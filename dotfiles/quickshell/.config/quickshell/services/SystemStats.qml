// Singularity - Quickshell
// ~/.config/quickshell/SystemStats.qml
//
// Everything the System window shows, sampled: CPU (overall and per core),
// memory, swap, disk, temperature, network throughput and addresses, the
// heaviest processes, and static facts and hardware specs. Non-visual, and
// split out of System.qml so the numbers can be read (and the Gauge/Spark
// pieces reused) without the window's layout attached.
//
// Nearly everything live is read straight from procfs/sysfs with FileView
// rather than by running tools: /proc/stat for CPU and each core,
// /proc/meminfo for RAM and swap, the coretemp hwmon node for temperature
// (the same file `sensors` reads), and the interface byte counters for
// network speed. Re-reading a file each second costs next to nothing;
// spawning `sensors` or `free` each second would mean several processes a
// second for as long as the window is up.
//
// What does shell out, none of it per-second: `top` for the process list
// (every 3s), `df` for the root filesystem (every 30s), `pacman -Q` for the
// package counts, `lspci`/`lsblk`/DMI for the specs section, and a one-off
// search for the temperature sensor's hwmon node -- all once per open, since
// none of it changes while the window is up.
//
// Nothing polls unless `active` is true -- the window binds it to its own
// visibility. Going active resets the live baselines and history.

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "Format.js" as Format

