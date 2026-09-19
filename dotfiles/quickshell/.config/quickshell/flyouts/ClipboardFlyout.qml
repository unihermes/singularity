// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ClipboardFlyout.qml
//
// Clipboard history picker. On open, refresh the list from cliphist.
// Rows are newest-first; clicking one pastes it and closes the flyout.

import QtQuick
import "../services"

FlyoutPanel {
	id: clipboardFlyout
	flyout: "clipboard"
	menuWidth: 280

	onOpenChanged: if (open) Clipboard.refresh()

	FlyoutHeading {
		text: "CLIPBOARD"
	}

	ListView {
		width: parent.width
		height: Math.min(contentHeight, 300)
		clip: true
		spacing: Theme.spaceXs

		model: Clipboard.history

		delegate: FlyoutRow {
			required property var modelData
			width: parent.width
			label: {
				if (modelData.isImage) return "[image]"
				var p = modelData.preview
				return p.length > 50 ? p.substring(0, 47) + "..." : p
			}
			enabled: true
			onActivated: {
				Clipboard.select(modelData.id)
				clipboardFlyout.requestClose()
			}
		}
	}

	FlyoutDivider {}

	FlyoutRow {
		label: "Clear all"
		trailing: "󰆴"
		onActivated: Clipboard.remove("")
	}
}
