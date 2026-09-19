// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WindowMenuFlyout.qml
//
// Right-click menu for an icon in the bar's open-windows strip: the window
// actions that otherwise live on keybinds (float, fullscreen, pin, move,
// close), aimed at that exact window by address rather than whatever
// happens to be focused. `address` is set from outside by BarModules.qml;
// "Move to workspace" drills down in place, like the tray menu.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

FlyoutPanel {
    id: winMenu
    flyout: "windowmenu"
    menuWidth: 240

    // Hyprland address without the 0x, as the toplevels report it
    property string address: ""
    property bool movePage: false
    onOpenChanged: {
        if (open) Hyprland.refreshToplevels()
        else movePage = false
    }

    readonly property var toplevel: {
        var tls = Hyprland.toplevels.values
        for (var i = 0; i < tls.length; i++)
            if (tls[i].address === address) return tls[i]
        return null
    }
    readonly property var ipc: toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : ({})
    readonly property string target: "address:0x" + address
    readonly property int wsId: ipc.workspace ? ipc.workspace.id : -1

    // the menu outlives nothing: once its window is gone, close
    onToplevelChanged: if (open && !toplevel) requestClose()

    function dispatch(call) {
        Hyprland.dispatch(call)
        Hyprland.refreshToplevels()
        requestClose()
    }
    function win(fn, extra) {
        dispatch("hl.dsp.window." + fn + "({window=\"" + target + "\"" + (extra ? ", " + extra : "") + "})")
    }

    FlyoutHeading {
        text: (winMenu.ipc.class || winMenu.ipc.title || "WINDOW").toUpperCase()
    }

    // ---- main page ----
    FlyoutRow {
        visible: !winMenu.movePage
        label: "󰖯  Focus"
        onActivated: {
            Hyprland.dispatch("hl.dsp.focus({window=\"" + winMenu.target + "\"})")
            winMenu.win("bring_to_top")
        }
    }
    FlyoutRow {
        visible: !winMenu.movePage
        label: winMenu.ipc.floating ? "󰕰  Tile" : "󰖲  Float"
        onActivated: winMenu.win("float", "action=\"toggle\"")
    }
    FlyoutRow {
        visible: !winMenu.movePage
        label: "󰊓  Fullscreen"
        highlighted: (winMenu.ipc.fullscreen || 0) > 0
        onActivated: winMenu.win("fullscreen")
    }
    FlyoutRow {
        visible: !winMenu.movePage
        label: "󰐃  Pin to all workspaces"
        highlighted: !!winMenu.ipc.pinned
        // Hyprland only pins floating windows
        enabled: !!winMenu.ipc.floating
        onActivated: winMenu.win("pin")
    }
    FlyoutRow {
        visible: !winMenu.movePage
        label: "󰍹  Move to workspace"
        trailing: "󰅂"
        onActivated: winMenu.movePage = true
    }
    FlyoutDivider { visible: !winMenu.movePage }
    FlyoutRow {
        visible: !winMenu.movePage
        label: "󰅖  Close"
        // a second, harsher action for a window that ignores the polite one
        actionIcon: "󰚌"
        actionHint: "Force kill"
        onActivated: winMenu.win("close")
        onAction: winMenu.win("kill")
    }

    // ---- move page ----
    FlyoutRow {
        visible: winMenu.movePage
        label: "󰅁  Back"
        onActivated: winMenu.movePage = false
    }
    Repeater {
        model: winMenu.movePage ? Settings.workspaceCount : 0

        FlyoutRow {
            required property int index
            readonly property int ws: index + 1
            label: "Workspace " + ws
            highlighted: ws === winMenu.wsId
            enabled: ws !== winMenu.wsId
            onActivated: winMenu.win("move", "workspace=" + ws)
        }
    }
}
