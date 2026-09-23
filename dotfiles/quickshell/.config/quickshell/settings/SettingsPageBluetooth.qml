// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageBluetooth.qml
//
// The adapter, what's paired to it, and what's in range.
//
// Straight onto Quickshell's Bluetooth service (BlueZ), the same objects the
// bar module and its flyout read, so a device connected here is connected
// everywhere at once. Nothing to persist: BlueZ keeps the bonds.
//
// Rows are flyouts/BtDeviceRow.qml unchanged -- it already carries the whole
// connect / disconnect / pair / trust / forget dance, and it depends on
// nothing but the device it's given.
//
// What this page has that the flyout doesn't: the adapter's own identity,
// discoverable and pairable (which the flyout has no room for), the nearby
// list uncapped, and a way to see the unnamed devices the flyout only counts.

import Quickshell.Bluetooth
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Bluetooth"
    description: "The adapter, paired devices, and whatever else is in range. BlueZ remembers pairings itself."

    readonly property var adapter: Bluetooth.defaultAdapter

    // Repeated from shell.qml's bar helpers rather than shared: they need the
    // BluetoothAdapterState enum, which only a QML file importing
    // Quickshell.Bluetooth can see, so there is nowhere common to put them
    // that both the bar and a Settings page can reach.
    //
    // adapter.enabled mirrors BlueZ's "Powered", but Quickshell writes it
    // optimistically and never reverts a failed write. adapter.state is fed
    // only by BlueZ's own PropertiesChanged, so it is the true one.
    readonly property bool poweredOn: !!adapter && adapter.state === BluetoothAdapterState.Enabled
    readonly property bool blocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked

    function setPowered(on) {
        if (!adapter || blocked) return
        adapter.enabled = on
    }

    // Show the unnamed advertisements too. Off by default and deliberately not
    // persisted: BlueZ reports every BLE privacy beacon in range (phones,
    // watches, tags) as a nameless rotating address, which is dozens of rows
    // that can't be paired with. It's a "let me look" switch, not a setting.
    property bool showUnnamed: false

    readonly property var allDevices: (adapter && adapter.devices) ? adapter.devices.values : []

    // Nameless hardware BlueZ could still classify -- a headset that hasn't
    // answered a name request yet still reports a device class, where a
    // privacy beacon reports nothing at all.
    function named(d) {
        return d.deviceName !== "" || d.icon !== ""
    }

    function byName(list) {
        return list.sort((x, y) => {
            if (x.connected !== y.connected) return x.connected ? -1 : 1
            return (x.deviceName || "").localeCompare(y.deviceName || "")
        })
    }

    readonly property var paired: byName(allDevices.filter(d => d.paired || d.connected))
    readonly property var nearby: byName(allDevices.filter(d =>
        !d.paired && !d.connected && (page.showUnnamed || page.named(d))))
    readonly property int unnamedCount: allDevices.filter(d =>
        !d.paired && !d.connected && !page.named(d)).length

    // A scan left running keeps the radio busy and churns the list, so it is
    // stopped on the way out -- the flyout does the same when it closes.
    Component.onDestruction: if (poweredOn && adapter.discovering) adapter.discovering = false

    // --- adapter ---------------------------------------------------------

    FlyoutHeading { text: "ADAPTER" }

    SettingsField {
        label: "Bluetooth"
        hint: !page.adapter ? "No adapter found"
            : page.blocked ? "Blocked by rfkill -- unblock it to power the radio on"
            : page.poweredOn ? "On" : "Off"

        FlyoutChip {
            anchors.right: parent.right
            text: page.blocked ? "Blocked" : page.poweredOn ? "On" : "Off"
            selected: page.poweredOn
            enabled: !!page.adapter && !page.blocked
            onClicked: page.setPowered(!page.poweredOn)
        }
    }

    component Detail: SettingsField {
        id: detail
        property string value: ""
        visible: value !== ""
        // no verticalCenter anchor: the control slot's height is its
        // childrenRect, so anchoring to it binds the row's height to itself
        Text {
            anchors.right: parent.right
            text: detail.value
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
    }

    // The adapter carries a friendly name and its hciN id; the MAC lives on
    // BluetoothDevice, not here, so there is no address to show.
    Detail { label: "Name";      value: page.adapter ? page.adapter.name : "" }
    Detail { label: "Interface"; value: page.adapter ? page.adapter.adapterId : "" }

    SettingsField {
        visible: page.poweredOn
        label: "Discoverable"
        hint: "Let other devices see this machine while this page is open"

        FlyoutChip {
            anchors.right: parent.right
            text: page.adapter && page.adapter.discoverable ? "On" : "Off"
            selected: !!page.adapter && page.adapter.discoverable
            onClicked: page.adapter.discoverable = !page.adapter.discoverable
        }
    }

    SettingsField {
        visible: page.poweredOn
        label: "Pairable"
        hint: "Accept pairing requests that other devices start"

        FlyoutChip {
            anchors.right: parent.right
            text: page.adapter && page.adapter.pairable ? "On" : "Off"
            selected: !!page.adapter && page.adapter.pairable
            onClicked: page.adapter.pairable = !page.adapter.pairable
        }
    }

    // --- paired ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PAIRED" }

    Repeater {
        model: page.paired
        BtDeviceRow { required property var modelData; device: modelData }
    }

    Text {
        visible: page.paired.length === 0
        text: "Nothing paired yet"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    // --- in range ---------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }

    SettingsField {
        label: "Nearby"
        hint: !page.poweredOn ? "The radio is off"
            : page.adapter.discovering ? "Scanning…"
            : "Scan to find devices that aren't paired yet"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutChip {
                text: page.unnamedCount === 0 ? "Unnamed"
                    : page.showUnnamed ? "Hide " + page.unnamedCount
                    : "Show " + page.unnamedCount
                selected: page.showUnnamed
                enabled: page.unnamedCount > 0 || page.showUnnamed
                onClicked: page.showUnnamed = !page.showUnnamed
            }
            FlyoutChip {
                text: page.adapter && page.adapter.discovering ? "Stop" : "Scan"
                selected: !!page.adapter && page.adapter.discovering
                enabled: page.poweredOn
                onClicked: page.adapter.discovering = !page.adapter.discovering
            }
        }
    }

    Repeater {
        model: page.nearby
        BtDeviceRow { required property var modelData; device: modelData }
    }

    Text {
        visible: page.poweredOn && page.nearby.length === 0
        text: page.adapter && page.adapter.discovering ? "Nothing found yet" : "Nothing in range"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }
}
