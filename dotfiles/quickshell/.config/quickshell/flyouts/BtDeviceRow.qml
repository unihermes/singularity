// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BtDeviceRow.qml
//
// One Bluetooth device in the flyout. Extends FlyoutRow rather than wrapping
// one so it still behaves like a plain row inside the flyout's Column --
// a wrapper would have to forward width and height by hand.
//
// Every row carries the device's type icon and its state in words, with the
// battery once it's connected. In the flyout, pointing at a paired device
// offers Connect or Disconnect, and a click does the same; a new one pairs.
// The Settings page sets `detailed`: a paired device opens in place
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

    leadingIcon: BtKind.glyph(device.icon)

    trailing: {
        if (device.pairing) return "pairing"
        if (connecting) return "connecting"
        if (disconnecting) return "disconnecting"
        if (!device.paired && !device.connected) return BtKind.word(device.icon)
        var lv = BtBattery.level(device)
        return (lv >= 0 ? BtKind.battery(lv) + " " + lv + "%    " : "")
            + (device.connected ? "Connected" : "Not connected")
            + (detailed ? "  " + (open ? "󰅀" : "󰅂") : "")
    }

    highlighted: device.connected || open

    actionText: detailed || !(device.paired || device.connected) ? ""
        : device.connected ? "Disconnect" : "Connect"
    onAction: activated()

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
