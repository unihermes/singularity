// Neutrino - Quickshell
// ~/.config/quickshell/BluetoothFlyout.qml
//
// Split out of shell.qml. Needs bar's adapter-state helpers.

import Quickshell.Bluetooth
import QtQuick
import "../services"

FlyoutPanel {
    id: btFlyout
    flyout: "bluetooth"
    menuWidth: 280

    required property var bar

    // Discovery is started only by the Scan row, never by opening
    // the panel: it keeps the radio busy and churns the list, and
    // most visits here are to connect something already paired.
    // Closing still stops it, so a scan can't be left running.
    onOpenChanged: {
        if (open) return
        var a = Bluetooth.defaultAdapter
        if (bar.btAdapterOn(a)) a.discovering = false
    }

    FlyoutHeading { text: "BLUETOOTH" }

    FlyoutRow {
        readonly property var adapter: Bluetooth.defaultAdapter
        label: bar.btAdapterBlocked(adapter) ? "Blocked (rfkill)"
            : bar.btAdapterOn(adapter) ? "Powered on" : "Powered off"
        trailing: bar.btAdapterOn(adapter) ? "" : ""
        onActivated: {
            var a = Bluetooth.defaultAdapter
            bar.setBtPowered(a, !bar.btAdapterOn(a))
        }
    }

    FlyoutRow {
        readonly property var adapter: Bluetooth.defaultAdapter
        // discovery is meaningless with the radio off, and bluez
        // errors rather than ignoring the request
        visible: bar.btAdapterOn(adapter)
        label: (adapter && adapter.discovering) ? "Scanning" : "Scan"
        trailing: (adapter && adapter.discovering) ? "stop" : adapter ? adapter.adapterId : ""
        onActivated: {
            var a = Bluetooth.defaultAdapter
            if (bar.btAdapterOn(a)) a.discovering = !a.discovering
        }
    }

    // BlueZ hands back everything the radio hears -- here ~27
    // devices, of which only 5 have a name. The rest are BLE privacy
    // advertisements (phones, watches, tags) broadcasting a rotating
    // random address and nothing else. They can't be paired with and
    // they bury the device you're looking for.
    function btKeep(d) {
        if (d.paired || d.connected) return true
        if (d.deviceName !== "") return true
        // nameless hardware BlueZ could still classify: a headset
        // that hasn't answered a name request yet still reports a
        // device class, where a privacy beacon reports nothing
        return d.icon !== ""
    }

    function btAll() {
        var a = Bluetooth.defaultAdapter
        return (a && a.devices) ? a.devices.values : []
    }

    function btByName(list) {
        return list.sort(function(x, y) {
            if (x.connected !== y.connected) return x.connected ? -1 : 1
            return (x.deviceName || "").localeCompare(y.deviceName || "")
        })
    }

    // things you've paired before, whether or not they're in range
    function btSaved() {
        return btByName(btAll().filter(function(d) {
            return d.paired || d.connected
        }))
    }

    // everything else the scan turned up
    function btNearby() {
        return btByName(btAll().filter(function(d) {
            return !d.paired && !d.connected && btFlyout.btKeep(d)
        }))
    }

    function btHiddenCount() {
        return btAll().filter(function(d) {
            return !d.paired && !d.connected && !btFlyout.btKeep(d)
        }).length
    }

    FlyoutHeading {
        text: "SAVED"
        visible: btFlyout.btSaved().length > 0
    }

    Repeater {
        model: btFlyout.btSaved()
        BtDeviceRow { required property var modelData; device: modelData }
    }

    FlyoutHeading {
        text: "NEARBY"
        visible: btFlyout.btNearby().length > 0
    }

    Repeater {
        model: btFlyout.btNearby().slice(0, 10)
        BtDeviceRow { required property var modelData; device: modelData }
    }

    FlyoutRow {
        label: "No devices"
        enabled: false
        visible: btFlyout.btSaved().length === 0 && btFlyout.btNearby().length === 0
    }

    FlyoutRow {
        label: "+ " + btFlyout.btHiddenCount() + " unnamed"
        enabled: false
        visible: btFlyout.btHiddenCount() > 0
    }
}
