// Singularity - Quickshell
// ~/.config/quickshell/services/SystemStats.qml
//
// Everything live the System window shows, sampled: CPU (overall, per core
// and per-core clocks), memory in detail, swap, every mounted filesystem,
// disk throughput, temperatures and fans, network per interface, the battery
// and the heaviest processes.
//
// A singleton rather than an object the window owns: the System window is
// now a sidebar of pages, each its own file loaded on demand, and threading
// one `stats` object down through a Loader into a page means every page
// guarding against it being null for the frame before it arrives. The
// static half lives next door in SystemSpecs.qml.
//
// Nearly everything is read straight from procfs/sysfs with FileView rather
// than by running tools: /proc/stat for CPU and each core, /proc/meminfo for
// RAM and swap, /proc/loadavg for load and process counts, /proc/diskstats
// for disk throughput, hwmon for temperature, the interface byte counters
// for network speed, and the battery's uevent -- one file that carries every
// field the Power page shows. Re-reading a file each second costs next to
// nothing; spawning `sensors` or `free` each second would mean several
// processes a second for as long as the window is up.
//
// What does shell out, none of it per-second: `top` for the process list
// (every 3s), `ip` for addresses (3s), a hwmon sweep for the full sensor
// list (5s), `df` for the filesystems (30s), and one-off probes for the
// temperature node and the battery's path.
//
// Nothing polls unless `active` is true -- the window binds it to its own
// visibility. Going active resets the live baselines and history.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    // set while the pointer is over a process list: a refresh landing then
    // is dropped, so a row can't move out from under a click
    property bool holdProcs: false

    // samples of history kept for the graphs, one per second
    readonly property int historyLength: 60

    // --- cpu -------------------------------------------------------------

    property real cpu: 0          // 0..1
    property var cores: []        // 0..1 per core
    property var coreMhz: []      // current clock per core, MHz
    readonly property real cpuMhz: coreMhz.length > 0
        ? coreMhz.reduce((a, b) => a + b, 0) / coreMhz.length : 0
    readonly property real cpuMhzPeak: coreMhz.length > 0 ? Math.max.apply(null, coreMhz) : 0
    property string governor: ""
    property string epp: ""       // energy performance preference, if the driver has one

    property real load1: 0
    property real load5: 0
    property real load15: 0
    property int procRunning: 0
    property int threadTotal: 0

    // --- memory ----------------------------------------------------------

    property real mem: 0          // 0..1, MemAvailable-based
    property real memTotalKb: 0
    property real memUsedKb: 0
    property real memAvailKb: 0
    property real memFreeKb: 0
    property real cachedKb: 0
    property real buffersKb: 0
    property real shmemKb: 0
    property real slabKb: 0
    property real dirtyKb: 0
    property real writebackKb: 0
    property real swap: 0
    property real swapTotalKb: 0
    property real swapFreeKb: 0

    // --- storage ---------------------------------------------------------

    // [{ source, target, fstype, size, used }], bytes
    property var filesystems: []
    // the root filesystem, pulled out of the list for the overview gauge
    readonly property var rootFs: filesystems.find(f => f.target === "/") || null
    readonly property real diskSize: rootFs ? rootFs.size : 0
    readonly property real diskUsed: rootFs ? rootFs.used : 0

    property real diskRead: -1    // bytes/s across every real disk
    property real diskWrite: -1
    property var diskReadHistory: []
    property var diskWriteHistory: []

    // --- sensors ---------------------------------------------------------

    property real tempC: -1       // the CPU package, -1 = no sensor found
    // [{ chip, label, c }] for every readable hwmon temperature
    property var sensors: []
    // [{ chip, label, rpm }]
    property var fans: []

    // --- network ---------------------------------------------------------

    property string iface: ""        // the default route's interface
    property string connType: ""     // "Wi-Fi" | "Ethernet" | "Other" | ""
    property string ipAddr: ""
    property int signalDbm: 1000     // 1000 = n/a (not wifi, or no reading yet)
    property real rxRate: -1         // bytes/s, -1 until two samples exist
    property real txRate: -1
    property real rxTotal: 0         // bytes since the interface came up
    property real txTotal: 0
    property var rxHistory: []
    property var txHistory: []
    // [{ name, state, mac, mtu, ipv4, ipv6, rx, tx }] for every interface
    property var interfaces: []
    property string gateway: ""
    property string dns: ""

    // --- battery ---------------------------------------------------------

    // POWER_SUPPLY_* from the battery's uevent, keys lowercased and with the
    // prefix dropped: status, capacity, cycle_count, voltage_now, ...
    property var bat: ({})
    property bool acOnline: false

    // --- uptime ----------------------------------------------------------

    property real uptimeSec: 0
    readonly property var bootTime: new Date(Date.now() - uptimeSec * 1000)

    // --- history ---------------------------------------------------------

    // Histories are replaced, never mutated in place: a push onto the same
    // array doesn't notify, and the graphs would never repaint.
    property var cpuHistory: []
    property var memHistory: []

    // --- processes -------------------------------------------------------

    // [{ pid, user, cpu, memKb, name }], heaviest first
    property var procs: []
    property string procSort: "cpu"      // "cpu" | "mem"
    // how many rows to fetch; the Processes page asks for more than the
    // Overview's summary does
    property int procLimit: 8
    readonly property string me: Quickshell.env("USER")

    // previous samples, for the deltas
    property var cpuPrev: null
    property var corePrev: []
    property var netPrev: null
    property var diskPrev: null

    function pushHistory(arr, v) {
        return arr.concat([v]).slice(-historyLength)
    }

    // --- sampling --------------------------------------------------------

    FileView { id: statFile;    path: "/proc/stat";      blockLoading: true }
    FileView { id: memFile;     path: "/proc/meminfo";   blockLoading: true }
    FileView { id: uptimeFile;  path: "/proc/uptime";    blockLoading: true }
    FileView { id: loadFile;    path: "/proc/loadavg";   blockLoading: true }
    FileView { id: routeFile;   path: "/proc/net/route"; blockLoading: true }
    FileView { id: diskFile;    path: "/proc/diskstats"; blockLoading: true }
    FileView { id: cpuinfoFile; path: "/proc/cpuinfo";   blockLoading: true }
    FileView {
        id: govFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: eppFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: tempFile
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: batFile
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: acFile
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

    // Per-core clocks from /proc/cpuinfo, not the cpufreq sysfs nodes: one
    // read covers every core, where sysfs would need a FileView per thread.
    // Off the 3s timer -- a clock that lags a second reads fine, and this
    // file is far bigger than /proc/stat.
    function sampleFreq() {
        cpuinfoFile.reload()
        var mhz = []
        var lines = cpuinfoFile.text().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^cpu MHz\s*:\s*([\d.]+)/)
            if (m) mhz.push(Number(m[1]))
        }
        coreMhz = mhz
        govFile.reload(); eppFile.reload()
        governor = govFile.text().trim()
        epp = eppFile.text().trim()
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
        memFreeKb = kv.MemFree || 0
        memAvailKb = kv.MemAvailable || 0
        cachedKb = kv.Cached || 0
        buffersKb = kv.Buffers || 0
        shmemKb = kv.Shmem || 0
        slabKb = kv.Slab || 0
        dirtyKb = kv.Dirty || 0
        writebackKb = kv.Writeback || 0
        // MemAvailable, not MemFree: free memory excludes the page cache the
        // kernel will hand back the moment anything asks, so "used" computed
        // from it reads 80% on a machine that is mostly idle
        memUsedKb = memTotalKb - memAvailKb
        mem = memTotalKb > 0 ? memUsedKb / memTotalKb : 0
        memHistory = pushHistory(memHistory, mem)
        swapTotalKb = kv.SwapTotal || 0
        swapFreeKb = kv.SwapFree || 0
        swap = swapTotalKb > 0 ? (swapTotalKb - swapFreeKb) / swapTotalKb : 0
    }

    function sampleLoad() {
        loadFile.reload()
        var f = loadFile.text().trim().split(/\s+/)
        if (f.length < 4) return
        load1 = Number(f[0]); load5 = Number(f[1]); load15 = Number(f[2])
        var rt = f[3].split("/")
        procRunning = Number(rt[0]) || 0
        threadTotal = Number(rt[1]) || 0
    }

    function sampleTemp() {
        if (tempFile.path === "") return
        tempFile.reload()
        var t = tempFile.text().trim()
        var v = Number(t)
        tempC = (t === "" || isNaN(v)) ? -1 : v / 1000
    }

    // Whole disks only: the partitions on top of one would count the same
    // bytes a second time, and dm/loop devices a third.
    readonly property var diskRe: /^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+|hd[a-z]+)$/

    function sampleDisk() {
        diskFile.reload()
        var lines = diskFile.text().split("\n")
        var rd = 0, wr = 0
        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].trim().split(/\s+/)
            if (f.length < 10 || !diskRe.test(f[2])) continue
            // sectors, always 512 bytes here whatever the drive's own
            // sector size -- the kernel reports this field in 512b units
            rd += Number(f[5]) * 512
            wr += Number(f[9]) * 512
        }
        var now = Date.now()
        if (diskPrev) {
            var dt = (now - diskPrev.t) / 1000
            if (dt > 0) {
                diskRead = Math.max(0, (rd - diskPrev.rd) / dt)
                diskWrite = Math.max(0, (wr - diskPrev.wr) / dt)
                diskReadHistory = pushHistory(diskReadHistory, diskRead)
                diskWriteHistory = pushHistory(diskWriteHistory, diskWrite)
            }
        }
        diskPrev = { t: now, rd: rd, wr: wr }
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
        rxTotal = rx; txTotal = tx
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

    function sampleBattery() {
        if (batFile.path === "") return
        batFile.reload()
        var kv = {}
        var lines = batFile.text().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^POWER_SUPPLY_([A-Z0-9_]+)=(.*)$/)
            if (m) kv[m[1].toLowerCase()] = m[2]
        }
        bat = kv
        if (acFile.path !== "") {
            acFile.reload()
            acOnline = acFile.text().trim() === "1"
        }
    }

    function sampleAll() {
        sampleCpu(); sampleMem(); sampleLoad(); sampleTemp()
        sampleDisk(); sampleNet(); sampleUptime()
    }

    // --- battery, derived ------------------------------------------------

    // Batteries report either charge (ampere-hours) or energy (watt-hours);
    // this laptop's reports charge, so both shapes are converted to watt-
    // hours here and every reader can just ask for watt-hours.
    function wh(key) {
        var v = Number(bat["energy_" + key])
        if (!isNaN(v) && v > 0) return v / 1e6
        var c = Number(bat["charge_" + key])
        var volt = Number(bat.voltage_min_design) || Number(bat.voltage_now)
        if (!isNaN(c) && c > 0 && volt > 0) return c * volt / 1e12
        return -1
    }
    readonly property real batNowWh:    bat.status !== undefined ? wh("now") : -1
    readonly property real batFullWh:   bat.status !== undefined ? wh("full") : -1
    readonly property real batDesignWh: bat.status !== undefined ? wh("full_design") : -1
    // Draw in watts. power_now is watts already; current_now needs the
    // voltage to get there.
    readonly property real batWatts: {
        if (bat.status === undefined) return -1
        var p = Number(bat.power_now)
        if (!isNaN(p) && p > 0) return p / 1e6
        var i = Number(bat.current_now), v = Number(bat.voltage_now)
        if (!isNaN(i) && i > 0 && v > 0) return i * v / 1e12
        return -1
    }
    // What the pack holds now against what it held new: the number that says
    // whether a battery is worn out, which the percentage never does.
    readonly property real batHealth: batFullWh > 0 && batDesignWh > 0
        ? batFullWh / batDesignWh : -1
    readonly property bool batCharging: String(bat.status || "") === "Charging"
    // Hours left at the current draw -- the pack's own estimate, not a
    // smoothed one, so it swings while the load does.
    readonly property real batHours: batWatts > 0 && batNowWh > 0
        ? (batCharging ? (batFullWh - batNowWh) : batNowWh) / batWatts : -1

    // --- timers ----------------------------------------------------------

    // 1s: a gauge that lags two seconds behind a spike reads as broken
    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.sampleAll()
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            root.refreshProcs()
            root.refreshNetInfo()
            root.sampleFreq()
            root.sampleBattery()
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!sensorProc.running) sensorProc.running = true
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!dfProc.running) dfProc.running = true
    }

    onActiveChanged: if (active) {
        // Stale baselines from the last time the window was open would turn
        // the first reading into an average over however long it was shut,
        // and old history would draw a graph with a gap-less lie in it.
        cpuPrev = null
        corePrev = []
        cores = []
        netPrev = null
        diskPrev = null
        rxRate = txRate = -1
        diskRead = diskWrite = -1
        cpuHistory = []
        memHistory = []
        rxHistory = []
        txHistory = []
        diskReadHistory = []
        diskWriteHistory = []
        procs = []
        killPid = -1
        if (tempFile.path === "") tempProbe.running = true
        if (batFile.path === "") batProbe.running = true
    }

    // --- one-off probes --------------------------------------------------

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

    // The battery's uevent and the mains adapter's online flag. Found once:
    // a battery doesn't move sysfs nodes while the machine is up.
    Process {
        id: batProbe
        command: ["sh", "-c",
            "for d in /sys/class/power_supply/*; do "
            + "t=$(cat $d/type 2>/dev/null); "
            + "[ \"$t\" = Battery ] && [ -r $d/uevent ] && { echo bat $d/uevent; break; }; done\n"
            + "for d in /sys/class/power_supply/*; do "
            + "t=$(cat $d/type 2>/dev/null); "
            + "[ \"$t\" = Mains ] && [ -r $d/online ] && { echo ac $d/online; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].trim().split(" ")
                    if (f[0] === "bat" && f[1]) batFile.path = f[1]
                    if (f[0] === "ac" && f[1]) acFile.path = f[1]
                }
                root.sampleBattery()
            }
        }
    }

    // --- periodic processes ----------------------------------------------

    // Every readable hwmon temperature and fan, not just the CPU package:
    // on this laptop that's the package, the SSD, the wifi card and the
    // ACPI zone, and knowing which one is hot is the whole point of a
    // sensor list. A sweep rather than a FileView each, because the set of
    // nodes isn't known until it's walked.
    Process {
        id: sensorProc
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do "
            + "n=$(cat $d/name 2>/dev/null) || continue; "
            + "for t in $d/temp*_input; do [ -r \"$t\" ] || continue; "
            + "l=$(cat \"${t%_input}_label\" 2>/dev/null); b=${t##*/}; "
            + "echo \"T|$n|${l:-${b%_input}}|$(cat \"$t\")\"; done; "
            + "for f in $d/fan*_input; do [ -r \"$f\" ] || continue; "
            + "l=$(cat \"${f%_input}_label\" 2>/dev/null); b=${f##*/}; "
            + "echo \"F|$n|${l:-${b%_input}}|$(cat \"$f\")\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var temps = [], fans = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("|")
                    if (f.length < 4) continue
                    var v = Number(f[3])
                    if (isNaN(v)) continue
                    if (f[0] === "T") temps.push({ chip: f[1], label: f[2], c: v / 1000 })
                    // a fan reading 0 is a fan that is off, which is worth
                    // showing; one with no tacho reads as a missing file
                    else fans.push({ chip: f[1], label: f[2], rpm: v })
                }
                temps.sort((a, b) => b.c - a.c)
                root.sensors = temps
                root.fans = fans
            }
        }
    }

    // Every real filesystem, not just root: /home on its own partition, a
    // mounted phone, an external disk. The pseudo-filesystems are excluded
    // by type rather than by name -- there are a dozen of them and their
    // mount points move.
    Process {
        id: dfProc
        command: ["sh", "-c",
            "df -B1 --output=source,target,fstype,size,used -x tmpfs -x devtmpfs "
            + "-x efivarfs -x squashfs -x overlay -x ramfs 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].trim().split(/\s+/)
                    if (f.length < 5) continue
                    out.push({ source: f[0], target: f[1], fstype: f[2],
                               size: Number(f[3]), used: Number(f[4]) })
                }
                out.sort((a, b) => b.size - a.size)
                root.filesystems = out
            }
        }
    }

    // Addresses, the default gateway and the resolvers, plus the wifi link's
    // signal. Every 3s rather than every second: none of it changes at the
    // rate a throughput number does.
    function refreshNetInfo() {
        if (netInfoProc.running) return
        netInfoProc.command = ["sh", "-c",
            "ip -j addr show 2>/dev/null || echo '[]'\n"
            + "echo ---\n"
            + "ip route show default 2>/dev/null | awk '{print $3; exit}'\n"
            + "echo ---\n"
            // /etc/resolv.conf rather than resolvectl: it is there whether
            // or not systemd-resolved is, and it is what glibc actually uses
            + "awk '/^nameserver/{print $2}' /etc/resolv.conf 2>/dev/null | paste -sd' '\n"
            + "echo ---\n"
            // the link's signal level from the kernel's own table, not
            // `iw dev link`: iw isn't installed by default on Arch
            + "awk 'NR>2 {sub(/:$/,\"\",$1); sub(/\\.$/,\"\",$4); print $1\" \"$4}' /proc/net/wireless 2>/dev/null"]
        netInfoProc.running = true
    }

    Process {
        id: netInfoProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("\n---\n")
                var addrs
                try { addrs = JSON.parse(parts[0] || "[]") } catch (e) { addrs = [] }
                var out = []
                for (var i = 0; i < addrs.length; i++) {
                    var a = addrs[i]
                    var v4 = [], v6 = []
                    var info = a.addr_info || []
                    for (var j = 0; j < info.length; j++) {
                        if (info[j].family === "inet") v4.push(info[j].local)
                        // link-local v6 is on every interface and says
                        // nothing about connectivity
                        else if (info[j].family === "inet6" && info[j].scope === "global")
                            v6.push(info[j].local)
                    }
                    out.push({
                        name: a.ifname, state: a.operstate || "",
                        mac: a.address || "", mtu: a.mtu || 0,
                        ipv4: v4.join(", "), ipv6: v6.join(", "),
                    })
                }
                // the interface in use first, loopback last
                out.sort((a, b) => (a.name === root.iface ? -2 : a.name === "lo" ? 2 : 0)
                                 - (b.name === root.iface ? -2 : b.name === "lo" ? 2 : 0))
                root.interfaces = out
                var mine = out.find(x => x.name === root.iface)
                root.ipAddr = mine ? mine.ipv4 : ""

                root.gateway = (parts[1] || "").trim()
                root.dns = (parts[2] || "").trim()

                // Number("") is 0, which would read as a perfect 0 dBm
                var sig = 1000
                var wl = (parts[3] || "").trim().split("\n")
                for (var k = 0; k < wl.length; k++) {
                    var wf = wl[k].trim().split(/\s+/)
                    if (wf[0] === root.iface && wf[1] !== undefined) {
                        var n = Number(wf[1])
                        if (!isNaN(n)) sig = n
                    }
                }
                root.signalDbm = sig
            }
        }
    }

    // --- processes -------------------------------------------------------

    // the sort a run was started with; see onStreamFinished
    property string procRunSort: ""

    function refreshProcs() {
        if (procProc.running) return
        procRunSort = procSort
        procProc.running = true
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
            + "print $1\"|\"$2\"|\"$9\"|\"$6\"|\"c; if(++n==" + root.procLimit + ") exit}'"]
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
    // a page asking for more rows than the last one showed: refetch rather
    // than wait up to 3s with a short list on screen
    onProcLimitChanged: if (active) refreshProcs()

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
}
