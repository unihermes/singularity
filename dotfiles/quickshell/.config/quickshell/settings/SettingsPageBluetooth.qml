// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageBluetooth.qml
//
// The adapter, what's paired to it, and what's in range.
//
// Straight onto Quickshell's Bluetooth service (BlueZ), the same objects the
// bar module and its flyout read, so a device connected here is connected
// everywhere at once. Nothing to persist: BlueZ keeps the bonds.
//
// Rows are flyouts/BtDeviceRow.qml in its `detailed` form, which keeps the
// pair / trust / connect dance in one place. A paired device opens in place
// to connect, rename, stop it reconnecting by itself, or remove it.
//
// What this page has that the flyout doesn't: the adapter's own identity,
// discoverable and pairable, each device's settings, the nearby list
// uncapped, and a way to see the unnamed devices the flyout only counts.

import Quickshell
import Quickshell.Bluetooth
import QtQuick
import "../services"
import "../services/BtKind.js" as BtKind
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Bluetooth"
    description: "The adapter, paired devices and what's in range."

    readonly property var adapter: Bluetooth.defaultAdapter

    // Repeated from the bar's helpers rather than shared: they need the
    // BluetoothAdapterState enum, which only a QML file importing
    // Quickshell.Bluetooth can see.
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

    // Show the unnamed advertisements too. Not persisted: BlueZ reports every
    // BLE privacy beacon in range as a nameless rotating address, dozens of
    // rows that can't be paired with.
    property bool showUnnamed: false
    // the paired device opened for its settings, and the one being renamed
    property string openAddr: ""
    property string renaming: ""

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
    readonly property int connectedCount: paired.filter(d => d.connected).length

    // BlueZ turns discoverable off by itself after discoverableTimeout
    // seconds (0: never), so the hint counts down to it.
    readonly property bool discoverable: !!adapter && adapter.discoverable
    readonly property int discTimeout: adapter ? adapter.discoverableTimeout : 0
    property real discUntil: 0
    property real now: Date.now()

    onDiscoverableChanged: if (discoverable) discUntil = Date.now() + discTimeout * 1000
    Component.onCompleted: if (discoverable) discUntil = Date.now() + discTimeout * 1000

    Timer {
        running: page.discoverable && page.discTimeout > 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: page.now = Date.now()
    }

    function clock(sec) {
        sec = Math.max(0, Math.round(sec))
        return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0")
    }
    function span(sec) {
        return sec % 60 === 0 ? (sec / 60) + " min" : sec + " s"
    }

    // A scan left running keeps the radio busy and churns the list, so it is
    // stopped on the way out -- the flyout does the same when it closes.
    Component.onDestruction: if (poweredOn && adapter.discovering) adapter.discovering = false

    // --- adapter ---------------------------------------------------------

    FlyoutHeading { text: "ADAPTER" }

    // the adapter: its name, interface and what's on it, and the power switch
    HeadCard {
        glyph: !page.poweredOn ? BtKind.adapterOff
            : page.connectedCount > 0 ? BtKind.adapterLinked : BtKind.adapterOn
        glyphColor: page.poweredOn ? Theme.textStrong : Theme.muted
        title: !page.adapter ? "No adapter found"
            : page.blocked ? "Blocked by rfkill"
            : !page.poweredOn ? "Bluetooth is off"
            : page.adapter.name
        lines: [!page.adapter ? "BlueZ reports no Bluetooth adapter"
            : page.blocked ? "Unblock it to power on"
            : !page.poweredOn ? "Turn it on to reach your devices"
            : [page.adapter.adapterId,
               page.paired.length + " paired",
               page.connectedCount > 0 ? page.connectedCount + " connected" : "nothing connected"
              ].join("  ·  ")]
        rule: page.poweredOn

        Switch {
            checked: page.poweredOn
            enabled: !!page.adapter && !page.blocked
            onToggled: page.setPowered(!page.poweredOn)
        }
    }

    SettingsField {
        visible: page.poweredOn
        label: "Discoverable"
        hint: page.discoverable
            ? (page.discTimeout > 0
                ? "Visible as " + page.adapter.name + " for " + page.clock((page.discUntil - page.now) / 1000)
                : "Visible as " + page.adapter.name)
            : page.discTimeout > 0 ? "Turns itself off after " + page.span(page.discTimeout)
            : "Lets other devices find this one"

        Switch {
            anchors.right: parent.right
            checked: page.discoverable
            onToggled: page.adapter.discoverable = !page.discoverable
        }
    }

    SettingsField {
        visible: page.poweredOn
        label: "Pairable"
        hint: "Accept pairing started by other devices"

        Switch {
            anchors.right: parent.right
            checked: !!page.adapter && page.adapter.pairable
            onToggled: page.adapter.pairable = !page.adapter.pairable
        }
    }

    // --- paired ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PAIRED" + (page.poweredOn ? "  " + page.paired.length : "") }

    // A battery part (or the whole battery) as a level chip.
    component BatteryField: SettingsField {
        id: battery
        property int level: 0

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: battery.level + "%"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Slider {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(140)
                value: battery.level
                interactive: false
                fillColor: Theme.good
            }
        }
    }

    // A paired device and the settings it opens under itself.
    component PairedDevice: Column {
        id: dev
        required property var modelData
        readonly property var d: modelData
        readonly property bool isOpen: page.openAddr === d.address
        readonly property bool settling: d.state === BluetoothDeviceState.Connecting
            || d.state === BluetoothDeviceState.Disconnecting
        // [left, right, case] for earbuds, or null
        readonly property var parts: d.connected && !d.batteryAvailable ? (BtBattery.parts[d.address] || null) : null
        readonly property int level: BtBattery.level(d)

        width: parent ? parent.width : 0

        BtDeviceRow {
            id: row
            device: dev.d
            detailed: true
            open: dev.isOpen
            onOpened: {
                page.openAddr = dev.isOpen ? "" : dev.d.address
                page.renaming = ""
            }
        }

        SettingsIndent {
            visible: dev.isOpen

            FlyoutChip {
                text: dev.d.state === BluetoothDeviceState.Connecting ? "Connecting…"
                    : dev.d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                    : dev.d.connected ? "Disconnect" : "Connect"
                selected: !dev.d.connected && !dev.settling
                enabled: !dev.settling
                onClicked: dev.d.connected ? dev.d.disconnect() : dev.d.connect()
            }

            Repeater {
                model: dev.parts ? ["Left", "Right", "Case"] : []
                BatteryField {
                    required property string modelData
                    required property int index
                    visible: dev.parts[index] >= 0
                    label: modelData
                    level: Math.max(0, dev.parts[index])
                }
            }
            BatteryField {
                visible: !dev.parts && dev.level >= 0
                label: "Battery"
                level: Math.max(0, dev.level)
            }
            SettingsValue {
                visible: !dev.d.connected
                label: "Battery"
                hint: "Shows while connected"
                value: "—"
            }

            SettingsField {
                label: "Reconnect by itself"
                hint: "When it's turned on nearby"
                Switch {
                    anchors.right: parent.right
                    checked: dev.d.trusted
                    onToggled: dev.d.trusted = !dev.d.trusted
                }
            }

            SettingsField {
                visible: page.renaming !== dev.d.address
                label: "Name"
                hint: "What this computer calls it"

                Row {
                    anchors.right: parent.right
                    spacing: Theme.spaceS

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.label
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontBody
                    }
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: BtKind.rename
                        onClicked: {
                            page.renaming = dev.d.address
                            newName.text = row.label
                            Qt.callLater(newName.forceFocus)
                        }
                    }
                }
            }

            // an empty name goes back to the one the device advertises
            Item {
                visible: page.renaming === dev.d.address
                width: parent.width
                height: newName.implicitHeight

                FlyoutInput {
                    id: newName
                    anchors.left: parent.left
                    anchors.right: save.left
                    anchors.rightMargin: Theme.spaceM
                    echoPassword: false
                    placeholder: dev.d.deviceName !== "" ? dev.d.deviceName : "name"
                    hints: ["Enter save"]
                    onAccepted: save.clicked()
                    onEscapePressed: page.renaming = ""
                }
                FlyoutChip {
                    id: save
                    anchors.right: cancel.left
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Save"
                    selected: true
                    onClicked: {
                        dev.d.name = newName.text.trim()
                        page.renaming = ""
                    }
                }
                FlyoutChip {
                    id: cancel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cancel"
                    onClicked: page.renaming = ""
                }
            }

            SettingsValue { label: "Type"; value: BtKind.word(dev.d.icon) }
            SettingsValue { label: "Address"; value: dev.d.address; copyable: true }

            // Unpair and drop it from BlueZ entirely, so it moves back to
            // nearby (or vanishes, if it's off) and has to be paired again.
            FlyoutChip {
                text: "󰆴 Remove device"
                confirmText: "Remove " + row.label + "?"
                onClicked: {
                    page.openAddr = ""
                    dev.d.forget()
                }
            }
        }
    }

    Repeater {
        model: ScriptModel { values: page.poweredOn ? page.paired : [] }
        PairedDevice {}
    }

    FlyoutRow {
        visible: !page.poweredOn || page.paired.length === 0
        enabled: false
        label: page.poweredOn ? "Nothing paired yet" : "The radio is off"
    }

    // --- in range ---------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }

    // the heading shares its line with Scan
    Item {
        readonly property bool isSectionBreak: true
        readonly property bool sectioned: true
        width: parent.width
        height: Math.max(Theme.controlSize, rangeHeading.implicitHeight)

        FlyoutHeading {
            id: rangeHeading
            firstInColumn: false
            anchors.left: parent.left
            anchors.right: scan.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "IN RANGE" + (page.poweredOn && page.nearby.length > 0 ? "  " + page.nearby.length : "")
        }

        FlyoutChip {
            id: scan
            readonly property bool running: page.poweredOn && page.adapter.discovering
            visible: page.poweredOn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: rangeHeading.lift
            icon: running ? BtKind.scanning : ""
            spinning: running
            text: running ? "Stop" : "Scan"
            selected: running
            onClicked: page.adapter.discovering = !page.adapter.discovering
        }
    }

    Repeater {
        model: ScriptModel { values: page.poweredOn ? page.nearby : [] }
        BtDeviceRow { required property var modelData; device: modelData; detailed: true }
    }

    FlyoutRow {
        visible: page.poweredOn && page.unnamedCount > 0
        label: page.showUnnamed ? "Hide unnamed" : "Show " + page.unnamedCount + " unnamed"
        trailing: page.showUnnamed ? "󰅀" : "can't pair  󰅂"
        onActivated: page.showUnnamed = !page.showUnnamed
    }

    FlyoutRow {
        visible: !page.poweredOn || page.nearby.length === 0
        enabled: false
        label: !page.poweredOn ? "The radio is off"
            : page.adapter.discovering ? "Nothing found yet"
            : "Nothing in range; scan to look"
    }
}
