// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageBluetooth.qml
//
// The adapter, paired devices and what's in range, straight on Quickshell's
// Bluetooth service (BlueZ keeps the bonds). The adapter card carries the
// power switch and Discoverable / Pairable chips. A paired device
// (BtPairedRow) connects from its row on hover, and opens to Connect,
// Rename and Remove, its battery and Reconnect by itself. Devices in range
// are BtDeviceRow in its `detailed` form, with unnamed ones behind a row.

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

    // repeated from the bar (they need the BluetoothAdapterState enum);
    // adapter.state, not `enabled`, which Quickshell sets optimistically
    readonly property bool poweredOn: !!adapter && adapter.state === BluetoothAdapterState.Enabled
    readonly property bool blocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked

    function setPowered(on) {
        if (!adapter || blocked) return
        adapter.enabled = on
    }

    // show nameless advertisements (mostly BLE privacy beacons); not saved
    property bool showUnnamed: false
    // the paired device opened for its settings, and the one being renamed
    property string openAddr: ""
    property string renaming: ""

    readonly property var allDevices: (adapter && adapter.devices) ? adapter.devices.values : []

    // nameless hardware BlueZ could still classify (a device class)
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
        FlyoutChip {
            visible: page.poweredOn
            text: !page.discoverable ? "Discoverable"
                : page.discTimeout > 0 ? "Visible " + page.clock((page.discUntil - page.now) / 1000)
                : "Visible"
            selected: page.discoverable
            onClicked: page.adapter.discoverable = !page.discoverable
        }
        FlyoutChip {
            visible: page.poweredOn
            text: "Pairable"
            selected: !!page.adapter && page.adapter.pairable
            onClicked: page.adapter.pairable = !page.adapter.pairable
        }

        Switch {
            checked: page.poweredOn
            enabled: !!page.adapter && !page.blocked
            onToggled: page.setPowered(!page.poweredOn)
        }
    }

    // --- paired ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PAIRED" + (page.poweredOn ? "  " + page.paired.length : "") }

    // A paired device and the settings it opens under itself.
    component PairedDevice: Column {
        id: dev
        required property var modelData
        readonly property var d: modelData
        readonly property bool isOpen: page.openAddr === d.address
        readonly property bool settling: d.state === BluetoothDeviceState.Connecting
            || d.state === BluetoothDeviceState.Disconnecting

        width: parent ? parent.width : 0

        BtPairedRow {
            id: row
            device: dev.d
            open: dev.isOpen
            onOpened: {
                page.openAddr = dev.isOpen ? "" : dev.d.address
                page.renaming = ""
            }
        }

        SettingsIndent {
            visible: dev.isOpen

            // what it does, on one line
            Row {
                spacing: Theme.spaceS

                FlyoutChip {
                    text: dev.d.state === BluetoothDeviceState.Connecting ? "Connecting…"
                        : dev.d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                        : dev.d.connected ? "Disconnect" : "Connect"
                    selected: !dev.d.connected && !dev.settling
                    enabled: !dev.settling
                    onClicked: dev.d.connected ? dev.d.disconnect() : dev.d.connect()
                }
                FlyoutChip {
                    icon: BtKind.rename
                    text: "Rename"
                    selected: page.renaming === dev.d.address
                    onClicked: {
                        if (page.renaming === dev.d.address) { page.renaming = ""; return }
                        page.renaming = dev.d.address
                        newName.text = row.label
                        Qt.callLater(newName.forceFocus)
                    }
                }
                // Unpair and drop it from BlueZ entirely, so it moves back
                // to nearby (or vanishes, if it's off) and has to be paired
                // again.
                FlyoutChip {
                    text: "󰆴 Remove"
                    confirmText: "Remove " + row.label + "?"
                    onClicked: {
                        page.openAddr = ""
                        dev.d.forget()
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

            SettingsField {
                label: "Battery"
                hint: dev.d.connected ? "" : "Shows while connected"

                BatteryChips {
                    id: chips
                    anchors.right: parent.right
                    device: dev.d
                }
                Text {
                    anchors.right: parent.right
                    visible: chips.chips.length === 0
                    text: "—"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
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

            // the fine print; the address copies on a click
            Row {
                spacing: Theme.spaceM

                Text {
                    text: BtKind.word(dev.d.icon) + "  ·"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                Text {
                    text: addrMouse.copied ? "Copied" : dev.d.address
                    color: addrMouse.copied ? Theme.good : addrMouse.containsMouse ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall

                    MouseArea {
                        id: addrMouse
                        property bool copied: copiedTimer.running
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["wl-copy", "--", dev.d.address])
                            copiedTimer.restart()
                        }
                        Timer { id: copiedTimer; interval: 1200 }
                    }
                }
                Text {
                    visible: dev.d.deviceName !== "" && dev.d.deviceName !== row.label
                    text: "·  advertises as " + dev.d.deviceName
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
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
