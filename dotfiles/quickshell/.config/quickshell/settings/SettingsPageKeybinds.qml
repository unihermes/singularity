// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageKeybinds.qml
//
// The Keybinds editor (KeybindsBody.qml). It keeps its own list scrolling,
// and reports through this page's toast.

import QtQuick
import "../services"

SettingsPage {
    id: page

    title: "Keybinds"
    description: "Every shortcut in hyprland.lua, and presets worth adding. Saving checks the Lua, backs the file up and reloads Hyprland."
    scrolls: false

    function focusSearch() { body.focusSearch() }

    KeybindsBody {
        id: body
        page: page
        // the scrolling pages' width: their scroll bar's gutter is left free
        width: parent.width - Theme.scrollGutter
        // search, toolbar and status line, a spacing after each -- the rest
        // is the list
        bodyHeight: page.bodyHeight - searchHeight - Theme.rowHeightTall - Theme.headingHeight - Theme.spaceM * 3
    }
}
