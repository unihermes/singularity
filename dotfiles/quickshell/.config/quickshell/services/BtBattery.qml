// Singularity - Quickshell
// ~/.config/quickshell/services/BtBattery.qml
//
// Battery levels of connected Bluetooth devices, for the bar module and the
// flyout. BlueZ's Battery1 covers most devices; AirPods only report over
// Apple's own protocol, read by scripts/airpods-battery.py, which is started
// for every connected device BlueZ has no battery for.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    // address -> [left, right, case], each 0..100 or -1
    property var parts: ({})

    readonly property var connected: {
        var a = Bluetooth.defaultAdapter
        var ds = (a && a.devices) ? a.devices.values : []
        return ds.filter(d => d.connected)
    }

    // 0..100, or -1 when the device reports nothing; for earbuds, the
    // lower of the buds in use
    function level(d) {
        if (!d || !d.connected) return -1
        // BlueZ reports a 0..1 fraction despite the name, like UPower
        if (d.batteryAvailable) return Math.round(d.battery * 100)
        var p = parts[d.address]
        if (!p) return -1
        var buds = [p[0], p[1]].filter(v => v >= 0)
        return buds.length ? Math.min.apply(null, buds) : -1
    }

    // "L 67%  R 68%  Case 90%" for earbuds, "67%" otherwise, "" for none
    function describe(d) {
        if (!d || !d.connected) return ""
        var p = d.batteryAvailable ? null : parts[d.address]
        if (!p) {
            var l = level(d)
            return l >= 0 ? l + "%" : ""
        }
        var out = []
        var names = ["L", "R", "Case"]
        for (var i = 0; i < 3; i++)
            if (p[i] >= 0) out.push(names[i] + " " + p[i] + "%")
        return out.join("  ")
    }

    // the lowest level among connected devices, -1 when none report
    readonly property int lowest: {
        var min = -1
        for (var i = 0; i < connected.length; i++) {
            var l = level(connected[i])
            if (l >= 0 && (min < 0 || l < min)) min = l
        }
        return min
    }

    function setParts(address, value) {
        var next = Object.assign({}, parts)
        if (value) next[address] = value
        else delete next[address]
        parts = next
    }

    Instantiator {
        model: root.connected.filter(d => !d.batteryAvailable)

        Process {
            id: proc
            required property var modelData
            readonly property string address: modelData.address
            command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/airpods-battery.py", address]
            running: true
            stdout: SplitParser {
                onRead: line => {
                    var v = line.split("\t").map(Number)
                    if (v.length === 3) root.setParts(proc.address, v)
                }
            }
            onRunningChanged: if (!running) root.setParts(address, null)
            Component.onDestruction: root.setParts(address, null)
        }
    }
}