Item {
    id: root
    visible: false

    property bool active: false
    // set while the pointer is over the process list: a refresh landing then
    // is dropped, so a row can't move out from under a click
    property bool holdProcs: false

    // samples of history kept for the graphs, one per second
    readonly property int historyLength: 60

    // --- state ---------------------------------------------------------

    property real cpu: 0          // 0..1
    property var cores: []        // 0..1 per core
    property real mem: 0          // 0..1
    property real memUsedKb: 0
    property real memTotalKb: 0
    property real swap: 0         // 0..1
    property real swapTotalKb: 0
    property real diskUsed: 0     // bytes
    property real diskSize: 0
    property real tempC: -1       // -1 = no sensor found
    property string iface: ""
    property real rxRate: -1      // bytes/s, -1 until two samples exist
    property real txRate: -1
    property real uptimeSec: 0

    // connection type/IP/signal, refreshed alongside the process list (3s)
    // -- these change rarely enough that 1s would just be wasted Process spawns
    property string ipAddr: ""
    property string connType: ""     // "Wi-Fi" | "Ethernet" | "Other" | ""
    property int signalDbm: 1000     // 1000 = n/a (not wifi, or no reading yet)

    // real battery only, same rule as the bar: UPower's DisplayDevice is a
    // synthetic aggregate that can't tell you whether a battery exists at all
    readonly property UPowerDevice batt: {
        var ds = UPower.devices ? UPower.devices.values : []
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].isLaptopBattery) return ds[i]
        }
        return UPower.displayDevice
    }
    readonly property bool hasBattery: batt && batt.ready && batt.isPresent

    // Histories are replaced, never mutated in place: a push onto the same
    // array doesn't notify, and the graphs would never repaint.
    property var cpuHistory: []
    property var rxHistory: []
    property var txHistory: []

    // [{ pid, user, cpu, memKb, name }], heaviest first
    property var procs: []
    property string procSort: "cpu"      // "cpu" | "mem"
    readonly property string me: Quickshell.env("USER")

    // previous samples, for the deltas
    property var cpuPrev: null
    property var corePrev: []
    property var netPrev: null

    function pushHistory(arr, v) {
        return arr.concat([v]).slice(-historyLength)
    }

    // --- sampling ------------------------------------------------------

    FileView { id: statFile;    path: "/proc/stat";    blockLoading: true }
    FileView { id: memFile;     path: "/proc/meminfo"; blockLoading: true }
    FileView { id: uptimeFile;  path: "/proc/uptime";  blockLoading: true }
    FileView { id: routeFile;   path: "/proc/net/route"; blockLoading: true }
    FileView {
        id: tempFile
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: rxFile
        path: root.iface !== "" ? "/sys/class/net/" + root.iface + "/statistics/rx_bytes" : ""
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: txFile
        path: root.iface !== "" ? "/sys/class/net/" + root.iface + "/statistics/tx_bytes" : ""
        blockLoading: true
        printErrors: false
    }

    // "cpu  user nice system idle iowait irq softirq steal ..." -> busy
    // fraction since the previous sample, or -1 with no previous sample
    function busy(fields, prev) {
        var f = fields.slice(1, 9).map(Number)
        var idle = f[3] + f[4]
        var total = f.reduce((a, b) => a + b, 0)
        var frac = -1
        if (prev) {
            var dt = total - prev.total
            if (dt > 0) frac = Math.max(0, Math.min(1, 1 - (idle - prev.idle) / dt))
        }
        return { frac: frac, sample: { idle: idle, total: total } }
    }

    function sampleCpu() {
        statFile.reload()
        var lines = statFile.text().split("\n")
        var nextCores = [], nextPrev = []
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].trim().split(/\s+/)
            if (f[0] === "cpu") {
                var all = busy(f, cpuPrev)
                if (all.frac >= 0) {
                    cpu = all.frac
                    cpuHistory = pushHistory(cpuHistory, all.frac)
                }
                cpuPrev = all.sample
            } else if (/^cpu\d+$/.test(f[0])) {
                var n = nextPrev.length
                var c = busy(f, corePrev[n])
                nextCores.push(Math.max(0, c.frac))
                nextPrev.push(c.sample)
            } else if (f[0] !== "" && !f[0].startsWith("cpu")) {
                break   // the cpu lines come first; nothing after is needed
            }
        }
        if (corePrev.length === nextPrev.length) cores = nextCores
        corePrev = nextPrev
    }

    function sampleMem() {
        memFile.reload()
        var kv = {}
        var lines = memFile.text().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^(\w+):\s+(\d+)/)
            if (m) kv[m[1]] = Number(m[2])
        }
        memTotalKb = kv.MemTotal || 0
        // MemAvailable, not MemFree: free memory excludes the page cache the
        // kernel will hand back the moment anything asks, so "used" computed
        // from it reads 80% on a machine that is mostly idle
        memUsedKb = memTotalKb - (kv.MemAvailable || 0)
        mem = memTotalKb > 0 ? memUsedKb / memTotalKb : 0
        swapTotalKb = kv.SwapTotal || 0
        swap = swapTotalKb > 0 ? (swapTotalKb - (kv.SwapFree || 0)) / swapTotalKb : 0
    }

    function sampleTemp() {
        if (tempFile.path === "") return
        tempFile.reload()
        var t = tempFile.text().trim()
        var v = Number(t)
        tempC = (t === "" || isNaN(v)) ? -1 : v / 1000
    }

    function sampleNet() {
        // The default route's interface, re-read each sample so switching
        // from wifi to ethernet (or a VPN) follows without reopening.
        routeFile.reload()
        var best = "", bestMetric = Infinity
        var lines = routeFile.text().split("\n")
        for (var i = 1; i < lines.length; i++) {
            var f = lines[i].trim().split(/\s+/)
            if (f.length < 7 || f[1] !== "00000000") continue
            if (Number(f[6]) < bestMetric) { best = f[0]; bestMetric = Number(f[6]) }
        }
        if (best !== iface) {
            // new counters, so the old baseline would produce a garbage delta
            iface = best
            netPrev = null
            rxRate = txRate = -1
            connType = best.startsWith("wl") ? "Wi-Fi"
                : best.startsWith("en") || best.startsWith("eth") ? "Ethernet"
                : best !== "" ? "Other" : ""
            if (best === "") { ipAddr = ""; signalDbm = 1000 }
        }
        if (iface === "") return

        rxFile.reload(); txFile.reload()
        var now = Date.now()
        var rx = Number(rxFile.text().trim()), tx = Number(txFile.text().trim())
        if (isNaN(rx) || isNaN(tx)) return
        if (netPrev) {
            var dt = (now - netPrev.t) / 1000
            if (dt > 0) {
                rxRate = Math.max(0, (rx - netPrev.rx) / dt)
                txRate = Math.max(0, (tx - netPrev.tx) / dt)
                rxHistory = pushHistory(rxHistory, rxRate)
                txHistory = pushHistory(txHistory, txRate)
            }
        }
        netPrev = { t: now, rx: rx, tx: tx }
    }

    function sampleUptime() {
        uptimeFile.reload()
        uptimeSec = Number(uptimeFile.text().split(" ")[0]) || 0
    }

    function sampleAll() {
        sampleCpu(); sampleMem(); sampleTemp(); sampleNet(); sampleUptime()
    }

    // IP address and (for wifi) signal strength. Piggybacks on the 3s
    // process-list timer below rather than its own -- neither changes fast
    // enough to need a fresh Process every second.
    function refreshNetInfo() {
        if (iface === "" || netInfoProc.running) return
        netInfoProc.command = ["sh", "-c",
            "ip -4 -o addr show dev " + iface + " | awk '{print $4}' | cut -d/ -f1\n"
            + "echo ---\n"
            // the link's signal level from the kernel's own table, not
            // `iw dev link`: iw isn't installed by default on Arch
            + (connType === "Wi-Fi" ? "awk -v i=" + iface + ": '$1==i {sub(/\\.$/,\"\",$4); print $4}' /proc/net/wireless" : "true")]
        netInfoProc.running = true
    }

    Process {
        id: netInfoProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("\n---\n")
                root.ipAddr = (parts[0] || "").trim()
                // Number("") is 0, which would read as a perfect 0 dBm
                var raw = (parts[1] || "").trim()
                var sig = Number(raw)
                root.signalDbm = raw === "" || isNaN(sig) ? 1000 : sig
            }
        }
    }

    // 1s: a gauge that lags two seconds behind a spike reads as broken
    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.sampleAll()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: { root.refreshProcs(); root.refreshNetInfo() }
    }

    // the sort a run was started with; see onStreamFinished
    property string procRunSort: ""

    function refreshProcs() {
        if (procProc.running) return
        procRunSort = procSort
        procProc.running = true
    }

    onActiveChanged: if (active) {
        // Stale baselines from the last time the window was open would turn
        // the first reading into an average over however long it was shut,
        // and old history would draw a graph with a gap-less lie in it.
        cpuPrev = null
        corePrev = []
        cores = []
        netPrev = null
        rxRate = txRate = -1
        cpuHistory = []
        rxHistory = []
        txHistory = []
        procs = []
        killPid = -1
        if (tempFile.path === "") tempProbe.running = true
    }

    Process {
        id: diskProc
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.trim().split("\n").pop().trim().split(/\s+/)
                if (f.length >= 2) {
                    root.diskSize = Number(f[0])
                    root.diskUsed = Number(f[1])
                }
            }
        }
    }

    // First CPU package sensor by driver: Intel, then AMD's two drivers,
    // then ARM SoCs, then the ACPI zone as a last resort.
    Process {
        id: tempProbe
        command: ["sh", "-c",
            "for want in coretemp k10temp zenpower cpu_thermal acpitz; do "
            + "for d in /sys/class/hwmon/hwmon*; do "
            + "[ \"$(cat $d/name 2>/dev/null)\" = \"$want\" ] && [ -r $d/temp1_input ] "
            + "&& { echo $d/temp1_input; exit 0; }; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim()
                if (p !== "") { tempFile.path = p; root.sampleTemp() }
            }
        }
    }

    // Heaviest processes. top, not ps: ps's %CPU is each process's average
    // over its whole lifetime, so a browser that spiked an hour ago outranks
    // whatever is pinning a core right now. top's *second* frame (-n 2) is a
    // real 1-second sample -- its first frame has the same lifetime-average
    // problem. -e k keeps RES in plain KiB instead of "1.2g".
    Process {
        id: procProc
        command: ["sh", "-c",
            "top -b -n 2 -d 1 -o " + (root.procSort === "mem" ? "%MEM" : "%CPU")
            + " -e k -w 512 | awk '/^top -/{f++} f==2 && /^ *[0-9]+ /{"
            + "c=$12; for(i=13;i<=NF;i++) c=c\" \"$i; if (c==\"top\") next; "
            + "print $1\"|\"$2\"|\"$9\"|\"$6\"|\"c; if(++n==5) exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                // held while the pointer is over the list, so a row can't
                // reshuffle out from under a click on its kill button
                if (root.holdProcs) return
                // A run takes a second, so one started just before the sort
                // was switched can land after it and paint the old order
                // over the new heading. Drop it; the next run is the right one.
                if (root.procRunSort !== root.procSort) { root.refreshProcs(); return }
                var out = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("|")
                    if (f.length < 5) continue
                    out.push({ pid: Number(f[0]), user: f[1], cpu: Number(f[2]),
                               memKb: Number(f[3]), name: f[4] })
                }
                // top already sorted, but by its own rounding of the column;
                // this keeps ties and near-ties in a stable, visible order
                var key = root.procSort === "mem" ? "memKb" : "cpu"
                out.sort((a, b) => b[key] - a[key])
                root.procs = out
            }
        }
    }

    onProcSortChanged: if (active) {
        procs = []
        refreshProcs()
    }

    // Two-step kill. The first click arms the button for that *pid* (not
    // that row), the second sends SIGTERM. Arming expires after 3s, and the
    // list freezes while hovered, so a refresh can't move a different
    // process under the confirming click.
    property int killPid: -1

    Timer {
        id: killDisarm
        interval: 3000
        onTriggered: root.killPid = -1
    }

    function requestKill(pid) {
        if (killPid !== pid) {
            killPid = pid
            killDisarm.restart()
            return
        }
        killPid = -1
        killDisarm.stop()
        killProc.command = ["kill", String(pid)]
        killProc.running = true
    }

    Process {
        id: killProc
        command: ["true"]
        onExited: root.refreshProcs()
    }

    // Static facts and hardware specs, gathered once per open rather than
    // sampled -- their own file, since nothing about them is live.
    readonly property alias specs: specsObj
    SystemSpecs {
        id: specsObj
        stats: root
        active: root.active
    }
}
