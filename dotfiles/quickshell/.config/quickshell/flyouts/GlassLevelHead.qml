// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassLevelHead.qml
//
// A Glass level card's title line; the words at its end (a device) may open a list.

import QtQuick
import "../services"

Item {
    id: lh
    property string title: ""
    property string device: ""
    property bool chevron: false
    property bool expanded: false
    signal deviceClicked()
    width: parent ? parent.width : 0
    height: Theme.fs(18)
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: lh.title
        color: Theme.textStrong
        font.family: Theme.fontText
        font.weight: Theme.weightStrong
        font.pixelSize: Theme.fontSmall
    }
    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.6)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        text: lh.device + (lh.chevron ? (lh.expanded ? "  󰅀" : "  󰅂") : "")
        color: devMouse.containsMouse ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
        MouseArea {
            id: devMouse
            anchors.fill: parent
            enabled: lh.chevron
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: lh.deviceClicked()
        }
    }
}
