// Singularity - Quickshell
// ~/.config/quickshell/services/Clipboard.qml
//
// Clipboard history via cliphist. Exposed as a list of {id, preview, isImage}
// for the ClipboardFlyout. Actions: select() to paste an entry,
// remove() to delete it, and refresh() to re-read the history.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	// [ { id, preview, isImage } ], newest first
	property var history: []

	function refresh() {
		if (!listProc.running) listProc.running = true
	}

	function select(id) {
		selectProc.command = ["sh", "-c", "cliphist decode '" + id.replace(/'/g, "'\\''") + "' | wl-copy --type image/png 2>/dev/null || cliphist decode '" + id.replace(/'/g, "'\\''") + "' | wl-copy"]
		selectProc.running = true
	}

	function remove(id) {
		removeProc.command = ["cliphist", "delete", id]
		removeProc.running = true
	}

	Process {
		id: listProc
		command: ["cliphist", "list"]
		running: false
		stdout: StdioCollector {
			onStreamFinished: {
				var lines = text.trim().split("\n")
				var items = []
				for (var i = 0; i < lines.length; i++) {
					var parts = lines[i].split("\t")
					if (parts.length >= 2) {
						var id = parts[0]
						var preview = parts.slice(1).join("\t")
						var isImage = preview.startsWith("󰷏") || preview.includes("image")
						items.push({ id: id, preview: preview, isImage: isImage })
					}
				}
				root.history = items
			}
		}
	}

	Process {
		id: selectProc
		command: []
		running: false
	}

	Process {
		id: removeProc
		command: []
		running: false
		onExited: root.refresh()
	}
}
