// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PopoutsFlyout.qml
//
// The popouts' icon in the bar's open-windows strip, when it holds more
// than one: every dialog, sign-in popup and prompt in the strip's scope, a
// row each. A row brings that window up; its close action closes it.
// Which windows are popouts is windows.lua's call (Bar.isPopout).

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "popouts"
    menuWidth: 280

    required property var bar

    onOpenChanged: if (open) Hyprland.refreshToplevels()

    // the strip's own list, so the two never disagree
    readonly property var popouts: {
        var icons = bar ? bar.focusedWorkspaceIcons() : []
        var last = icons.length > 0 ? icons[icons.length - 1] : null
        return last && last.popouts ? last.popouts : []
    }
    // nothing left to pick from: close
    onPopoutsChanged: if (open && popouts.length === 0) requestClose()

    FlyoutHeading { text: "POPOUTS" }

    Repeater {
        model: root.popouts

        FlyoutRow {
            required property var modelData
            width: parent ? parent.width : 0
            leadingImage: modelData.source
            leadingIcon: modelData.source === "" ? modelData.glyph : ""
            label: modelData.toplevel ? modelData.toplevel.title || modelData.name : modelData.name
            note: modelData.name
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
