// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassLinkTile.qml
//
// A Glass card holding one GlassLink: a round switch with its name and
// state. The disc toggles, the words open the details.

import QtQuick
import "../services"

Item {
    id: tile
    property string icon: ""
    property string title: ""
    property string caption: ""
    property bool lit: false
    property bool usable: true
    signal toggled()
    signal opened()

    height: Theme.fs(60)

    GlassCard { anchors.fill: parent }
    GlassLink {
        x: Theme.spaceL
        width: parent.width - Theme.spaceL * 2
        anchors.verticalCenter: parent.verticalCenter
        icon: tile.icon
        title: tile.title
        caption: tile.caption
        lit: tile.lit
        usable: tile.usable
        onToggled: tile.toggled()
        onOpened: tile.opened()
    }
}
