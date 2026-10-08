// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BtDeviceRow.qml
//
// One Bluetooth device in the flyout. Extends FlyoutRow rather than wrapping
// one so it still behaves like a plain row inside the flyout's Column --
// a wrapper would have to forward width and height by hand.
//
// Shared by the saved and nearby sections, which differ only in which
// devices they feed it, and by the Settings page, which sets `detailed`:
// the type icon and the state in words, and a paired device opens in place
// (opened()) rather than connecting.

import Quickshell.Bluetooth
import QtQuick
import "../services"
import "../services/BtKind.js" as BtKind

FlyoutRow {
    id: root

    required property var device

    property bool detailed: false
    // the open one, on the Settings page
    property bool open: false
    signal opened()

    // `name` is BlueZ's Alias: what it was renamed to, or the advertised
    // deviceName. With no name known BlueZ fills it with a dashed copy of
    // the MAC, so it can't be used to detect "nameless".
    readonly property bool aliasIsMac: device.name === device.address.replace(/:/g, "-")
    label: device.name !== "" && !aliasIsMac ? device.name
        : device.deviceName !== "" ? device.deviceName : device.address

    readonly property bool connecting: device.state === BluetoothDeviceState.Connecting
    readonly property bool disconnecting: device.state === BluetoothDeviceState.Disconnecting
    busy: device.pairing || connecting || disconnecting

    leadingIcon: detailed ? BtKind.glyph(device.icon) : ""

    trailing: {
        if (device.pairing) return "pairing"
        if (connecting) return "connecting"
        if (disconnecting) return "disconnecting"
        if (detailed) {
            if (!device.paired && !device.connected) return BtKind.word(device.icon)
            var lv = BtBattery.level(device)
            return (lv >= 0 ? BtKind.battery(lv) + " " + lv + "%    " : "")
                + (device.connected ? "Connected" : "Not connected")
                + "  " + (open ? "󰅀" : "󰅂")
        }
        if (device.connected) return BtBattery.describe(device) || ""
        if (device.paired) return ""
        return "new"
    }

    highlighted: device.connected || open

    // Unpair and drop it from BlueZ entirely, so it moves back to nearby
    // (or vanishes, if it's off) and has to be paired again to reconnect.
    actionIcon: device.paired && !detailed ? "󰆴" : ""
    actionHint: "Remove " + label + "?"
    onAction: device.forget()

    onActivated: {
        if (detailed && (device.paired || device.connected)) {
            opened()
        } else if (device.connected) {
            device.disconnect()
        } else if (device.paired) {
            device.connect()
        } else {
            BtPairing.pair(device)
        }
    }
}
