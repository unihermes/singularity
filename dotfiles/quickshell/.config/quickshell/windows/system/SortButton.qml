// Singularity - Quickshell
// ~/.config/quickshell/windows/system/SortButton.qml
//
// One of the process list's CPU / MEM sort toggles.

import QtQuick
import "../../services"

Item {
    id: sb
    property string label: ""
    property bool on: false
    signal clicked()

    width: sbText.implicitWidth + Theme.spaceXl
    height: Theme.controlSize

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: sb.on ? Theme.selectedFill : (sbMouse.containsMouse ? Theme.hoverFillSoft : "transparent")
        border.width: Theme.borderWidth
        border.color: sb.on ? Theme.selectedStroke : "transparent"
    }

    Text {
        id: sbText
        anchors.centerIn: parent
        text: sb.label
        color: sb.on ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
        font.bold: Theme.headingBold

    }

    MouseArea {
        id: sbMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sb.clicked()
    }
}
