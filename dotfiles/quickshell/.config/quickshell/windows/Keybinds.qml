// Singularity - Quickshell
// ~/.config/quickshell/windows/Keybinds.qml
//
// Keybinds as its own window. The editor is KeybindsBody.qml, which the
// Settings window's Keybinds page hosts as well.

import QtQuick
import "../services"

CentredWindow {
    id: root

    heading: "KEYBINDS"
    eyebrow: "HYPRLAND SHORTCUTS"
    subtitle: "Every binding in hyprland.lua, and the presets they come from"
    contentWidth: Theme.fs(720)

    KeybindsBody {
        active: root.visible
        // toolbar, spacing, status line, spacing -- the rest is the list
        bodyHeight: root.bodyHeight - Theme.rowHeightTall - Theme.headingHeight - Theme.spaceM * 2
        onCloseRequested: root.close()
    }
}
