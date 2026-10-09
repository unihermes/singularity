// Singularity - Quickshell
// ~/.config/quickshell/services/DdcBrightness.qml
//
// Brightness of external monitors over DDC/CI, one level per display: the
// desktop's monitors have no backlight node for Brightness.qml to read,
// but most take VCP feature 0x10 (brightness) over their I2C line.
//
// ddcutil does the talking. Displays are found with `ddcutil detect`, at
// startup and again whenever a screen comes or goes, and keyed on their
// DRM connector (DP-2), which is the name Quickshell gives the screen --
// so each bar's module drives the monitor it sits on.
//
// A DDC write takes a quarter of a second, and monitors drop commands that
// arrive while one is still being handled, so each display has one ddcutil
// in flight at a time: set() records the level at once (the slider and the
// bar follow the pointer) and the display's writer sends only the latest
// value once the one before it has finished. Levels are read at detection
// and each time the flyout opens (refresh()), which catches changes made
// with the monitor's own buttons; nothing is polled.
//
// Needs the i2c-dev module and access to /dev/i2c-*, both of which the
// ddcutil package sets up (modules-load.d and a uaccess udev rule).

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [ output, bus, model ] for every display that answers, from detect
    property var displays: []
    // output -> level 0..100
    property var levels: ({})

    readonly property bool available: displays.length > 0

    function find(output) {
        for (var i = 0; i < displays.length; i++)
            if (displays[i].output === output) return displays[i]
        return null
    }
    function has(output) { return find(output) !== null }
    function level(output) { return levels[output] !== undefined ? levels[output] : -1 }

    function setLevel(output, v) {
        var next = Object.assign({}, levels)
        next[output] = v
        levels = next
    }

    function set(output, pct) {
        var w = writer(output)
        if (!w) return
        var v = Math.max(0, Math.min(100, Math.round(pct)))
        setLevel(output, v)
        w.write(v)
    }

    function refresh() {
        for (var i = 0; i < writers.count; i++) {
            var w = writers.objectAt(i)
            if (w) w.read()
        }
    }

    function writer(output) {
        for (var i = 0; i < writers.count; i++) {
            var w = writers.objectAt(i)
            if (w && w.modelData.output === output) return w
        }
        return null
    }

    CommandProbe { id: probe; name: "ddcutil" }

    function detect() {
        if (probe.found && !detectProc.running) detectProc.running = true
    }
    Connections {
        target: probe
        function onFoundChanged() { root.detect() }
    }
    // a monitor plugged in or out; give its DDC line a moment to come up
    Connections {
        target: Quickshell
        function onScreensChanged() { redetect.restart() }
    }
    Timer { id: redetect; interval: 2000; onTriggered: root.detect() }

    Process {
        id: detectProc
        command: ["ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], cur = null
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()
                    var m
                    if (/^Display \d+/.test(l)) { cur = { output: "", bus: -1, model: "" }; out.push(cur) }
                    // "Invalid display" blocks (no DDC) are skipped by leaving cur null
                    else if (/^Invalid display/.test(l)) cur = null
                    else if (cur && (m = l.match(/^I2C bus:\s+\/dev\/i2c-(\d+)/))) cur.bus = Number(m[1])
                    else if (cur && (m = l.match(/^DRM connector:\s+card\d+-(.+)$/))) cur.output = m[1]
                    else if (cur && (m = l.match(/^Monitor:\s+[^:]*:([^:]*):/))) cur.model = m[1].trim()
                }
                root.displays = out.filter(d => d.output !== "" && d.bus >= 0)
            }
        }
    }

    // One per display: reads its level, and sends writes one at a time.
    Instantiator {
        id: writers
        model: root.displays

        QtObject {
            id: w
            required property var modelData
            property int pending: -1
            property bool wantRead: false
            property bool reading: false
            // the display's own top of the scale, nearly always 100
            property int max: 100

            property Process proc: Process {
                stdout: StdioCollector {
                    onStreamFinished: {
                        if (!w.reading) return
                        // "VCP 10 C <current> <max>"
                        var f = text.trim().split(/\s+/)
                        var cur = Number(f[3]), max = Number(f[4])
                        if (f[0] !== "VCP" || isNaN(cur) || !(max > 0)) return
                        w.max = max
                        if (w.pending < 0) root.setLevel(w.modelData.output, Math.round(cur / max * 100))
                    }
                }
                onExited: w.next()
            }

            function read() {
                wantRead = true
                if (!proc.running) next()
            }
            function write(v) {
                pending = v
                if (!proc.running) next()
            }
            function next() {
                var bus = String(modelData.bus)
                if (pending >= 0) {
                    reading = false
                    proc.command = ["ddcutil", "--bus", bus, "--noverify", "setvcp", "10",
                                    String(Math.round(pending * max / 100))]
                    pending = -1
                    proc.running = true
                } else if (wantRead) {
                    wantRead = false
                    reading = true
                    proc.command = ["ddcutil", "--bus", bus, "getvcp", "10", "--brief"]
                    proc.running = true
                }
            }

            Component.onCompleted: read()
        }
    }
}
