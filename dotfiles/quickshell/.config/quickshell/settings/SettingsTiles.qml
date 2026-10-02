// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsTiles.qml
//
// A visual picker: one tile per value, each drawing what it does, the
// current one lit with the accent groove (DESIGN.md, Visual pickers). Goes
// under a SettingsField that names the choice.
//
// `model` is [{ value, text }]. `art` is a Component drawn near the top of
// each tile; it reads `parent.value` and can size itself from
// `parent.tileWidth`.

import QtQuick
import "../services"

Grid {
    id: root

    property var model: []
    property var current
    property Component art: null
    property int tileHeight: Theme.fs(70)
    signal picked(var value)

    width: parent ? parent.width : 0
    columns: 4
    spacing: Theme.spaceS
    bottomPadding: Theme.spaceXs

    Repeater {
        model: root.model

        Rectangle {
            id: tile
            required property var modelData
            readonly property bool on: root.current === modelData.value
            width: (root.width - root.spacing * (root.columns - 1)) / root.columns
            height: root.tileHeight
            radius: Theme.radius > 0 ? Theme.radius + 3 : 0
            color: on ? Theme.overlay : tileMouse.containsMouse ? Theme.surface : Theme.panel
            border.width: Theme.borderWidth
            border.color: on ? Theme.channelOuter : tileMouse.containsMouse ? Theme.subtext : Theme.border

            // lit: the groove inside the line, in the accent
            Rectangle {
                visible: tile.on
                anchors.fill: parent
                anchors.margins: Theme.borderWidth
                radius: Math.max(0, parent.radius - Theme.borderWidth)
                color: "transparent"
                border.width: Theme.channelGrooveWidth
                border.color: Theme.accent
            }

            Loader {
                property var value: tile.modelData.value
                property real tileWidth: tile.width
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.spaceL
                sourceComponent: root.art
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spaceS
                text: tile.modelData.text
                color: tile.on || tileMouse.containsMouse ? Theme.textStrong : Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
                font.weight: Theme.weightBody
            }

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(tile.modelData.value)
            }
        }
    }
}
