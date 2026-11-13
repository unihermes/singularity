// One reading of a link (IP address, Gateway, Speed) as a small framed
// chip: its name spaced out over the value. A `copyable` one fills on
// hover, copies on a click and reads Copied for a moment. Rings when
// Settings' search picked its label.

import Quickshell
import QtQuick
import "../services"

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property bool copyable: true
    readonly property bool isSettingsField: true

    readonly property var hostPage: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }
    readonly property bool searched: !!hostPage && label !== "" && hostPage.highlight === label
    readonly property bool hot: copyable && mouse.containsMouse

    visible: value !== ""
    width: Math.max(name.implicitWidth, val.implicitWidth) + Theme.spaceL * 2
    height: col.implicitHeight + Theme.spaceS * 2
    radius: Theme.radiusInner
    color: searched ? Theme.selectedFill : Theme.controlFill(hot ? Theme.hoverFillSoft : "transparent")
    border.width: Theme.controlBorder(edge)
    border.color: Theme.controlStroke(edge)
    readonly property color edge: searched ? Theme.accent : hot ? Theme.strokeHover : Theme.stroke

    Column {
        id: col
        x: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            id: name
            text: root.label.toUpperCase()
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontEyebrow
            font.letterSpacing: 1
        }
        Text {
            id: val
            text: copied.running ? "Copied" : root.value
            color: copied.running ? Theme.good : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.copyable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["wl-copy", "--", root.value])
            copied.restart()
        }
    }

    Timer { id: copied; interval: 1200 }
}
