// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ScrollBar.qml
//
// The thin position marker beside a scrolling list -- not draggable, just a
// thumb sized and placed from the Flickable it watches. Anchor it to the
// Flickable's right edge; it hides itself when there's nothing to scroll.

import QtQuick
import "../services"

Rectangle {
    id: root

    required property Flickable flickable

    readonly property real overflow: flickable.contentHeight - flickable.height

    width: 3
    radius: Math.min(width / 2, Theme.radius)
    color: Theme.muted
    visible: overflow > 0
    height: Math.max(20, flickable.height * flickable.height / Math.max(1, flickable.contentHeight))
    y: flickable.y + (flickable.height - height) * (flickable.contentY / Math.max(1, overflow))
}
