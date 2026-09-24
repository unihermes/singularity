// Singularity - Quickshell
// ~/.config/quickshell/services/DesktopThemes.qml
//
// The cursor and icon themes installed, for the Appearance page's pickers.
// Both live in the same XDG icon directories: a cursor theme is one with a
// cursors/ folder, an icon theme one whose index.theme lists Directories.
// Bibata's index.theme only inherits, so it counts as a cursor theme alone,
// while Adwaita is both. `default` (an alias for another theme) and
// `hicolor` (the fallback every icon theme inherits) are never offered.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var cursors: []
    property var icons: []
    // theme directory -> its index.theme Name, for icon themes
    property var names: ({})

    // A cursor theme's directory name with its dashes spaced out, which is
    // how the Bibata variants read; an icon theme's own Name.
    function label(t) { return names[t] || t.replace(/-/g, " ") }

    function refresh() { if (!scan.running) scan.running = true }

    Process {
        id: scan
        running: true
        command: ["sh", "-c",
            "for d in /usr/share/icons/* \"$HOME/.local/share/icons\"/* \"$HOME/.icons\"/*; do " +
            "  n=${d##*/}; [ \"$n\" = default ] || [ \"$n\" = hicolor ] && continue; " +
            "  [ -d \"$d/cursors\" ] && printf 'cursor\\t%s\\n' \"$n\"; " +
            "  [ -f \"$d/index.theme\" ] && grep -q '^Directories=' \"$d/index.theme\" && " +
            "    printf 'icon\\t%s\\t%s\\n' \"$n\" \"$(sed -n 's/^Name=//p' \"$d/index.theme\" | head -n 1)\"; " +
            "done; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = [], i = [], n = {}
                text.split("\n").forEach(l => {
                    var f = l.split("\t")
                    if (f[0] === "cursor" && c.indexOf(f[1]) === -1) c.push(f[1])
                    if (f[0] === "icon" && i.indexOf(f[1]) === -1) {
                        i.push(f[1])
                        if (f[2]) n[f[1]] = f[2]
                    }
                })
                root.names = n
                root.cursors = c.sort()
                root.icons = i.sort()
            }
        }
    }
}
