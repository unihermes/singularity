// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassDetailHead.qml
//
// A Glass details card's heading, with the way to the module's own flyout at its end.

import QtQuick
import "../services"

Item {
    id: dh
    property string text: ""
    property string more: ""
    signal moreClicked()
    width: parent ? parent.width : 0
    height: Theme.fs(22)
    Text {
        x: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        text: dh.text
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
    }
    Text {
        visible: dh.more !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        text: dh.more
        color: moreMouse.containsMouse ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
        MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dh.moreClicked()
        }
    }
}
