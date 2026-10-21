// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspacesFlyout.qml
//
// Every window on every workspace, under a heading per workspace with its
// count: the app's icon and name, the title quieter after, the focused one
// ticked. A click focuses, close on hover; then the workspace grid.

import "../services"
import Quickshell.Hyprland
import QtQuick

FlyoutPanel {
    id: panel
    flyout: "workspaces"
    menuWidth: Theme.flyoutMenuWidth

    required property var bar
    // for the workspace grid (SUPER+W)
    required property var shellRoot

    // allWindows() is sorted by workspace, so a group is a run of one id
    readonly property var groups: {
        var out = []
        var wins = bar.allWindows()
        for (var i = 0; i < wins.length; i++) {
            if (out.length === 0 || out[out.length - 1].ws !== wins[i].ws)
                out.push({ ws: wins[i].ws, windows: [] })
            out[out.length - 1].windows.push(wins[i])
        }
        return out
    }

    function wsName(id) {
        // special workspaces have negative ids and go by their name:
        // "special:scratchpad" reads Scratchpad
        if (id < 0) {
            var ws = Hyprland.workspaces.values.find(w => w.id === id)
            var name = ws ? String(ws.name).replace(/^special:/, "") : ""
            return name ? name.charAt(0).toUpperCase() + name.slice(1) : "Special"
        }
        if (Theme.workspaceStyle === "roman")
            return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][id - 1] || String(id)
        return String(id)
    }

    // an app's name for a window: its desktop entry's, else the class
    function appName(w) {
        var e = w.cls !== "" ? Apps.byClass(w.cls).entry : null
        return e && e.name ? e.name : (w.cls || "Window")
    }

    // a heading per workspace (a click there folds it), then its windows:
    // the app and, quieter, the title; a click focuses, close on hover
    Repeater {
        model: panel.groups

        Column {
            id: group
            required property var modelData
            readonly property bool current: Hyprland.focusedWorkspace !== null
                && Hyprland.focusedWorkspace.id === modelData.ws
            readonly property int n: modelData.windows.length
            width: parent ? parent.width : 0

            FlyoutHeading {
                width: parent.width
                text: "WORKSPACE " + panel.wsName(group.modelData.ws).toUpperCase()
                hints: [group.n + (group.n === 1 ? " window" : " windows")]
            }

            Repeater {
                model: group.modelData.windows

                FlyoutRow {
                    id: row
                    required property var modelData
                    readonly property string iconPath: Apps.iconForClass(modelData.cls)
                    width: parent.width
                    leadingImage: iconPath
                    leadingIcon: iconPath === "" ? Apps.glyphForWindow(modelData.cls, modelData.title) : ""
                    label: panel.appName(modelData)
                    note: modelData.title !== label ? modelData.title : ""
                    highlighted: Hyprland.activeToplevel !== null
                        && Hyprland.activeToplevel.address === modelData.address
                    actionIcon: "󰅖"
                    actionHint: "Close"
                    onAction: Hyprland.dispatch("hl.dsp.window.close({window=\"address:0x" + modelData.address + "\"})")
                    onActivated: {
                        var addr = "address:0x" + modelData.address
                        panel.requestClose()
                        // bring to top as well, as the bar's strip does, so
                        // a floating window buried under others surfaces
                        Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                        Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
                    }
                }
            }
        }
    }

    FlyoutRow {
        label: "No windows open"
        enabled: false
        visible: panel.groups.length === 0
    }

    FlyoutDivider {}

    FlyoutRow {
        leadingIcon: "󰕰"
        label: "All workspaces"
        trailing: "SUPER W"
        onActivated: {
            panel.requestClose()
            panel.shellRoot.workspaceOverlayToggled()
        }
    }
}
