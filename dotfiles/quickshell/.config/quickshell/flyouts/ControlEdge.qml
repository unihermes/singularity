// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlEdge.qml
//
// The frame style carried inside panels: what a control's edge gets on top
// of its own stroke. The control (a Rectangle) keeps drawing its stroke,
// through Theme.controlBorder()/controlStroke(), and puts one of these over
// itself for the rest:
//   double   an inner stroke, inset, as on bar modules
//   bevel    a raised chisel on buttons, a sunken well on fields
//   groove   the same pair the other way round
//   corners  marks at the four corners, in the control's stroke colour
//   channel  a groove inside the stroke: dark at rest, the accent and
//            twice as wide when the control is lit (focused, selected)
// Single, accent and none are the stroke alone (or none), so this draws
// nothing for them.
//
// `sunken` marks a field (an input, a dropdown's box, a switch's track) or
// a pressed button (a lit chip).

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

    Bevel {
        visible: Theme.frameChiselled
        anchors.fill: parent
        raised: Theme.frameGroove ? root.sunken : !root.sunken
        light: Theme.bevelLight
        dark: Theme.bevelDark
        thickness: Theme.borderWidth
    }

    FrameCorners {
        visible: Theme.frameCorners
        anchors.fill: parent
        length: Math.min(Theme.sp(6), root.height / 3)
        color: Qt.colorEqual(root.stroke, "transparent") ? Theme.stroke : root.stroke
    }
}
