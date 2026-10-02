// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Channel.qml
//
// The channel frame (Theme.frameStyle "channel"): an outer line, a dark
// groove, an inner line, then the ground. Drawn as nested fills, outside in,
// so every band follows the corners. `lit` turns the groove the accent: an
// open bar module, a switch that's on, a focused field.

import QtQuick
import "../services"

Item {
    id: root

    property real radius: Theme.radius
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property color fill: Theme.surface
    property color outer: Theme.channelOuter
    property bool lit: false
    property color groove: lit ? Theme.accent : Theme.channelGroove
    property int grooveWidth: Theme.channelGrooveWidth
    // false leaves the inner line out: outer line and groove only, for
    // small controls where three bands would crowd the fill
    property bool innerLine: true

    readonly property int bw: Theme.borderWidth
    // from the edge in to the ground
    readonly property int depth: bw + grooveWidth + (innerLine ? bw : 0)

    anchors.fill: parent

    component Band: Rectangle {
        property real inset: 0
        anchors.fill: parent
        anchors.margins: inset
        topLeftRadius: Math.max(0, root.topLeftRadius - inset)
        topRightRadius: Math.max(0, root.topRightRadius - inset)
        bottomLeftRadius: Math.max(0, root.bottomLeftRadius - inset)
        bottomRightRadius: Math.max(0, root.bottomRightRadius - inset)
    }

    Band { color: root.outer }
    Band {
        inset: root.bw
        color: root.groove
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    Band { visible: root.innerLine; inset: root.bw + root.grooveWidth; color: Theme.channelInner }
    Band { inset: root.depth; color: root.fill }
}
