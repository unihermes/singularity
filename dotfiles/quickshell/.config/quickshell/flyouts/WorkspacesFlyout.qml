// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspacesFlyout.qml
//
// The window-overview flyout: every window on every workspace. Needs
// bar.allWindows() for its list.

import "../services"
import Quickshell.Hyprland
import QtQuick

FlyoutPanel {
    flyout: "workspaces"
    menuWidth: 280

    required property var bar

    FlyoutHeading { text: "WINDOWS" }

    Repeater {
        model: bar.allWindows()

        FlyoutRow {
            required property var modelData
            label: "[" + modelData.ws + "] " + modelData.title
            onActivated: {
                scope.openFlyout = ""
                Hyprland.dispatch("hl.dsp.focus({window=\"address:0x" + modelData.address + "\"})")
            }
        }
    }

    FlyoutRow {
        label: "No windows open"
        enabled: false
        visible: bar.allWindows().length === 0
    }
}
