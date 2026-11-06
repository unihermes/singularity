// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassTile.qml
//
// Glass's Control Centre tile: a frosted card with a round button above its
// name and state. One press toggles it.

import QtQuick
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string caption: ""
    property bool lit: false
    property bool usable: true
    signal clicked()

    implicitHeight: Theme.fs(78)
    radius: Theme.fs(16)
    color: mouse.containsMouse && usable ? Theme.washActive : Theme.washHover
    border.width: 1
    border.color: Theme.stroke
    Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

    GlassDot {
        x: Theme.spaceL + 2
        y: Theme.spaceL + 2
        icon: root.icon
        lit: root.lit
        usable: root.usable
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceL + 4
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceL
        spacing: 0
        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody
        }
        Text {
            width: parent.width
            text: root.caption
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.usable) root.clicked()
    }
}
