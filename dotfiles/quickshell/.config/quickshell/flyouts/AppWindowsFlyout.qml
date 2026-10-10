// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AppWindowsFlyout.qml
//
// An app's icon in the bar's open-windows strip, when the app has more
// than one window: every one of them, its dialogs and popups after its own
// windows, a row each, as the Windows taskbar lists a grouped app's. A row
// brings that window up; its close action closes it. Which windows are
// popouts is windows.lua's call (Bar.isPopout).

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "appwindows"
    menuWidth: 300

    required property var bar

    onOpenChanged: if (open) Hyprland.refreshToplevels()

    // the strip's own entry for the app, so the two never disagree
    readonly property var app: {
        var icons = bar ? bar.focusedWorkspaceIcons() : []
        var key = bar ? bar.appWindowsKey : ""
        for (var i = 0; i < icons.length; i++)
            if (icons[i].key === key) return icons[i]
        return null
    }
    readonly property var windows: app ? app.windows : []
    // down to one window or none: nothing left to pick from
    onWindowsChanged: if (open && windows.length < 2) requestClose()

    FlyoutHeading { text: root.app ? root.app.name.toUpperCase() : "" }

    Repeater {
        model: root.windows

        FlyoutRow {
            required property var modelData
            width: parent ? parent.width : 0
            leadingImage: modelData.source
            leadingIcon: modelData.source === "" ? modelData.glyph : ""
            label: modelData.toplevel ? modelData.toplevel.title || modelData.name : modelData.name
            note: modelData.popout ? "Popout" : ""
            highlighted: !!Hyprland.activeToplevel && Hyprland.activeToplevel.address === modelData.address
            actionIcon: "󰅖"
            actionHint: "Close"
            onActivated: {
                var addr = "address:0x" + modelData.address
                root.requestClose()
                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                Hyprland.dispatch("hl.dsp.window.alter_zorder({mode=\"top\", window=\"" + addr + "\"})")
            }
            onAction: Hyprland.dispatch("hl.dsp.window.close({window=\"address:0x" + modelData.address + "\"})")
        }
    }
}
