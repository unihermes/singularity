// Singularity - Quickshell
// ~/.config/quickshell/flyouts/TileGrid.qml
//
// Equal tiles across a flyout's column: `columns` of them a line, each
// FlyoutTile sizing itself with `width: parent.cell`.

import QtQuick
import "../services"

Grid {
    id: root
    columns: 2
    spacing: Theme.spaceS
    width: parent ? parent.width : 0
    readonly property real cell: (width - spacing * (columns - 1)) / columns
}
