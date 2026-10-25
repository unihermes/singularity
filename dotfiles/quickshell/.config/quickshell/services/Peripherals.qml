// Singularity - Quickshell
// ~/.config/quickshell/services/Peripherals.qml
//
// Battery levels of the things plugged into the machine rather than its
// own: what UPower reports that isn't a power supply (a wireless mouse or
// keyboard through its receiver, a Bluetooth device with a battery) and a
// headset headsetcontrol reads (Channels). For the Devices module and its
// flyout; a warning when one runs low.

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

    // each { key, name, glyph, level (0..100, -1 while off), charging }
    readonly property var devices: {
        var ds = UPower.devices ? UPower.devices.values : []
        var out = ds.filter(d => d.ready && d.isPresent && !d.powerSupply
                && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Battery)
            .map(d => ({
                key: d.nativePath,
                name: d.model || d.nativePath,
                glyph: glyph(d.type),
                level: Math.round(d.percentage * 100),
                charging: d.state === UPowerDeviceState.Charging
            }))
        if (Channels.headset !== "")
            out.push({
                key: "headset",
                name: Channels.headsetName,
                glyph: "󰋋",
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
}
