// Singularity - Quickshell
// ~/.config/quickshell/windows/system/StatCard.qml
//
// One headline figure on the Overview: a caption, a big number, a meter
// under it and a quiet line of detail. Four of them across the top answer
// "is anything wrong" before any of the lists below are read.
//
// The meter is optional -- a temperature has no natural full scale until
// one is chosen (see PageOverview), and a tile with `fraction` left at -1
// drops the bar and closes up. With `history`, the last minute is drawn as
// a line over the meter, so now and just now read together.

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
    // samples for the line, one a second; empty for none
    property var history: []
    property real historyFloor: 0
    property real historyCeiling: 1

    signal activated()

    implicitHeight: body.implicitHeight + Theme.spaceXl * 2

    Rectangle {
        id: card
        readonly property color edge: mouse.containsMouse ? Theme.strokeHover : Theme.stroke
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.controlFill(mouse.containsMouse ? Theme.hoverFillSoft : "transparent")
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        ControlEdge { stroke: card.edge; radius: card.radius }
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
            font.weight: Theme.headingBold ? Theme.weightStrong : Theme.weightBody
            font.letterSpacing: Theme.headingSpacing
        }

        Text {
            width: parent.width
            text: root.value
            elide: Text.ElideRight
            color: !root.available ? Theme.subtext
                : root.critical ? Theme.alert : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontTitle
        }

        Spark {
            visible: root.history.length > 0
            width: parent.width
            height: Theme.row(26)
            bare: true
            series: [{ values: root.history, color: root.critical ? Theme.alert : Theme.accent, fill: true }]
            floor: root.historyFloor
            ceiling: root.historyCeiling
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
            font.weight: Theme.weightBody
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
