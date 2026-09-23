// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowPanel.qml
//
// One framed panel inside a standalone window: the sections list or the
// open page in Settings and System, the editor in Keybinds. A faint
// surface tint over the window's ground, and the usual stroke.

import QtQuick
import "../services"

Rectangle {
    radius: Theme.radius
    color: Theme.panelTint
    border.width: Theme.borderWidth
    border.color: Theme.stroke
}
