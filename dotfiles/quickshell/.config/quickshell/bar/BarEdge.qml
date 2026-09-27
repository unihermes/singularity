// Singularity - Quickshell
// ~/.config/quickshell/bar/BarEdge.qml
//
// A full-width bar's inner edge, the line that makes it read as a surface
// rather than a strip of background, drawn to Theme.frameStyle: the stroke
// (in the accent for accent), a second line inside it for double, a light
// and a dark line for bevel (the dark one outside, as on a raised edge) and
// the other way round for groove, and nothing for corners or none.
// `atTop` is true when the edge is the bar's top, for a bar at the bottom.

import QtQuick
import "../services"

Item {
    id: root

    property bool atTop: false

    readonly property int bw: Theme.borderWidth
    visible: !Theme.frameCorners && !Theme.frameNone
    height: Theme.frameDouble ? Theme.frameInset + bw : Theme.frameChiselled ? bw * 2 : bw

    // the outermost line, on the edge itself
    Rectangle {
        y: root.atTop ? 0 : root.height - height
        width: parent.width
        height: root.bw
        color: Theme.frameAccent ? Theme.accent
            : Theme.frameChiselled ? (Theme.frameGroove ? Theme.bevelLight : Theme.bevelDark)
            : Theme.stroke
    }

    // the line inside it, for double, bevel and groove
    Rectangle {
        visible: Theme.frameDouble || Theme.frameChiselled
        y: root.atTop ? root.height - height : 0
        width: parent.width
        height: root.bw
        color: Theme.frameDouble ? Theme.frameStroke
            : Theme.frameGroove ? Theme.bevelDark : Theme.bevelLight
    }
}
