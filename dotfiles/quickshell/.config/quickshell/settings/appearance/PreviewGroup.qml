// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/PreviewGroup.qml
//
// The shell's own bar chips and a flyout, scaled down over the wallpaper,
// so every change on the visual tabs shows as it's made. Built from the
// real components, which read Theme, so it can't drift from the shell.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

Item {
    default property alias chips: chipRow.data
    width: chipRow.width + (Theme.moduleGrouped ? Theme.channelWidth * 2 : 0)
    height: Theme.barHeight

    Item {
        visible: Theme.moduleGrouped
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.groupHeight
        Channel { radius: Theme.groupRadius }
    }
    Row {
        id: chipRow
        x: Theme.moduleGrouped ? Theme.channelWidth : 0
        spacing: Theme.moduleSpacing
    }
}
