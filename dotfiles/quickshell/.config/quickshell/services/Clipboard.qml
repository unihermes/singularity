// Singularity - Quickshell
// ~/.config/quickshell/services/Clipboard.qml
//
// Clipboard history from cliphist, for the launcher (Launcher.qml). The history is
// captured by `wl-paste --watch cliphist store`, started from hyprland.lua.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ id, preview, isImage }], newest first
    property var history: []

    function refresh() {
        if (!listProc.running) listProc.running = true
    }

    // cliphist decode takes the whole list line on stdin; wl-copy picks the
    // mime type from the content, so images stay images and text stays text.
    function select(entry) {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist decode | wl-copy",
            "sh", entry.id, entry.preview])
    }

    function remove(entry) {
        history = history.filter(e => e.id !== entry.id)
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist delete",
            "sh", entry.id, entry.preview])
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var items = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t")
                    if (tab < 0) continue
                    var preview = lines[i].slice(tab + 1)
                    items.push({
                        id: lines[i].slice(0, tab),
                        preview: preview,
                        isImage: preview.startsWith("[[ binary data")
                    })
                }
                root.history = items
            }
        }
    }
}
