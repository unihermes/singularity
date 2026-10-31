// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageBluetooth.qml
//
// The adapter, paired devices and what's in range, straight on Quickshell's
// Bluetooth service (BlueZ keeps the bonds). The adapter is a card pinned
// on top with Discoverable and Pairable chips and the round power button.
// Each paired device is a card: its icon, name, kind and state, the
// battery as bars, Connect / Disconnect, and behind its ⋯ Rename, Reconnect
// by itself, the address and Remove. Pair a new device starts a scan;
// devices in range are pills with Pair, unnamed ones behind a last pill.

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

    // `name` is BlueZ's Alias; nameless, BlueZ fills it with a dashed MAC
    function labelOf(d) {
        var aliasIsMac = d.name === d.address.replace(/:/g, "-")
        return d.name !== "" && !aliasIsMac ? d.name
            : d.deviceName !== "" ? d.deviceName : d.address
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
    readonly property bool scanning: poweredOn && adapter.discovering

    // BlueZ turns discoverable off by itself after discoverableTimeout
    // seconds (0: never), so the chip counts down to it.
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
    Component.onDestruction: if (scanning) adapter.discovering = false

    pinned: ConnHero {
        glyph: !page.poweredOn ? BtKind.adapterOff
            : page.connectedCount > 0 ? BtKind.adapterLinked : BtKind.adapterOn
        eyebrow: page.adapter ? "Adapter" + "  ·  " + page.adapter.adapterId : ""
        title: !page.adapter ? "No adapter found"
            : page.blocked ? "Blocked by rfkill"
            : page.poweredOn ? "Bluetooth is on" : "Bluetooth is off"
        line: !page.adapter ? "BlueZ reports no Bluetooth adapter"
            : page.blocked ? "Unblock it to power on"
            : !page.poweredOn ? "Turn it on to reach your devices"
            : "Others see it as " + page.adapter.name + "  ·  "
                + (page.connectedCount > 0 ? page.connectedCount + " connected" : "nothing connected")
        on: page.poweredOn
        powerEnabled: !!page.adapter && !page.blocked
        onToggled: page.setPowered(!page.poweredOn)

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
    }

    // --- your devices -----------------------------------------------------

    FlyoutHeading { text: "YOUR DEVICES" + (page.poweredOn ? "  " + page.paired.length : "") }

    // A paired device's card; its ⋯ opens the rest in the card.
    component DeviceCard: ConnTile {
        id: card
        required property var modelData
        readonly property var d: modelData
        readonly property string name: page.labelOf(d)
        readonly property bool isOpen: page.openAddr === d.address
        readonly property bool settling: d.state === BluetoothDeviceState.Connecting
            || d.state === BluetoothDeviceState.Disconnecting

        width: parent ? parent.cell : 0
        clickable: false
        glyph: BtKind.glyph(d.icon)
        lit: d.connected
        title: name
        caption: BtKind.word(d.icon) + "  ·  " + (d.state === BluetoothDeviceState.Connecting ? "Connecting…"
            : d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
            : d.connected ? "Connected" : "Not connected")

        corner: IconButton {
            implicitWidth: Theme.chipHeight
            implicitHeight: Theme.chipHeight
            icon: "󰇘"
            lit: card.isOpen
            onClicked: {
                page.openAddr = card.isOpen ? "" : card.d.address
                page.renaming = ""
            }
        }

        // the battery, in a fixed space so closed cards line up
        Item {
            width: parent.width
            height: Theme.fontCaption * 3 + Theme.spaceS * 3

            BatteryBars {
                id: bars
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                device: card.d
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: bars.bars.length === 0
                text: card.d.connected ? "No battery reading" : "Battery shows while connected"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }

        FlyoutChip {
            text: card.d.state === BluetoothDeviceState.Connecting ? "Connecting…"
                : card.d.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                : card.d.connected ? "Disconnect" : "Connect"
            selected: !card.d.connected && !card.settling
            enabled: !card.settling
            onClicked: card.d.connected ? card.d.disconnect() : card.d.connect()
        }

        // opened: Rename, Reconnect by itself, the address, Remove
        Column {
            visible: card.isOpen
            width: parent.width
            topPadding: Theme.spaceS
            spacing: Theme.spaceS

            Rectangle { width: parent.width; height: Theme.borderWidth; color: Theme.stroke }

            Flow {
                width: parent.width
                spacing: Theme.spaceS

                FlyoutChip {
                    icon: BtKind.rename
                    text: "Rename"
                    selected: page.renaming === card.d.address
                    onClicked: {
                        if (page.renaming === card.d.address) { page.renaming = ""; return }
                        page.renaming = card.d.address
                        newName.text = card.name
                        Qt.callLater(newName.forceFocus)
                    }
                }
                FlyoutChip {
                    icon: card.d.trusted ? "󰄬" : ""
                    text: "Reconnect by itself"
                    selected: card.d.trusted
                    onClicked: card.d.trusted = !card.d.trusted
                }
            }

            // an empty name goes back to the one the device advertises
            FlyoutInput {
                id: newName
                visible: page.renaming === card.d.address
                width: parent.width
                echoPassword: false
                placeholder: card.d.deviceName !== "" ? card.d.deviceName : "name"
                hints: ["Enter save"]
                onAccepted: {
                    card.d.name = text.trim()
                    page.renaming = ""
                }
                onEscapePressed: page.renaming = ""
            }

            // the address copies on a click
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: addrMouse.copied ? "Copied" : card.d.address
                    + (card.d.deviceName !== "" && card.d.deviceName !== card.name ? "  ·  " + card.d.deviceName : "")
                color: addrMouse.copied ? Theme.good : addrMouse.containsMouse ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption

                MouseArea {
                    id: addrMouse
                    property bool copied: copiedTimer.running
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", "--", card.d.address])
                        copiedTimer.restart()
                    }
                    Timer { id: copiedTimer; interval: 1200 }
                }
            }

            // unpair and drop it from BlueZ, so it has to be paired again
            FlyoutChip {
                text: "󰆴 Remove"
                confirmText: "Remove " + card.name + "?"
                onClicked: {
                    page.openAddr = ""
                    card.d.forget()
                }
            }
        }
    }

    TileGrid {
        visible: page.poweredOn
        columns: 3

        Repeater {
            model: ScriptModel { values: page.poweredOn ? page.paired : []; objectProp: "address" }
            DeviceCard {}
        }

        ConnTile {
            width: parent.cell
            label: "Pair a new device"
            glyph: page.scanning ? BtKind.scanning : "󰐕"
            title: "Pair a new device"
            caption: page.scanning ? "Scanning; pick it in range below" : "Starts a scan"
            lit: page.scanning
            onClicked: page.adapter.discovering = true
        }
    }

    FlyoutRow {
        visible: !page.poweredOn
        enabled: false
        label: "The radio is off"
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
            visible: page.poweredOn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: rangeHeading.lift
            icon: page.scanning ? BtKind.scanning : ""
            spinning: page.scanning
            text: page.scanning ? "Stop" : "Scan"
            selected: page.scanning
            onClicked: page.adapter.discovering = !page.adapter.discovering
        }
    }

    // each a pill: its icon and name, then Pair; the unnamed behind the last
    component NearbyPill: Rectangle {
        id: pill
        property string glyph: ""
        property string name: ""
        property bool faint: false
        default property alias trailing: end.data
        signal clicked()

        width: row.implicitWidth + Theme.spaceL + Theme.spaceS
        height: Theme.chipHeight + Theme.spaceS * 2
        radius: Theme.pill(height)
        color: Theme.controlFill(pillMouse.containsMouse ? Theme.hoverFillSoft : "transparent")
        border.width: Theme.borderWidth
        border.color: pillMouse.containsMouse ? Theme.strokeHover : Theme.stroke

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }

        Row {
            id: row
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: pill.glyph
                color: pill.faint ? Theme.subtext : Theme.textStrong
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.name
                color: pill.faint ? Theme.subtext : Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Row {
                id: end
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Flow {
        visible: page.poweredOn && (page.nearby.length > 0 || page.unnamedCount > 0)
        width: parent.width
        spacing: Theme.spaceS

        Repeater {
            model: ScriptModel { values: page.poweredOn ? page.nearby : []; objectProp: "address" }

            NearbyPill {
                id: near
                required property var modelData
                glyph: BtKind.glyph(modelData.icon)
                name: page.labelOf(modelData)
                onClicked: BtPairing.pair(modelData)

                FlyoutChip {
                    text: near.modelData.pairing ? "Pairing…" : "Pair"
                    enabled: !near.modelData.pairing
                    onClicked: BtPairing.pair(near.modelData)
                }
            }
        }

        NearbyPill {
            visible: page.unnamedCount > 0
            faint: true
            name: page.showUnnamed ? "Hide unnamed" : "Show " + page.unnamedCount + " unnamed"
            onClicked: page.showUnnamed = !page.showUnnamed
        }
    }

    FlyoutRow {
        visible: !page.poweredOn || page.nearby.length === 0
        enabled: false
        label: !page.poweredOn ? "The radio is off"
            : page.scanning ? "Nothing found yet"
            : "Nothing in range; scan to look"
    }
}
