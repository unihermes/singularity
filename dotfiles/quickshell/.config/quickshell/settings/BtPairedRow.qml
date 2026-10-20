// Singularity - Quickshell
// ~/.config/quickshell/settings/BtPairedRow.qml
//
// A paired device on the Bluetooth page: its type icon, the name over the
// type and state, the battery as level chips on the right, and
// Connect / Disconnect in their place on hover. A click opens it.

import Quickshell.Bluetooth
import QtQuick
import "../services"
import "../services/BtKind.js" as BtKind
import "../flyouts"

Item {
    id: root

    required property var device
    property bool open: false
    signal opened()

    // `name` is BlueZ's Alias; nameless, BlueZ fills it with a dashed MAC
    readonly property bool aliasIsMac: device.name === device.address.replace(/:/g, "-")
    readonly property string label: device.name !== "" && !aliasIsMac ? device.name
        : device.deviceName !== "" ? device.deviceName : device.address
    readonly property bool settling: device.state === BluetoothDeviceState.Connecting
        || device.state === BluetoothDeviceState.Disconnecting
    readonly property string stateWord: device.state === BluetoothDeviceState.Connecting ? "Connecting…"
        : device.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
        : device.connected ? "Connected" : "Not connected"
    readonly property bool lit: open || hover.hovered

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.fieldHeight, texts.implicitHeight + Theme.spaceM)

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: root.lit ? Theme.hoverFill : "transparent"
    }

    // the open one, or a connected one, has the tick
    Rectangle {
        visible: root.open || root.device.connected
        x: -Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.indicatorWidth
        height: parent.height - Theme.spaceM
        radius: Theme.pill(width)
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.opened()
    }

    Text {
        id: icon
        x: Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell
        horizontalAlignment: Text.AlignHCenter
        text: BtKind.glyph(root.device.icon)
        color: root.device.connected || root.lit ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    Column {
        id: texts
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceM
        anchors.right: right.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
        Text {
            width: parent.width
            text: BtKind.word(root.device.icon) + "  ·  "
                + (root.device.connected && !root.settling ? "<font color='" + Theme.good + "'>" + root.stateWord + "</font>" : root.stateWord)
            textFormat: Text.StyledText
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
    }

    Row {
        id: right
        anchors.right: chevron.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceM

        BatteryChips {
            anchors.verticalCenter: parent.verticalCenter
            visible: !hover.hovered
            device: root.device
        }
        FlyoutChip {
            anchors.verticalCenter: parent.verticalCenter
            visible: hover.hovered
            text: root.settling ? root.stateWord : root.device.connected ? "Disconnect" : "Connect"
            selected: !root.device.connected && !root.settling
            enabled: !root.settling
            onClicked: root.device.connected ? root.device.disconnect() : root.device.connect()
        }
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.open ? "󰅀" : "󰅂"
        color: root.lit ? Theme.text : Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontSmall
    }
}
