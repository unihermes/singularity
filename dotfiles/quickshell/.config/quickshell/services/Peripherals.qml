// Singularity - Quickshell
// ~/.config/quickshell/services/Peripherals.qml
//
// Battery levels of the things plugged into the machine rather than its
// own: what UPower reports that isn't a power supply (a wireless mouse or
// keyboard through its receiver, a Bluetooth device with a battery) and a
// headset headsetcontrol reads (Channels). For the Devices module and its
// flyout and the Devices page; a warning when one runs low. And the
// headset's own settings (sidetone, auto-off, ...) through headsetcontrol.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    function glyph(type) {
        switch (type) {
        case UPowerDeviceType.Mouse: return "󰍽"
        case UPowerDeviceType.Keyboard: return "󰌌"
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones: return "󰋋"
        case UPowerDeviceType.GamingInput: return "󰊴"
        case UPowerDeviceType.Phone: return "󰄜"
        default: return "󰁹"
        }
    }

    function kind(type) {
        switch (type) {
        case UPowerDeviceType.Mouse: return "Mouse"
        case UPowerDeviceType.Keyboard: return "Keyboard"
        case UPowerDeviceType.Headset: return "Headset"
        case UPowerDeviceType.Headphones: return "Headphones"
        case UPowerDeviceType.GamingInput: return "Controller"
        case UPowerDeviceType.Phone: return "Phone"
        default: return "Device"
        }
    }

    // each { key, name, glyph, kind, level (0..100, -1 while off), charging }
    readonly property var devices: {
        var ds = UPower.devices ? UPower.devices.values : []
        var out = ds.filter(d => d.ready && d.isPresent && !d.powerSupply
                && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Battery)
            .map(d => ({
                key: d.nativePath,
                name: d.model || d.nativePath,
                glyph: glyph(d.type),
                kind: kind(d.type),
                level: Math.round(d.percentage * 100),
                charging: d.state === UPowerDeviceState.Charging
            }))
        if (Channels.headset !== "")
            out.push({
                key: "headset",
                name: Channels.headsetName,
                glyph: "󰋋",
                kind: "Headset",
                level: Channels.headsetLevel,
                charging: Channels.headsetCharging
            })
        return out
    }

    // at or under the first warning and not charging, for the flyout's red
    // and the bar's dot
    function isLow(d) { return d.level >= 0 && d.level <= warnLevels[0] && !d.charging }
    readonly property bool low: devices.some(d => isLow(d))

    // --- low battery ---------------------------------------------------------

    // A notification at 15% and at 5%, once each per discharge; charging
    // re-arms them. key -> the lowest level warned about.
    readonly property var warnLevels: [15, 5]
    property var warned: ({})

    onDevicesChanged: {
        var next = {}
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            var was = d.key in warned ? warned[d.key] : 101
            next[d.key] = was
            if (d.charging || d.level < 0) { next[d.key] = 101; continue }
            var hit = warnLevels.filter(l => d.level <= l && l < was)
            if (hit.length === 0) continue
            next[d.key] = hit[hit.length - 1]
            alert.command = ["notify-send", "-a", "Battery", "-u", next[d.key] <= 5 ? "critical" : "normal",
                             "-i", "battery-caution", d.name + " battery low", d.level + "%"]
            alert.running = false
            alert.running = true
        }
        warned = next
    }

    Process { id: alert }

    // --- the headset's own settings -------------------------------------------

    // key -> [the capability headsetcontrol lists, the flag that sets it].
    // The headset can't report them back, so Settings keeps what was picked
    // (Settings.headsetOptions), sent again each time the headset turns on.
    readonly property var headsetFlags: ({
        sidetone: ["CAP_SIDETONE", "-s"],
        micVolume: ["CAP_MICROPHONE_VOLUME", "--microphone-volume"],
        inactive: ["CAP_INACTIVE_TIME", "-i"],
        muteLed: ["CAP_MICROPHONE_MUTE_LED_BRIGHTNESS", "--microphone-mute-led-brightness"],
        limiter: ["CAP_VOLUME_LIMITER", "--volume-limiter"],
        btPower: ["CAP_BT_WHEN_POWERED_ON", "--bt-when-powered-on"],
        lights: ["CAP_LIGHTS", "-l"],
        prompts: ["CAP_VOICE_PROMPTS", "-v"]
    })
    // the headset's capabilities, read once it's found
    property var headsetCaps: []
    property string headsetError: ""

    function headsetCan(key) { return Channels.headset !== "" && headsetCaps.indexOf(headsetFlags[key][0]) !== -1 }
    // the value picked, or undefined while it's left as the headset has it
    function headsetValue(key) { return Settings.headsetOptions[key] }
    function setHeadset(key, v) {
        Settings.setHeadsetOption(key, v)
        if (Channels.headset === "on") sendHeadset()
    }

    function sendHeadset() {
        if (headsetSet.running) { headsetSet.again = true; return }
        var args = []
        for (var k in headsetFlags) {
            var v = Settings.headsetOptions[k]
            if (v !== undefined && headsetCan(k)) args.push(headsetFlags[k][1], String(Number(v)))
        }
        if (args.length === 0) return
        headsetSet.command = ["headsetcontrol"].concat(args)
        headsetSet.running = true
    }

    function headsetSeen() {
        if (Channels.headset !== "" && headsetCaps.length === 0 && !capsRead.running) capsRead.running = true
        if (Channels.headset === "on") headsetOn.restart()
    }
    Connections {
        target: Channels
        function onHeadsetChanged() { root.headsetSeen() }
    }
    Component.onCompleted: headsetSeen()

    // a moment after it turns on, as it takes a while to answer
    Timer {
        id: headsetOn
        interval: 2000
        onTriggered: root.sendHeadset()
    }

    Process {
        id: capsRead
        command: ["headsetcontrol", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var ds = []
                try { ds = JSON.parse(text).devices || [] } catch (e) {}
                var d = ds.find(d => d.capabilities)
                if (!d) return
                root.headsetCaps = d.capabilities
                if (Channels.headset === "on") root.sendHeadset()
            }
        }
    }

    Process {
        id: headsetSet
        property bool again: false
        stderr: StdioCollector { id: headsetErr }
        onExited: code => {
            root.headsetError = code === 0 ? "" : headsetErr.text.trim().split("\n").pop() || "The headset didn't answer"
            if (again) { again = false; root.sendHeadset() }
        }
    }
}
