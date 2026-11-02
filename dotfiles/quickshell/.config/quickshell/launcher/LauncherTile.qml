// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherTile.qml
//
// An app as a large icon over its name, for the launcher's grids (Grid,
// Home's pinned apps, the Start menu, Spotlight's most used). Lit when
// current; a pin mark in the corner when `pinMark` and it's pinned.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"

Item {
    id: tile

    required property var launcher
    required property var entry
    property bool current: false
    property bool pinMark: false
    property real iconScale: 0.42
    signal hovered()
    signal clicked()

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spaceXs
        radius: Theme.radiusInner
        color: tile.current ? Theme.selectedFill : "transparent"
        border.width: Theme.borderWidth
        border.color: tile.current ? Theme.strokeHover : "transparent"
    }

    IconImage {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        implicitSize: Math.round(Math.min(parent.width, parent.height) * tile.iconScale)
        source: Quickshell.iconPath(tile.entry.icon || "", true)
    }

    Text {
        visible: tile.pinMark && Apps.isPinned(tile.entry)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceS
        text: "󰐃"
        color: Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontCaption
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.12)
        x: Theme.spaceS
        width: parent.width - Theme.spaceS * 2
        horizontalAlignment: Text.AlignHCenter
        text: tile.entry.name || ""
        elide: Text.ElideRight
        color: tile.current ? Theme.textStrong : Theme.text
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: m => {
            if (tile.launcher.pointerMoved(mouse, m.x, m.y)) tile.hovered()
        }
        onClicked: tile.clicked()
    }
}
