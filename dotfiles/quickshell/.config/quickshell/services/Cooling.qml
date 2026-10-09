// Singularity - Quickshell
// ~/.config/quickshell/services/Cooling.qml
//
// Temperatures and fans for the bar's Cooling module and its flyout: the CPU
// package, the GPU, the hottest drive, and every fan header with a tacho.
//
// A desktop's module. A laptop's fans are the firmware's business and its
// temperatures are already on the System window, so the module only runs on
// a machine install.sh recorded as a desktop -- or, with no record, one
// without a battery.
//
// Read like SystemStats: the hwmon nodes are found once by a probe, then
// each is a FileView re-read every few seconds, with no process per sample.
// The one exception is an NVIDIA card, whose driver has no hwmon node:
// nvidia-smi runs once with its own loop (-l) and prints a line per sample.
//
// Fans are named from ~/.local/state/singularity/fan-names.json when it
// exists, an object of header to name ("fan1": "CPU"): which header drives
// which fan is particular to one machine's wiring, so it never lives in the
// repo.
// A header that has never turned since the shell started is left out --
// motherboards list every header, wired or not.

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
    readonly property bool wanted: desktop && Settings.widgetVisible("cooling")
    readonly property bool available: wanted && (cpuC >= 0 || gpuC >= 0 || fans.length > 0)

    property string machine: ""

    property real cpuC: -1
    property real gpuC: -1          // the NVIDIA card, else the first amdgpu
    property real driveC: -1        // the hottest NVMe drive
    property int gpuLoad: -1        // %, NVIDIA only
    property real gpuWatts: -1
    property int gpuFan: -1         // % of the card's own fans, NVIDIA only

    // [{ key, name, rpm, duty }] for every header that has turned; duty is
    // the PWM as a percent, -1 when the header has no PWM node
    property var fans: []
    property var cpuHistory: []
    property var gpuHistory: []

    readonly property real hottest: Math.max(cpuC, gpuC)

    readonly property bool coolerControl: ccProbe.found

    property var names: ({})
    // keys of headers seen turning, so a stopped fan stays listed
    property var spun: ({})
    // [{ key, input, pwm }], [paths]
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
            if (seen[s.key]) out.push({ key: s.key, name: fanName(s.key), rpm: s.rpm, duty: s.duty })
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

    // The CPU package by driver, as SystemStats finds it; amdgpu's edge
    // sensor for the GPU; every NVMe drive's composite; and every fan input
    // beside the PWM that drives it, when there is one.
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
            + "echo \"F|$k|$f|$p\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var fanNodes = [], drives = [], gpu = ""
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("|")
                    if (f[0] === "C") cpuFile.path = f[1]
                    else if (f[0] === "G" && gpu === "") gpu = f[1]
                    else if (f[0] === "D") drives.push(f[1])
                    else if (f[0] === "F" && f.length >= 4) fanNodes.push({ key: f[1], input: f[2], pwm: f[3] })
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
            function read() {
                rpmView.reload()
                var rpm = Number(rpmView.text().trim())
                var duty = -1
                if (modelData.pwm !== "") {
                    pwmView.reload()
                    var p = Number(pwmView.text().trim())
                    if (!isNaN(p)) duty = Math.round(p / 255 * 100)
                }
                return { key: modelData.key, rpm: isNaN(rpm) ? 0 : rpm, duty: duty }
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
                root.gpuLoad = isNaN(v[1]) ? -1 : v[1]
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
