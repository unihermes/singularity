// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BarMenuFlyout.qml
//
// Right-click menu for the bar's empty space: edit the bar in place, or
// restart the shell.

import QtQuick
import "../services"

FlyoutPanel {
    id: barMenu
    flyout: "barmenu"
    menuWidth: 220

    FlyoutHeading { text: "BAR" }

    FlyoutRow {
        leadingIcon: "󰏫"
        label: "Edit bar"
        onActivated: barMenu.scope.editBar()
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
