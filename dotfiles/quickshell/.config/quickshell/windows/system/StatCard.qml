// Singularity - Quickshell
// ~/.config/quickshell/windows/system/StatCard.qml
//
// One headline figure on the Overview: a caption, a big number, a meter
// under it and a quiet line of detail. Four of them across the top answer
// "is anything wrong" before any of the lists below are read.
//
// The meter is optional -- a temperature has no natural full scale until
// one is chosen (see PageOverview), and a tile with `fraction` left at -1
// drops the bar and closes up.

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string caption: ""
    property string value: "--"
    property string detail: ""
    // 0..1, or -1 for no meter
    property real fraction: -1
    property bool critical: false
    property bool available: true

    signal activated()

    implicitHeight: body.implicitHeight + Theme.spaceXl * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: mouse.containsMouse ? Theme.hoverFillSoft : "transparent"
        border.width: Theme.borderWidth
        border.color: mouse.containsMouse ? Theme.strokeHover : Theme.stroke
    }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spaceXl
        anchors.rightMargin: Theme.spaceXl
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS

        Text {
            width: parent.width
            text: Theme.heading(root.caption)
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
            font.bold: Theme.headingBold
            font.letterSpacing: Theme.headingSpacing
        }

        Text {
            width: parent.width
            text: root.value
            elide: Text.ElideRight
            color: !root.available ? Theme.subtext
                : root.critical ? Theme.alert : Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontTitle
        }

        Meter {
            visible: root.fraction >= 0
            width: parent.width
            fraction: root.available ? root.fraction : 0
            fillColor: root.critical ? Theme.alert : Theme.meterFill
        }

        Text {
            visible: root.detail !== ""
            width: parent.width
            text: root.detail
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
