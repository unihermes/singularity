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
    height: Math.min(flickable.height, Math.max(20, flickable.height * flickable.visibleArea.heightRatio))
    y: flickable.y + (flickable.height - height) * Math.max(0, Math.min(1,
        flickable.visibleArea.yPosition / Math.max(0.00001, 1 - flickable.visibleArea.heightRatio)))
}
