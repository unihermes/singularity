// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassLink.qml
//
// A round switch with its name and state beside it: a click on the disc toggles, one on the words opens the details.

import QtQuick
import "../services"

Item {
    id: link
    property string icon: ""
    property string title: ""
    property string caption: ""
    property bool lit: false
    property bool usable: true
    signal toggled()
    signal opened()
    width: parent ? parent.width : 0
    height: Theme.fs(38)

    GlassDot {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        icon: link.icon
        lit: link.lit
        usable: link.usable
        MouseArea {
            anchors.fill: parent
            enabled: link.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: link.toggled()
        }
    }
    Column {
        anchors.left: dot.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        Text {
            width: parent.width
            text: link.title
            elide: Text.ElideRight
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody
        }
        Text {
            width: parent.width
            text: link.caption
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
    }
    MouseArea {
        anchors.left: dot.right
        anchors.right: parent.right
        height: parent.height
        enabled: link.usable
        cursorShape: Qt.PointingHandCursor
        onClicked: link.opened()
    }
}
