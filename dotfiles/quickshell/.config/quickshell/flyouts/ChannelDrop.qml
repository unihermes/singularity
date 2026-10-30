// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ChannelDrop.qml
//
// Lays over a channel's row and takes an app dragged there (AppDrag),
// outlined in the accent while one hovers. Dropped, it says which streams
// came; the row's owner moves them (Audio.moveApp).

import QtQuick
import "../services"

DropArea {
    id: root

    signal appDropped(var nodes)

    keys: ["singularity-app"]
    onDropped: drop => {
        if (drop.source && drop.source.nodes) root.appDropped(drop.source.nodes)
        drop.accept()
    }

    Rectangle {
        anchors.fill: parent
        visible: root.containsDrag
        radius: Theme.radiusInner
        color: "transparent"
        border.width: Theme.borderWidth * 2
        border.color: Theme.accent
    }
}
