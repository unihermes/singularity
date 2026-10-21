// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BluetoothFlyout.qml
//
// One heading with the paired count, Scan and the radio switch, then
// each connected device as a card (its kind, battery and Disconnect, an
// earbuds' left, right and case as tiles under it), the other paired ones
// as rows, then anything new the scan turned up, then Settings. Needs
// bar's adapter-state helpers.

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "../services"
import "../services/BtKind.js" as BtKind

FlyoutPanel {
    id: btFlyout
    flyout: "bluetooth"
    menuWidth: Theme.flyoutMenuWidth

    required property var bar

    // Discovery is started only by the Scan button, never by opening
    // the panel: it keeps the radio busy and churns the list, and
    // most visits here are to connect something already paired.
    // Closing still stops it, so a scan can't be left running.
    onOpenChanged: {
        if (open) return
        var a = Bluetooth.defaultAdapter
        if (bar.btAdapterOn(a)) a.discovering = false
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool radioOn: bar.btAdapterOn(adapter)

    FlyoutHeading {
        text: "BLUETOOTH" + (btFlyout.radioOn && btFlyout.saved.length > 0 ? "  " + btFlyout.saved.length : "")
        control: btFlyout.adapter && !bar.btAdapterBlocked(btFlyout.adapter) ? headingControls : null
    }

    // Scan, then the radio switch. Discovery is meaningless with the radio
    // off, and bluez errors rather than ignoring the request, so Scan only
    // shows with it on.
    Component {
        id: headingControls
        Row {
            spacing: Theme.spaceM
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: btFlyout.radioOn
                icon: "󰑐"
                spinning: btFlyout.adapter && btFlyout.adapter.discovering
                onClicked: btFlyout.adapter.discovering = !btFlyout.adapter.discovering
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: btFlyout.radioOn
                onToggled: bar.setBtPowered(btFlyout.adapter, !btFlyout.radioOn)
            }
        }
    }

    // why there's no switch
    FlyoutRow {
        visible: !btFlyout.adapter || bar.btAdapterBlocked(btFlyout.adapter)
        enabled: false
        label: !btFlyout.adapter ? "No adapter" : "Blocked by rfkill"
    }

    // drops nameless BLE privacy advertisements (most of what BlueZ hears;
    // unpairable)
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
    readonly property var saved: btByName(btAll().filter(function(d) {
        return d.paired || d.connected
    }))

    // everything else the scan turned up
    readonly property var nearby: btByName(btAll().filter(function(d) {
        return !d.paired && !d.connected && btFlyout.btKeep(d)
    }))

    readonly property var connected: saved.filter(d => d.connected)
    readonly property var paired: saved.filter(d => !d.connected)

    // each connected device as a card: what it is, its battery (earbuds'
    // left, right and case as tiles under it), Disconnect
    Repeater {
        model: ScriptModel { values: btFlyout.radioOn ? btFlyout.connected : [] }

        Column {
            id: device
            required property var modelData
            readonly property var parts: modelData.batteryAvailable ? null : BtBattery.parts[modelData.address] || null
            width: parent ? parent.width : 0
            spacing: Theme.spaceS

            HeadCard {
                id: card
                readonly property var modelData: device.modelData
                readonly property int battery: BtBattery.level(modelData)
                readonly property bool aliasIsMac: modelData.name === modelData.address.replace(/:/g, "-")
                glyph: BtKind.glyph(modelData.icon)
                glyphColor: Theme.accent
                title: modelData.name !== "" && !aliasIsMac ? modelData.name
                    : modelData.deviceName !== "" ? modelData.deviceName : modelData.address
                lines: [
                    "Connected" + (BtKind.word(modelData.icon) !== "" ? " · " + BtKind.word(modelData.icon) : ""),
                    battery >= 0 && !device.parts ? BtKind.battery(battery) + " " + battery + "% battery" : "",
                ]
                FlyoutChip {
                    text: card.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : "Disconnect"
                    onClicked: card.modelData.disconnect()
                }
            }

            TileGrid {
                visible: !!device.parts
                columns: 3
                Repeater {
                    model: device.parts ? ["Left", "Right", "Case"].map((n, i) => ({ name: n, level: device.parts[i] })) : []
                    FlyoutTile {
                        required property var modelData
                        width: parent.cell
                        centred: true
                        title: modelData.level >= 0 ? modelData.level + "%" : "—"
                        caption: modelData.name
                        dimmed: modelData.level < 0
                    }
                }
            }
        }
    }

    // ScriptModels, not the bare arrays: each change during a scan makes a
    // fresh array, which would rebuild every row
    Repeater {
        model: ScriptModel { values: btFlyout.radioOn ? btFlyout.paired : [] }
        BtDeviceRow { required property var modelData; device: modelData }
    }

    // what the scan found, under the saved ones
    Repeater {
        model: ScriptModel { values: btFlyout.radioOn ? btFlyout.nearby.slice(0, 5) : [] }
        BtDeviceRow { required property var modelData; device: modelData }
    }

    FlyoutRow {
        label: btFlyout.adapter && btFlyout.adapter.discovering ? "Looking for devices…" : "No devices yet; scan to look"
        enabled: false
        visible: btFlyout.radioOn && btFlyout.saved.length === 0 && btFlyout.nearby.length === 0
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: scope.openSettings("bluetooth")
    }
}
