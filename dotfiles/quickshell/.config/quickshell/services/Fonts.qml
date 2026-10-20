// Singularity - Quickshell
// ~/.config/quickshell/services/Fonts.qml
//
// Which of Looks.fonts Qt can draw: Qt reads fonts once at startup, so
// `available` is what it knows and newly installed ones are `pending` until
// a restart. Anything unavailable resolves to the first.

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
