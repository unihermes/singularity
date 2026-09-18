// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Meter.qml
//
// A horizontal level bar: a track, and a fill from the left edge. Every
// meter in the shell is one of these -- gauges, the media progress bar, the
// volume/brightness toast, sliders -- so they share a height, stroke and
// corner, and a look that squares off corners squares them all.

import QtQuick
import "../services"

Rectangle {
    id: root

    // 0..1; clamped
    property real fraction: 0
    property color fillColor: Theme.meterFill
    // animate the fill as it changes; off for a slider under the pointer
    property bool animated: true

    implicitHeight: Theme.meterHeight
    // pill-shaped, but never rounder than the look's corners
    radius: Math.min(height / 2, Theme.radius)
    color: Theme.meterTrack
    border.width: Theme.borderWidth
    border.color: Theme.meterStroke

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // never narrower than it is tall, so a sliver still reads as a
        // rounded end rather than a hairline
        width: root.fraction <= 0 ? 0
            : Math.max(height, root.width * Math.min(1, root.fraction))
        radius: root.radius
        color: root.fillColor

        Behavior on width {
            enabled: root.animated
            NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease }
        }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
}
