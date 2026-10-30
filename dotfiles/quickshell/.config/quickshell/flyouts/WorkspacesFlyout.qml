// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspacesFlyout.qml
//
// Every window on every workspace in one frame, under a heading per
// workspace with its count: the app's icon and name, the title quieter
// after, the focused one ticked. A click focuses, close on hover, and a
// window dragged onto another workspace's heading or windows, or onto an
// empty one's number, moves there. Then the workspace grid and Settings.

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

    // allWindows() is sorted by workspace, so a group is a run of one id;
    // the numbered ones first, then the specials. `target` is what a move
    // takes: the number, or "special:name"
    readonly property var groups: {
        var out = []
        var wins = bar.allWindows()
        for (var i = 0; i < wins.length; i++) {
            if (out.length === 0 || out[out.length - 1].ws !== wins[i].ws) {
                var ws = Hyprland.workspaces.values.find(w => w.id === wins[i].ws)
                out.push({ ws: wins[i].ws, target: wins[i].ws < 0 && ws ? String(ws.name) : wins[i].ws, windows: [] })
            }
            out[out.length - 1].windows.push(wins[i])
        }
        return out.filter(g => g.ws > 0).concat(out.filter(g => g.ws < 0))
    }

    // the numbered workspaces with nothing on them, a drop target each
    readonly property var empty: {
        var out = []
        for (var id = 1; id <= Settings.workspaceCount; id++)
            if (!groups.some(g => g.ws === id)) out.push(id)
        return out
    }

    // where a dragged window would land, null for nowhere
    property var dropTarget: null

    // the target under a point in window coordinates
    function targetAt(p) {
        for (var i = 0; i < groupList.count; i++) {
            var g = groupList.itemAt(i)
            var q = g.mapFromItem(null, p.x, p.y)
            if (g.contains(q)) return g.modelData.target
        }
        for (var j = 0; j < emptyList.count; j++) {
            var c = emptyList.itemAt(j)
            var r = c.mapFromItem(null, p.x, p.y)
            if (c.contains(r)) return c.modelData
        }
        return null
    }

    function moveWindow(address, target) {
        Hyprland.dispatch("hl.dsp.window.move({window=\"address:0x" + address + "\", workspace="
            + (typeof target === "number" ? target : "\"" + target + "\", follow=false") + "})")
        Hyprland.refreshToplevels()
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

    // a heading per workspace, then its windows: the app and, quieter, the
    // title; a click focuses, close on hover, drag to move
    Repeater {
        id: groupList
        model: panel.groups

        Column {
            id: group
            required property var modelData
            readonly property int n: modelData.windows.length
            readonly property bool isDropTarget: panel.dropTarget !== null && panel.dropTarget === modelData.target
            width: parent ? parent.width : 0

            // lit while a window is dragged over it
            Rectangle {
                parent: group
                width: group.width + Theme.spaceS * 2
                height: group.height
                x: -Theme.spaceS
                z: -1
                visible: group.isDropTarget
                radius: Theme.radiusInner
                color: Theme.selectedFill
                border.width: Theme.borderWidth
                border.color: Theme.accent
            }

            FlyoutHeading {
                width: parent.width
                text: group.modelData.ws < 0 ? panel.wsName(group.modelData.ws).toUpperCase()
                    : "WORKSPACE " + panel.wsName(group.modelData.ws).toUpperCase()
                hints: [group.n + (group.n === 1 ? " window" : " windows")]
            }

            Repeater {
                model: group.modelData.windows

                FlyoutRow {
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
                    draggable: true
                    opacity: dragging ? 0.5 : 1
                    onDragMoved: at => {
                        var t = panel.targetAt(at)
                        panel.dropTarget = t === group.modelData.target ? null : t
                    }
                    onDropped: at => {
                        var t = at.x < 0 ? null : panel.targetAt(at)
                        panel.dropTarget = null
                        if (t !== null && t !== group.modelData.target) panel.moveWindow(modelData.address, t)
                    }
                    onAction: Hyprland.dispatch("hl.dsp.window.close({window=\"address:0x" + modelData.address + "\"})")
                    onActivated: {
                        var addr = "address:0x" + modelData.address
                        panel.requestClose()
                        // bring to top as well, as the bar's strip does, so
                        // a floating window buried under others surfaces
                        Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                        Hyprland.dispatch("hl.dsp.window.bring_to_top()")
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

    // the empty numbers: a click goes there, a window dropped on one moves
    Row {
        visible: panel.empty.length > 0
        spacing: Theme.spaceS

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "EMPTY"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
            font.letterSpacing: 1
        }

        Repeater {
            id: emptyList
            model: panel.empty

            FlyoutChip {
                required property int modelData
                text: panel.wsName(modelData)
                selected: panel.dropTarget === modelData
                onClicked: {
                    panel.requestClose()
                    Hyprland.dispatch("hl.dsp.focus({workspace=" + modelData + "})")
                }
            }
        }
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [
            { icon: "󰕰", text: "All workspaces", act: "grid" },
            { icon: "󰒓", text: "Settings",       act: "settings" },
        ]
        onPicked: act => {
            if (act === "settings") {
                panel.scope.openSettings("appearance")
                return
            }
            panel.requestClose()
            panel.shellRoot.workspaceOverlayToggled()
        }
    }
}
