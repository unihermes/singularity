// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageKeybinds.qml
//
// The Keybinds editor (KeybindsBody.qml). It keeps its own list scrolling,
// and reports through this page's toast.

import QtQuick
import "../services"

SettingsPage {
    id: page

    sectioned: true

    title: "Keybinds"
    description: "Every shortcut in hyprland.lua, and presets worth adding."
    scrolls: false

    function focusSearch() { body.focusSearch() }

    KeybindsBody {
        id: body
        page: page
        // the scrolling pages' width: their scroll bar's gutter is left free
        width: parent.width - Theme.scrollGutter
        // search and status line, a spacing after each -- the rest is the
        // list (which gives up room to the lookup line and the ticked bar)
        bodyHeight: page.bodyHeight - Theme.rowHeightTall - Theme.spaceM - Theme.headingHeight - Theme.spaceM * 2
    }
}
