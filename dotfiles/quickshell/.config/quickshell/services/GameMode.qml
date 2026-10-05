// Singularity - Quickshell
// ~/.config/quickshell/services/GameMode.qml
//
// Game Mode: Hyprland without animations, blur, shadows, gaps or rounding.
// The switch is a state file, game-mode ("on" or "off"), that the Hyprland
// config reads on load and lays over everything else it sets (overrides.lua), so turning it off
// and reloading restores the desktop as it was. Kept across restarts, like
// the rest of the state directory.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string path: Settings.stateDir + "/game-mode"
    property bool active: false

    function toggle() { set(!active) }

    function set(on) {
        // optimistic, so the switch moves on the click; the file's change
        // notification settles it
        active = on
        AtomicFileWrite.write({
            path: root.path,
            transform: () => (on ? "on" : "off") + "\n",
            after: "hyprctl reload config-only >/dev/null",
        })
    }

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.active = text().trim() === "on"
        onLoadFailed: root.active = false
    }
}
