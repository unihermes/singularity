// Singularity - Quickshell
// ~/.config/quickshell/desktop/DesktopMenu.qml
//
// Right-click menu for the bare desktop, at the pointer: edit the widgets
// in place, a new sticky note where the click was, the next wallpaper, or
// the Desktop settings.

import QtQuick
import "../services"
import "../flyouts"

FlyoutPanel {
    id: menu
    flyout: "desktopmenu"
    menuWidth: 220

    // this screen's DesktopWidgets, which keeps where the click was
    required property var layer
    topOffset: Theme.barPosition === "bottom" ? height - layer.menuY : layer.menuY

    FlyoutHeading { text: "DESKTOP" }

    FlyoutRow {
        leadingIcon: "󰏫"
        label: "Edit widgets"
        onActivated: menu.scope.editWidgets()
    }

    FlyoutRow {
        leadingIcon: "󰐕"
        label: "New sticky note"
        onActivated: {
            menu.requestClose()
            menu.layer.newNoteAt(menu.anchorX, menu.layer.menuY)
        }
    }

    FlyoutRow {
        leadingIcon: "󰒭"
        label: "Next wallpaper"
        enabled: Wallpaper.images.length > 1
        onActivated: {
            menu.requestClose()
            Wallpaper.step(1)
        }
    }

    FlyoutRow {
        leadingIcon: "󰒓"
        label: "Desktop settings"
        onActivated: menu.scope.openSettings("appearance/colour")
    }
}
