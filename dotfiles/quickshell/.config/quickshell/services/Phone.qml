// Singularity - Quickshell
// ~/.config/quickshell/services/Phone.qml
//
// An Android phone over adb: which one is connected (USB, or Wi-Fi once
// paired through wireless debugging, which adb then joins by itself over
// mDNS), its battery, and the phone on screen through scrcpy with its
// sound, its clipboard shared and its own screen off. USB is used when
// it's plugged in, as it's smoother.
//
// Pairing for Wi-Fi: pair() makes a QR code for the phone's "Pair device
// with QR code" screen, watches mDNS for the phone offering that pairing,
// and pairs. Polls `adb devices` only while scrcpy and adb are installed.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool available: scrcpyProbe.found && adbProbe.found

    // [{ serial, state ("device", "unauthorized", "offline"), wifi, model }]
    property var devices: []
    // the one to use: a USB one first, then any over Wi-Fi
    readonly property var device: {
        var ready = devices.filter(d => d.state === "device")
        return ready.find(d => !d.wifi) || ready[0] || null
    }
    // plugged in, but the phone hasn't said yes to this computer yet
    readonly property bool unauthorized: !device && devices.some(d => d.state === "unauthorized")
    readonly property bool connected: device !== null

    // the phone's own name ("Alex's Pixel"), else its model
    property string name: ""
    property int battery: -1
    property bool charging: false

    readonly property bool mirroring: mirrorProc.running

    // --- devices ---

    Timer {
        running: root.available
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!list.running) list.running = true
    }

    Process {
        id: list
        command: ["adb", "devices", "-l"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.split("\n").slice(1).forEach(line => {
                    var f = line.trim().split(/\s+/)
                    if (f.length < 2) return
                    var model = (line.match(/model:(\S+)/) || [])[1] || ""
                    out.push({ serial: f[0], state: f[1], model: model.replace(/_/g, " "),
                               wifi: f[0].indexOf(":") !== -1 || f[0].indexOf("_adb-tls-connect") !== -1 })
                })
                if (JSON.stringify(out) !== JSON.stringify(root.devices)) root.devices = out
            }
        }
    }

    onDeviceChanged: {
        name = device ? device.model : ""
        battery = -1
        if (device) status.run()
    }

    // --- battery and name, a minute apart while connected ---

    Timer {
        running: root.connected
        interval: 60000
        repeat: true
        onTriggered: status.run()
    }

    Process {
        id: status
        function run() {
            if (running || !root.device) return
            command = ["adb", "-s", root.device.serial, "shell",
                "dumpsys battery | grep -E 'level:|powered:'; echo name=$(settings get global device_name)"]
            running = true
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var level = text.match(/level:\s*(\d+)/)
                if (level) root.battery = parseInt(level[1])
                root.charging = /powered:\s*true/.test(text)
                var n = (text.match(/name=(.*)/) || [])[1]
                if (n && n.trim() !== "" && n.trim() !== "null") root.name = n.trim()
            }
        }
    }

    // --- the phone on screen ---

    function toggleMirror() { mirroring ? mirrorProc.signal(15) : mirror() }

    function mirror() {
        if (!device || mirroring) return
        mirrorProc.command = ["scrcpy", "-s", device.serial, "--window-title", name || "Phone",
            "--turn-screen-off", "--stay-awake"]
        mirrorProc.running = true
    }

    Process {
        id: mirrorProc
        stderr: StdioCollector { id: mirrorErr }
        onExited: code => {
            if (code === 0 || code === 2) return
            var lines = mirrorErr.text.trim().split("\n").filter(l => /ERROR/.test(l))
            Quickshell.execDetached(["notify-send", "-a", "Phone", "-u", "critical", "Couldn't show the phone",
                lines.length ? lines[lines.length - 1].replace(/^.*ERROR:\s*/, "") : "scrcpy quit"])
        }
    }

    // The phone's screen as a picture, saved beside the screenshots and copied
    function screenshot() {
        if (!device) return
        Quickshell.execDetached(["sh", "-c",
            'd="$HOME/Pictures/Screenshots"; mkdir -p "$d"; f="$d/phone_$(date +%Y-%m-%d_%H-%M-%S).png"\n'
            + 'adb -s "$0" exec-out screencap -p > "$f" && [ -s "$f" ] || { rm -f "$f"; notify-send -a Phone -u critical "Phone screenshot failed"; exit 1; }\n'
            + 'wl-copy --type image/png < "$f"; notify-send -a Phone -i "$f" "Phone screenshot saved" "${f##*/}"',
            device.serial])
    }

    // --- pairing for Wi-Fi ---

    // "" | "waiting" (the QR is up) | "pairing" | "done" | "failed"
    property string pairState: ""
    property string pairError: ""
    // the QR code's picture, a file under the runtime dir
    property string pairQr: ""
    property string pairName: ""
    property string pairCode: ""

    function pair() {
        cancelPair()
        pairName = "singularity-" + Math.floor(Math.random() * 1e6)
        pairCode = String(100000 + Math.floor(Math.random() * 900000))
        pairQr = ""
        pairError = ""
        pairState = "waiting"
        qrProc.file = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/singularity-adb-pair-" + pairName + ".png"
        // Android's own format for wireless-debugging pairing
        qrProc.command = ["qrencode", "-t", "PNG", "-s", "8", "-m", "2", "-o", qrProc.file,
            "WIFI:T:ADB;S:" + pairName + ";P:" + pairCode + ";;"]
        qrProc.running = true
        pairTimeout.restart()
    }

    function cancelPair() {
        pairWatch.stop()
        pairTimeout.stop()
        if (pairState === "waiting" || pairState === "pairing") pairState = ""
    }

    Process {
        id: qrProc
        property string file: ""
        onExited: code => {
            if (code !== 0) {
                root.pairState = "failed"
                root.pairError = "qrencode isn't installed"
                return
            }
            root.pairQr = "file://" + file
            pairWatch.start()
        }
    }

    // the phone offers <pairName> over mDNS once the code is scanned
    Timer {
        id: pairWatch
        interval: 1000
        repeat: true
        onTriggered: if (!mdns.running) mdns.running = true
    }

    Timer {
        id: pairTimeout
        interval: 180000
        onTriggered: {
            if (root.pairState !== "waiting") return
            pairWatch.stop()
            root.pairState = "failed"
            root.pairError = "The phone didn't scan the code in time"
        }
    }

    Process {
        id: mdns
        command: ["adb", "mdns", "services"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.pairState !== "waiting") return
                var line = text.split("\n").find(l => l.indexOf(root.pairName) !== -1 && l.indexOf("_adb-tls-pairing") !== -1)
                var addr = line ? (line.match(/(\d+\.\d+\.\d+\.\d+:\d+)/) || [])[1] : null
                if (!addr) return
                pairWatch.stop()
                root.pairState = "pairing"
                pairProc.command = ["adb", "pair", addr, root.pairCode]
                pairProc.running = true
            }
        }
    }

    Process {
        id: pairProc
        stdout: StdioCollector { id: pairOut }
        stderr: StdioCollector { id: pairErr }
        onExited: code => {
            pairTimeout.stop()
            var ok = code === 0 && /Successfully paired/i.test(pairOut.text)
            root.pairState = ok ? "done" : "failed"
            root.pairError = ok ? "" : (pairErr.text.trim() || pairOut.text.trim()).split("\n").pop()
        }
    }

    CommandProbe { id: scrcpyProbe; name: "scrcpy" }
    CommandProbe { id: adbProbe; name: "adb" }

    IpcHandler {
        target: "phone"
        function mirror(): void { root.toggleMirror() }
        function screenshot(): void { root.screenshot() }
        function status(): string {
            return root.connected ? root.name + (root.device.wifi ? " (Wi-Fi)" : " (USB)") + ", " + root.battery + "%"
                : root.unauthorized ? "waiting for the phone to allow USB debugging" : "no phone"
        }
    }
}
