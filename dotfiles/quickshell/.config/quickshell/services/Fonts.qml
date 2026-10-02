// Singularity - Quickshell
// ~/.config/quickshell/services/Fonts.qml
//
// Which of Looks.fonts the shell can actually draw. Qt reads the system's
// fonts once, when the process starts, and never notices one installed after
// -- asking it for a family it doesn't know silently draws some fallback
// face instead. So `available` is what Qt itself knows, not what fc-list
// says is on disk; a font installed since startup shows up in `pending`
// until the shell is restarted (restartShell()).
//
// A look or saved setting naming a font that isn't available (or isn't on
// the list at all -- only monospace faces are) resolves to the first one.
// packages/pacman.txt installs the whole list.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks

Singleton {
    id: root

    // Fixed for the life of the process, as above. A family two foundries
    // ship comes back as "Name [Foundry]"; Qt still resolves the bare name.
    readonly property var loaded: Qt.fontFamilies().map(f => f.replace(/ \[[^\]]*\]$/, ""))
    readonly property var available: Looks.fonts.filter(f => loaded.indexOf(f) !== -1)

    // on disk per fontconfig; refreshed when the Appearance page opens
    property var installed: []
    readonly property var pending: Looks.fonts.filter(f => installed.indexOf(f) !== -1 && loaded.indexOf(f) === -1)

    function resolve(family) {
        return available.indexOf(family) !== -1 ? family : Looks.fonts[0]
    }

    function refresh() { if (!scan.running) scan.running = true }

    // A fresh process, since that's the only way Qt rereads fonts. Detached,
    // so it outlives this one; the log goes where hyprland.lua sends it.
    function restartShell() {
        Quickshell.execDetached(["sh", "-c",
            "qs kill; sleep 0.5; setsid quickshell > \"$HOME/.cache/quickshell.log\" 2>&1 < /dev/null &"])
    }

    Process {
        id: scan
        running: true
        command: ["fc-list", ":", "family"]
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {}
                text.split("\n").forEach(l => l.split(",").forEach(f => seen[f.trim()] = true))
                root.installed = Object.keys(seen)
            }
        }
    }
}
