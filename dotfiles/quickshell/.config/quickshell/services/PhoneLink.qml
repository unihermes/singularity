// Singularity - Quickshell
// ~/.config/quickshell/services/PhoneLink.qml
//
// The phone through the KDE Connect app on it: scripts/phone-link.py, run
// only while Phone link is on in Settings (Settings.phoneLinkOn), so it
// costs nothing when off. It finds and pairs the phone, and brings its
// battery and notifications (reply, dismiss, their actions), rings it,
// sends files and shares the clipboard both ways.
// Commands go in on its stdin, its state comes back a line of JSON at a time.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool running: proc.running
    property string error: ""
    // how the phone sees this computer
    property string hostName: ""

    // [{ id, name, type, paired, reachable, pairing ("" | "requested" |
    //    "incoming"), battery, charging, notifications: [{ id, app, package,
    //    title, text, time, icon, replyId, clearable, actions }] }]
    property var devices: []
    // the paired phone in reach, the one the bar and flyout show
    readonly property var device: devices.find(d => d.paired && d.reachable) || null
    readonly property bool connected: device !== null
    // a phone asking to pair, waiting for Accept
    readonly property var request: devices.find(d => d.pairing === "incoming") || null

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }

    function pair(id) { send({ cmd: "pair", id: id }) }
    function unpair(id) { send({ cmd: "unpair", id: id }) }
    function accept(id) { send({ cmd: "accept", id: id }) }
    function reject(id) { send({ cmd: "reject", id: id }) }
    function refresh() { send({ cmd: "refresh" }) }
    function ring() { if (device) send({ cmd: "ring", id: device.id }) }
    function share(paths) { if (device && paths.length) send({ cmd: "share", id: device.id, paths: paths }) }
    function reply(n, text) { if (device) send({ cmd: "reply", id: device.id, replyId: n.replyId, text: text }) }
    function dismiss(n) { if (device) send({ cmd: "dismiss", id: device.id, nid: n.id }) }
    function act(n, action) { if (device) send({ cmd: "action", id: device.id, nid: n.id, action: action }) }

    // files to send, picked in a dialog
    readonly property bool canPick: zenityProbe.found
    function pickFiles() {
        if (device && !picker.running) picker.running = true
    }

    Process {
        id: proc
        running: Settings.phoneLinkOn
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/phone-link.py"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                var m
                try { m = JSON.parse(line) } catch (e) { return }
                if (m.event === "state") root.devices = m.devices
                else if (m.event === "ready") { root.hostName = m.name; root.error = "" }
                else if (m.event === "error") root.error = m.text
            }
        }
        onRunningChanged: if (!running) root.devices = []
    }

    Process {
        id: picker
        command: ["zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Send to the phone"]
        stdout: StdioCollector {
            onStreamFinished: root.share(text.split("\n").filter(p => p !== ""))
        }
    }

    CommandProbe { id: zenityProbe; name: "zenity" }

    IpcHandler {
        target: "phonelink"
        function ring(): void { root.ring() }
        function share(path: string): void { root.share([path]) }
        function status(): string {
            if (!root.running) return "off"
            if (!root.connected) return root.error || "no phone in reach"
            return root.device.name + ", " + root.device.battery + "%"
        }
    }
}
