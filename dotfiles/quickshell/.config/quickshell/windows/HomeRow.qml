// Singularity - Quickshell
// ~/.config/quickshell/windows/HomeRow.qml
//
// A Home tile: accent icon, name and blurb, `status` and optional `history`
// on the right, a chevron; `current` lights it for the arrow keys.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string blurb: ""
    property string status: ""
    property color statusColor: Theme.subtext
    // one value a sample, 0..historyCeiling; empty draws no graph
    property var history: []
    property real historyCeiling: 1
    property bool first: false
    property bool current: false

    readonly property bool lit: current || mouse.containsMouse

    signal clicked()
    signal hovered()

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.row(48), texts.implicitHeight + Theme.spaceL * 2)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.lit ? Theme.hoverFill : "transparent"
    }

    // the hairline from the text's edge, hidden beside a lit row so the
    // fill isn't cut
    Rectangle {
        visible: !root.first && !root.lit
        x: texts.x
        width: parent.width - x - Theme.spaceL
        height: Theme.borderWidth
        color: Theme.stroke
    }

    Item {
        id: iconCell
        x: Theme.spaceXl
        width: Theme.iconCell
        height: parent.height

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: Theme.hasAccent ? Qt.lighter(Theme.accent, 1.4) : Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Math.round(Theme.fontIconSize * 1.35)
        }
    }

    Column {
        id: texts
        anchors.left: iconCell.right
        anchors.leftMargin: Theme.spaceXl
        anchors.right: right.left
        anchors.rightMargin: Theme.spaceXl
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.blurb
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
    }

    Row {
        id: right
        anchors.right: chevron.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceL

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            // never more than half the row, so the name keeps its room
            width: Math.min(implicitWidth, root.width / 2)
            elide: Text.ElideRight
            text: root.status
            color: root.statusColor
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        Spark {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.history.length > 0
            width: Theme.fit(90)
            height: Theme.row(20)
            ceiling: root.historyCeiling
            series: [{ values: root.history, color: Theme.accent, fill: true }]
        }
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXl
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅂"
        color: root.lit ? Theme.text : Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.clicked()
    }
}
