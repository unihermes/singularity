// Singularity - Quickshell
// ~/.config/quickshell/system/SortButton.qml
//
// One of the process list's CPU / MEM sort toggles.

import QtQuick
import "../../services"

Item {
    id: sb
    property string label: ""
    property bool on: false
    signal clicked()

    width: sbText.implicitWidth + 12
    height: 18

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: sb.on ? Theme.overlay : (sbMouse.containsMouse ? Theme.surface : "transparent")
        border.width: 1
        border.color: sb.on ? Theme.muted : "transparent"
    }

    Text {
        id: sbText
        anchors.centerIn: parent
        text: sb.label
        color: sb.on ? Theme.bright : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
        font.bold: true
    }

    MouseArea {
        id: sbMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sb.clicked()
    }
}
