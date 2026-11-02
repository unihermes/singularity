// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherEmpty.qml
//
// What a launcher layout says when it has no rows (No matches, Searching…),
// lined up with a row's name.

import QtQuick
import "../services"

Text {
    required property var launcher

    x: Theme.spaceL + Theme.iconCell + Theme.spaceM
    width: parent ? parent.width - x : 0
    height: launcher.rowHeight
    verticalAlignment: Text.AlignVCenter
    text: launcher.emptyText
    color: Theme.textDisabled
    font.family: Theme.fontText
    font.weight: Theme.weightBody
    font.pixelSize: Theme.fontBody
}
