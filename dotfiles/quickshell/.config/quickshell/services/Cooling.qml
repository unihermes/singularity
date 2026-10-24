// Singularity - Quickshell
// ~/.config/quickshell/services/Cooling.qml
//
// Temperatures and fans for the desktop's Cooling module: CPU package, GPU,
// hottest drive, every fan with a tacho. Desktops only (install.sh's record,
// else no battery). hwmon nodes probed once, then re-read by FileView;
// NVIDIA via one looping nvidia-smi. Fan names from fan-names.json in the
// state directory (fan1 to CPU, say); headers that never turned are hidden.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // seconds between samples; the history covers historyLength of them
    readonly property int interval: 3
    readonly property int historyLength: 60

    // a reading at or over this is drawn in the alert colour
    readonly property int hotC: 85

    readonly property bool desktop: machine === "desktop"
        || (machine === "" && !Battery.present)
    // the bar's Cooling module, or the desktop's stats widget (GPU load)
    readonly property bool wanted: desktop && (Settings.widgetVisible("cooling") || Settings.deskWidget("stats").on)
    readonly property bool available: wanted && (cpuC >= 0 || gpuC >= 0 || fans.length > 0)

    property string machine: ""

    property real cpuC: -1
    property real gpuC: -1          // the NVIDIA card, else the first amdgpu
    property real driveC: -1        // the hottest NVMe drive
    property int gpuLoad: -1        // %, NVIDIA only, the mean of the last two readings
    property int gpuLoadLast: -1
    property real gpuWatts: -1
    property int gpuFan: -1         // % of the card's own fans, NVIDIA only

    // [{ key, name, rpm, duty, auto }] for every header that has turned; duty
    // is the PWM as a percent, -1 when the header has no PWM node; auto when
    // the board drives it, not a manual PWM (CoolerControl's)
    property var fans: []
    property var cpuHistory: []
    property var gpuHistory: []

    readonly property real hottest: Math.max(cpuC, gpuC)

    readonly property bool coolerControl: ccProbe.found

    property var names: ({})
    // keys of headers seen turning, so a stopped fan stays listed
    property var spun: ({})
    // [{ key, input, pwm, enable }], [paths]
    property var fanNodes: []
    property var driveNodes: []

    function fanName(key) {
        if (names[key]) return names[key]
        var n = key.replace(/^fan/, "")
        return "Fan " + n
    }

    function openCoolerControl() {
        Quickshell.execDetached(["coolercontrol"])
    }

    // CoolerControl's modes ([{ uid, name }]) and the active one's uid, over
    // its daemon's API with the GUI's own access token; empty when there's
    // no daemon, no token or no modes
    property var modes: []
    property string activeMode: ""
    readonly property string ccApi: "conf=\"$HOME/.config/org.coolercontrol.CoolerControl/CoolerControl.conf\"; "
        + "t=$(sed -n '/^\\[daemonAccessTokens\\]/,/^\\[/s/^[^=]*=@ByteArray(\\(.*\\))$/\\1/p' \"$conf\" | head -n1); "
        + "cc() { curl -sk --max-time 4 -H \"Authorization: Bearer $t\" \"$@\"; }; "
    function refreshModes() {
        if (coolerControl && !modesProc.running) modesProc.running = true
    }
    function setMode(uid) {
        activeMode = uid
        modeSet.command = ["sh", "-c", ccApi + "cc -X POST \"https://127.0.0.1:11987/modes-active/$1\" >/dev/null", "sh", uid]
        modeSet.running = true
    }

    Process {
        id: modesProc
        command: ["sh", "-c", root.ccApi + "cc https://127.0.0.1:11987/modes; echo; cc https://127.0.0.1:11987/modes-active"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                try {
                    root.modes = (JSON.parse(lines[0]).modes || []).map(m => ({ uid: m.uid, name: m.name }))
                    root.activeMode = JSON.parse(lines[1]).current_mode_uid || ""
                } catch (e) {
                    root.modes = []
                }
            }
        }
    }

    Process {
        id: modeSet
        onExited: root.refreshModes()
    }

    function push(hist, v) {
        var h = hist.concat([v])
        return h.length > historyLength ? h.slice(h.length - historyLength) : h
    }

    function readC(view) {
        if (view.path === "") return -1
        view.reload()
        var v = Number(view.text().trim())
        return isNaN(v) || view.text().trim() === "" ? -1 : v / 1000
    }

    function sample() {
        cpuC = readC(cpuFile)
        if (!smiProbe.found) gpuC = readC(gpuFile)

        var hottestDrive = -1
        for (var d = 0; d < driveReaders.count; d++) {
            var r = driveReaders.objectAt(d)
            if (r) hottestDrive = Math.max(hottestDrive, readC(r.view))
        }
        driveC = hottestDrive

        var out = []
        var seen = spun
        var grew = false
        for (var i = 0; i < fanReaders.count; i++) {
            var f = fanReaders.objectAt(i)
            if (!f) continue
            var s = f.read()
            if (s.rpm > 0 && !seen[s.key]) { seen[s.key] = true; grew = true }
            if (seen[s.key]) out.push({ key: s.key, name: fanName(s.key), rpm: s.rpm, duty: s.duty, auto: s.auto })
        }
        if (grew) spun = Object.assign({}, seen)
        fans = out

        cpuHistory = push(cpuHistory, cpuC)
        if (gpuC >= 0) gpuHistory = push(gpuHistory, gpuC)
    }

    onWantedChanged: if (wanted) probe.running = true
    Component.onCompleted: if (wanted) probe.running = true
    onNamesChanged: fans = fans.map(f => Object.assign({}, f, { name: fanName(f.key) }))

    Timer {
        interval: root.interval * 1000
        running: root.wanted && !probe.running
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    FileView {
        path: Settings.stateDir + "/machine"
        // read before the first binding settles, so a laptop never starts
        // the probes on the way to finding out it's a laptop
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.machine = text().trim()
        onLoadFailed: root.machine = ""
        onFileChanged: reload()
    }

    FileView {
        path: Settings.stateDir + "/fan-names.json"
        watchChanges: true
        printErrors: false
        onLoaded: {
            try { root.names = JSON.parse(text()) || {} } catch (e) { root.names = {} }
        }
        onLoadFailed: root.names = {}
        onFileChanged: reload()
    }

    FileView { id: cpuFile; blockLoading: true; printErrors: false }
    FileView { id: gpuFile; blockLoading: true; printErrors: false }

    // the CPU package, amdgpu's edge sensor, each NVMe composite, and each
    // fan input with its PWM
    Process {
        id: probe
        command: ["sh", "-c",
            "for want in coretemp k10temp zenpower cpu_thermal; do "
            + "for d in /sys/class/hwmon/hwmon*; do "
            + "[ \"$(cat $d/name 2>/dev/null)\" = \"$want\" ] && [ -r $d/temp1_input ] "
            + "&& { echo \"C|$d/temp1_input\"; break 2; }; done; done\n"
            + "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null) || continue; "
            + "case $n in amdgpu) [ -r $d/temp1_input ] && echo \"G|$d/temp1_input\";; "
            + "nvme) [ -r $d/temp1_input ] && echo \"D|$d/temp1_input\";; esac; "
            + "for f in $d/fan*_input; do [ -r \"$f\" ] || continue; "
            + "k=${f##*/}; k=${k%_input}; p=$d/pwm${k#fan}; [ -r \"$p\" ] || p=; "
            + "e=${p:+${p}_enable}; [ -n \"$e\" ] && [ -r \"$e\" ] || e=; "
            + "echo \"F|$k|$f|$p|$e\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var fanNodes = [], drives = [], gpu = ""
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("|")
                    if (f[0] === "C") cpuFile.path = f[1]
                    else if (f[0] === "G" && gpu === "") gpu = f[1]
                    else if (f[0] === "D") drives.push(f[1])
                    else if (f[0] === "F" && f.length >= 4) fanNodes.push({ key: f[1], input: f[2], pwm: f[3], enable: f[4] || "" })
                }
                gpuFile.path = gpu
                root.driveNodes = drives
                root.fanNodes = fanNodes
            }
        }
    }

    Instantiator {
        id: driveReaders
        model: root.driveNodes
        QtObject {
            required property string modelData
            property FileView view: FileView { path: modelData; blockLoading: true; printErrors: false }
        }
    }

    Instantiator {
        id: fanReaders
        model: root.fanNodes
        QtObject {
            required property var modelData
            property FileView rpmView: FileView { path: modelData.input; blockLoading: true; printErrors: false }
            property FileView pwmView: FileView { path: modelData.pwm; blockLoading: true; printErrors: false }
            property FileView enableView: FileView { path: modelData.enable; blockLoading: true; printErrors: false }
            function read() {
                rpmView.reload()
                var rpm = Number(rpmView.text().trim())
                var duty = -1, auto = false
                if (modelData.enable !== "") {
                    enableView.reload()
                    auto = enableView.text().trim() !== "1"
                }
                if (modelData.pwm !== "") {
                    pwmView.reload()
                    var p = Number(pwmView.text().trim())
                    if (!isNaN(p)) duty = Math.round(p / 255 * 100)
                }
                return { key: modelData.key, rpm: isNaN(rpm) ? 0 : rpm, duty: duty, auto: auto }
            }
        }
    }

    CommandProbe { id: smiProbe; name: "nvidia-smi" }
    CommandProbe { id: ccProbe; name: "coolercontrol" }

    // One process for as long as the module is up, printing a line every
    // interval. Restarted after a pause if it dies (a driver reload).
    Process {
        id: smi
        running: root.wanted && smiProbe.found
        command: ["nvidia-smi",
            "--query-gpu=temperature.gpu,utilization.gpu,power.draw,fan.speed",
            "--format=csv,noheader,nounits", "-l", String(root.interval)]
        stdout: SplitParser {
            onRead: line => {
                var v = line.split(",").map(s => Number(s.trim()))
                if (v.length < 4) return
                root.gpuC = isNaN(v[0]) ? -1 : v[0]
                // with the reading before it: one alone swings with each frame
                var load = isNaN(v[1]) ? -1 : v[1]
                root.gpuLoad = load < 0 ? -1 : Math.round((load + (root.gpuLoadLast >= 0 ? root.gpuLoadLast : load)) / 2)
                root.gpuLoadLast = load
                root.gpuWatts = isNaN(v[2]) ? -1 : v[2]
                root.gpuFan = isNaN(v[3]) ? -1 : v[3]
            }
        }
        onExited: if (root.wanted) smiRestart.start()
    }
    Timer {
        id: smiRestart
        interval: 10000
        onTriggered: smi.running = Qt.binding(() => root.wanted && smiProbe.found)
    }
}
