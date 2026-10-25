// Singularity - Quickshell
// ~/.config/quickshell/services/Phone.qml
//
// An Android phone over adb: which one is connected (USB), or offers
// wireless debugging over mDNS once paired, its battery, and the phone on
// screen through scrcpy with its sound, its clipboard shared and its own
// screen off, still off once the mirror closes. USB is used when it's plugged in, as it's smoother. Over
// Wi-Fi adb joins the phone only for Mirror and Screenshot and leaves it
// after, so the phone's "Wireless debugging connected" notification is
// only up while it's used (adb's own joining is off: ADB_MDNS_AUTO_CONNECT).
//
// Pairing for Wi-Fi: pair() makes a QR code for the phone's "Pair device
// with QR code" screen, watches mDNS for the phone offering that pairing,
// and pairs. Polls adb only while scrcpy and adb are installed.

pragma Singleton

import Quickshell
import Quickshell.Hyprland
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
    // a phone offering wireless debugging ("192.168.1.64:37915"), to join
    property string wifiAddr: ""
    // Mirror and Screenshot can reach it
    readonly property bool reachable: connected || wifiAddr !== ""
    // for every adb that might start its server
    readonly property var adbEnv: ({ ADB_MDNS_AUTO_CONNECT: "0" })

    // the phone's own name ("Alex's Pixel"), else its model
    property string name: ""
    property int battery: -1
    property bool charging: false

    readonly property bool mirroring: mirrorProc.running

    // --- with the phone link (PhoneLink) too, for the bar and flyout ---

    readonly property bool shown: reachable || unauthorized || PhoneLink.connected || PhoneLink.request !== null
    readonly property string shownName: PhoneLink.connected ? PhoneLink.device.name
        : name || (PhoneLink.devices.find(d => d.paired) || { name: "" }).name
    readonly property bool linkBattery: PhoneLink.connected && PhoneLink.device.battery >= 0
    readonly property int shownBattery: linkBattery ? PhoneLink.device.battery : battery
    readonly property bool shownCharging: linkBattery ? PhoneLink.device.charging : charging

    // --- devices ---

    Timer {
        running: root.available
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!list.running) list.running = true
            if (!scan.running) scan.running = true
        }
    }

    Process {
        id: list
        command: ["adb", "devices", "-l"]
        environment: root.adbEnv
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

    Process {
        id: scan
        command: ["adb", "mdns", "services"]
        environment: root.adbEnv
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.split("\n").find(l => l.indexOf("_adb-tls-connect") !== -1)
                root.wifiAddr = line ? (line.match(/(\d+\.\d+\.\d+\.\d+:\d+)/) || ["", ""])[1] : ""
            }
        }
    }

    // the name stays from the last time it was connected, for the card
    onDeviceChanged: {
        if (device && !name) name = device.model
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

    // app: an Android package to start in it
    function mirror(app) {
        if (mirroring) return
        withPhone((serial, joined) => {
            mirrorProc.joined = joined ? serial : ""
            // the keys as a physical keyboard's, which the lock screen's
            // password field takes too; its output a line at a time, for
            // the texture sizes the window follows
            mirrorProc.command = ["stdbuf", "-oL", "scrcpy", "-s", serial, "--window-title", name || "Phone",
                "--turn-screen-off", "--stay-awake", "--power-off-on-close", "--keyboard=uhid"].concat(app ? ["--start-app=" + app] : [])
            mirrorProc.running = true
        })
    }

    // An app on the phone's screen here (a notification's click): started
    // in the mirror, which opens for it or comes to the front
    function openApp(app) {
        if (!reachable) return
        if (!mirroring) { mirror(app); return }
        withPhone(serial => Quickshell.execDetached({ command: ["adb", "-s", serial, "shell",
            "monkey", "-p", app, "-c", "android.intent.category.LAUNCHER", "1"], environment: adbEnv }))
        const win = Hyprland.toplevels.values.find(t => t.lastIpcObject && t.lastIpcObject.class === "scrcpy")
        if (win) Hyprland.dispatch("hl.dsp.focus({window=\"address:0x" + win.address + "\"})")
    }

    // then(serial, joined): the connected phone as it is, else the one over
    // Wi-Fi joined for this alone (joined), for the caller to leave after
    function withPhone(then) {
        if (device) { then(device.serial, false); return }
        if (wifiAddr === "" || join.running) return
        join.then = then
        join.command = ["adb", "connect", wifiAddr]
        join.running = true
    }

    Process {
        id: join
        property var then: null
        environment: root.adbEnv
        stdout: StdioCollector { id: joinOut }
        onExited: code => {
            if (code === 0 && /connected to/.test(joinOut.text)) then(command[2], true)
            else Quickshell.execDetached(["notify-send", "-a", "Phone", "-i", "phone", "-u", "critical", "Couldn't reach the phone",
                joinOut.text.trim() || "adb connect failed"])
        }
    }

    Process {
        id: mirrorProc
        // the Wi-Fi address joined for it, left when it closes
        property string joined: ""
        stdout: SplitParser { onRead: line => root.pictureSized(line) }
        stderr: StdioCollector { id: mirrorErr }
        onExited: code => {
            if (joined !== "") Quickshell.execDetached(["adb", "disconnect", joined])
            if (code === 0 || code === 2) return
            var lines = mirrorErr.text.trim().split("\n").filter(l => /ERROR/.test(l))
            Quickshell.execDetached(["notify-send", "-a", "Phone", "-i", "phone", "-u", "critical", "Couldn't show the phone",
                lines.length ? lines[lines.length - 1].replace(/^.*ERROR:\s*/, "") : "scrcpy quit"])
        }
    }

    // --- the mirror's window ---

    // A set size, turned with the picture: the largest of its shape inside
    // 70% of its monitor's width and 80% of its height (less the bar), in
    // the monitor's top-right corner. Fitted when it opens and whenever the
    // picture turns (a video gone full screen), which scrcpy reports as a
    // new texture size; a resize by hand holds until the next turn.
    // [width, height] of the phone's picture, empty before the first
    property var mirrorSize: []
    // its gap from the bar and the screen's edge
    readonly property int mirrorMargin: 24

    function pictureSized(line) {
        var m = line.match(/Texture.*?: (\d+)x(\d+)/)
        if (!m) return
        mirrorSize = [parseInt(m[1]), parseInt(m[2])]
        fitTries.tries = 0
        fitTries.restart()
    }

    // until the window's there; then once more, as scrcpy resizes itself
    // when the picture turns, which can land after this
    Timer {
        id: fitTries
        property int tries: 0
        interval: 600
        onTriggered: {
            if (!root.mirroring) return
            var fitted = root.fitMirror()
            if (++tries < (fitted ? 2 : 20)) restart()
        }
    }

    function fitMirror() {
        Hyprland.refreshToplevels()
        const win = Hyprland.toplevels.values.find(t => t.lastIpcObject && t.lastIpcObject.class === "scrcpy")
        const mon = win ? win.monitor : null
        if (!mon || mirrorSize.length !== 2) return false
        const res = (mon.lastIpcObject && mon.lastIpcObject.reserved) || [0, 0, 0, 0]
        const boxW = (mon.width / mon.scale - res[0] - res[2]) * 0.7
        const boxH = (mon.height / mon.scale - res[1] - res[3]) * 0.8
        // width over height of the picture as the phone now stands
        const shape = mirrorSize[0] / Math.max(1, mirrorSize[1])
        const w = Math.round(Math.min(boxW, boxH * shape))
        const h = Math.round(w / shape)
        const addr = "address:0x" + win.address
        Hyprland.dispatch("hl.dsp.window.resize({x=" + w + ", y=" + h + ", window=\"" + addr + "\"})")
        const x = Math.round(mon.x + mon.width / mon.scale - res[2] - w - mirrorMargin)
        const y = Math.round(mon.y + res[1] + mirrorMargin)
        Hyprland.dispatch("hl.dsp.window.move({x=" + x + ", y=" + y + ", window=\"" + addr + "\"})")
        return true
    }

    // The phone's screen as a picture, saved beside the screenshots and copied
    function screenshot() {
        withPhone((serial, joined) => Quickshell.execDetached(["sh", "-c",
            'd="$HOME/Pictures/Screenshots"; mkdir -p "$d"; f="$d/phone_$(date +%Y-%m-%d_%H-%M-%S).png"\n'
            + 'if adb -s "$0" exec-out screencap -p > "$f" && [ -s "$f" ]; then\n'
            + '  wl-copy --type image/png < "$f"; notify-send -a Phone -i "$f" "Phone screenshot saved" "${f##*/}"\n'
            + 'else rm -f "$f"; notify-send -a Phone -u critical "Phone screenshot failed"; fi\n'
            + '[ "$1" = 1 ] && adb disconnect "$0" > /dev/null',
            serial, joined ? "1" : ""]))
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
        environment: root.adbEnv
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
        environment: root.adbEnv
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
                : root.unauthorized ? "waiting for the phone to allow USB debugging"
                : root.wifiAddr !== "" ? "wireless debugging on at " + root.wifiAddr : "no phone"
        }
    }
}
