// Singularity - Quickshell
// ~/.config/quickshell/bar/BarGround.qml
//
// The ground under a floating bar or one of the islands, edged the way
// Theme.frameStyle edges panels: the outer stroke (in the accent for
// accent), the raised or sunken Bevel for bevel and groove, the corner
// marks for corners, nothing for none. Only the outer level: a double
// frame's inner stroke would run into the chips, which carry their own.
// The ground fades with Bar Opacity by its colour's alpha, so the edge
// stays solid.

import QtQuick
import "../services"
import "../flyouts"

Rectangle {
    radius: Theme.radius
    color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
    border.width: Theme.frameStroked ? Theme.borderWidth : 0
    border.color: Theme.frameAccent ? Theme.accent : Theme.stroke

    Bevel {
        visible: Theme.frameChiselled
        anchors.fill: parent
        raised: !Theme.frameGroove
        light: Theme.bevelLight
        dark: Theme.bevelDark
        thickness: Theme.borderWidth
    }

    FrameCorners {
        visible: Theme.frameCorners
        anchors.fill: parent
        length: Theme.sp(8)
        color: Theme.strokeFocus
    }
}
