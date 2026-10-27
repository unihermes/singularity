// Singularity - Quickshell
// ~/.config/quickshell/services/Mice.qml
//
// Mice that keep their own settings (DPI, report rate, what each button
// does), through libratbag's ratbagd (scripts/ratbag.py), for the Devices
// page. Read when asked; each change is written to the mouse in turn, then
// read back.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // each { path, name, profile, rate, rates, resolution, dpi, dpis,
    // buttons: [{ path, type (0 off, 1 a mouse button, 2+ other), value }] }
    property var devices: []
    property string error: ""

    readonly property string script: Quickshell.shellPath("scripts/ratbag.py")

    function refresh() {
        if (probe.found && !reader.running && !writer.running) reader.running = true
    }

    property var queue: []
    function write(args) {
        queue = queue.concat([args])
        next()
    }
    function next() {
        if (writer.running || queue.length === 0) return
        writer.command = [script].concat(queue[0])
        queue = queue.slice(1)
        writer.running = true
    }

    // shown at once, before the mouse answers
    function patch(path, change) {
        devices = devices.map(d => d.path === path ? Object.assign({}, d, change) : d)
    }

    function setDpi(d, dpi) {
        patch(d.path, { dpi: dpi })
        write(["dpi", d.resolution, String(dpi)])
    }
    function setRate(d, hz) {
        patch(d.path, { rate: hz })
        write(["rate", d.profile, String(hz)])
    }
    // to mouse button n (1 left .. 5 forward), or 0 for nothing
    function setButton(d, index, n) {
        patch(d.path, { buttons: d.buttons.map((b, i) => i === index ? { path: b.path, type: n ? 1 : 0, value: n } : b) })
        write(["button", d.buttons[index].path, n ? String(n) : "off"])
    }

    CommandProbe {
        id: probe
        name: "ratbagctl"
        onFoundChanged: root.refresh()
    }

    Process {
        id: reader
        command: [root.script, "read"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.devices = JSON.parse(text) } catch (e) { root.devices = [] }
            }
        }
    }

    Process {
        id: writer
        stderr: StdioCollector { id: writeErr }
        onExited: code => {
            root.error = code === 0 ? "" : writeErr.text.trim().split("\n").pop() || "The mouse didn't take it"
            if (root.queue.length > 0) root.next()
            else root.refresh()
        }
    }
}
