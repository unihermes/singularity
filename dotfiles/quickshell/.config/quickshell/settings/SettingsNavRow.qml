// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsNavRow.qml
//
// One entry in the Settings window's sidebar: an icon column, a label, and
// the left-edge tick FlyoutRow uses for the current entry -- a fill would
// read as hover next to the hover highlight.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false

    signal clicked()

    width: parent ? parent.width : 0
    implicitHeight: Theme.fieldHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.selected ? Theme.selectedFill
            : mouse.containsMouse ? Theme.hoverFillSoft : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.indicatorWidth
        height: parent.height - 8
        radius: width / 2
        color: Theme.accent
        visible: root.selected
    }

    Item {
        id: iconCell
        x: Theme.spaceL
        width: Theme.iconCell

        height: parent.height

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.selected ? Theme.accent : mouse.containsMouse ? Theme.textStrong : Theme.subtext

            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
    }

    Text {
        anchors.left: iconCell.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: root.selected || mouse.containsMouse ? Theme.textStrong : Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
