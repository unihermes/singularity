// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BarMenuFlyout.qml
//
// Right-click menu for the bar's empty space: edit the bar in place, move
// it, open the Appearance or System windows, or restart the shell.

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: barMenu
    flyout: "barmenu"
    menuWidth: 210
    compactMenu: true

    FlyoutHeading { text: "BAR" }

    FlyoutRow {
        leadingIcon: "󰏫"
        label: "Edit bar"
        onActivated: barMenu.scope.editBar()
    }

    FlyoutRow {
        leadingIcon: Theme.barPosition === "bottom" ? "󰁝" : "󰁅"
        label: Theme.barPosition === "bottom" ? "Bar at the top" : "Bar at the bottom"
        onActivated: {
            barMenu.requestClose()
            Settings.set("barPosition", Theme.barPosition === "bottom" ? "top" : "bottom")
        }
    }

    FlyoutRow {
        leadingIcon: "󰒓"
        label: "Appearance settings"
        onActivated: {
            barMenu.requestClose()
            Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "appearance"])
        }
    }

    FlyoutRow {
        leadingIcon: "󰨇"
        label: "Task manager"
        onActivated: {
            barMenu.requestClose()
            Quickshell.execDetached(["qs", "ipc", "call", "system", "open", "processes"])
        }
    }

    FlyoutRow {
        leadingIcon: "󰑓"
        label: "Restart shell"
        onActivated: {
            barMenu.requestClose()
            Session.restartShell()
        }
    }
}
