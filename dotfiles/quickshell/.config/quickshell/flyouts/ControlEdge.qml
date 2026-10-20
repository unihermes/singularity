// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlEdge.qml
//
// The frame style inside a control's own stroke: double adds an inset inner
// stroke; channel a groove (accent and wider when lit); single and none
// nothing. `sunken` marks a field or a pressed button.

import QtQuick
import "../services"

Item {
    id: root

    property color stroke: Theme.stroke
    property bool sunken: false
    // the host's corner radius, which the inner stroke follows
    property real radius: 0
    // channel: light the groove
    property bool lit: Qt.colorEqual(stroke, Theme.strokeFocus) && !Qt.colorEqual(stroke, Theme.stroke)

    anchors.fill: parent

    Rectangle {
        visible: Theme.frameChannel
        anchors.fill: parent
        anchors.margins: Theme.borderWidth
        radius: Math.max(0, root.radius - Theme.borderWidth)
        color: "transparent"
        border.width: root.lit ? Theme.channelGrooveWidth : Theme.borderWidth
        border.color: root.lit ? Theme.accent : Theme.channelGroove
    }

    Rectangle {
        visible: Theme.frameDouble
        anchors.fill: parent
        anchors.margins: 2
        radius: Math.max(0, root.radius - 2)
        color: "transparent"
        border.width: Theme.borderWidth
        // fainter at rest, so the pair reads as one edge; lit with the state
        border.color: Qt.colorEqual(root.stroke, Theme.stroke)
            ? Qt.rgba(Theme.frameStroke.r, Theme.frameStroke.g, Theme.frameStroke.b, 0.45) : Theme.frameStroke
    }
}
