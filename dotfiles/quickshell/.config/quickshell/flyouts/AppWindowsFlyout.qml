// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AppWindowsFlyout.qml
//
// An app's windows from the strip, as a menu: a row a window with its
// workspace, popouts indented under their owner and a blocked owner dimmed
// with a lock, then New window, Bring all here and Close all. A row raises
// its window, close on hover, and its ⌄ opens the window's actions under it
// as one toolbar (mode, the workspaces to move to, close, kill; the hovered
// one named in the row). An app with one window gets that window's actions
// as menu rows instead. A right-click on the bar opens the flyout with that
// window's actions open. Popouts per windows.lua's tags (Bar.isPopout).

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "appwindows"
    menuWidth: Theme.flyoutMenuWidth

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
    // no windows left: nothing to show
    onWindowsChanged: if (open && windows.length === 0) requestClose()

    // the app's class (its strip key is "<workspace>/<class>"), its desktop
    // entry for New window
    readonly property string cls: app ? app.key.split("/").slice(1).join("/") : ""
    readonly property var entry: cls !== "" ? Apps.byClass(cls).entry : null

    function focusWin(w) {
        var addr = "address:0x" + w.address
        root.requestClose()
        Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
        Hyprland.dispatch("hl.dsp.window.alter_zorder({mode=\"top\", window=\"" + addr + "\"})")
    }
    function closeWin(w) { Hyprland.dispatch("hl.dsp.window.close({window=\"address:0x" + w.address + "\"})") }
    function newWindow() {
        root.requestClose()
        if (root.entry) Apps.launch(root.entry)
    }
    // every window of the app onto the workspace you're on
    function bringHere() {
        var ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
        if (ws < 0) return
        root.windows.forEach(w => Hyprland.dispatch("hl.dsp.window.move({window=\"address:0x" + w.address + "\", workspace=" + ws + "})"))
        root.requestClose()
    }
    function closeAll() {
        root.windows.slice().forEach(w => root.closeWin(w))
        root.requestClose()
    }

    // a window's workspace id, -1 when not known yet
    function wsOf(w) {
        var o = w.toplevel && w.toplevel.lastIpcObject
        return o && o.workspace ? o.workspace.id : -1
    }
    readonly property int workspaceCount: {
        var seen = {}
        windows.forEach(w => seen[wsOf(w)] = true)
        return Object.keys(seen).length
    }

    // one of a window's actions, aimed at it by address
    function act(w, fn, extra) {
        Hyprland.dispatch("hl.dsp.window." + fn + "({window=\"address:0x" + w.address + "\"" + (extra ? ", " + extra : "") + "})")
        Hyprland.refreshToplevels()
    }

    // a window's actions, as [{ icon, name, act, lit }]: its mode, then Pin
    // while it floats and Promote for a popout
    function modeTools(w, ipc) {
        return [
            { icon: ipc.floating ? "󰕰" : "󰖲", name: ipc.floating ? "Tile" : "Float", act: "float" },
            { icon: "󰊓", name: "Fullscreen", act: "fullscreen", lit: !!ipc.fullscreen },
        ].concat(ipc.floating ? [{ icon: "󰐃", name: ipc.pinned ? "Unpin" : "Pin", act: "pin", lit: !!ipc.pinned }] : [])
         .concat(w.popout ? [{ icon: "󰖯", name: "Make it a main window", act: "promote" }] : [])
    }
    function runTool(w, a) {
        if (a === "promote")
            Quickshell.execDetached(["hyprctl", "eval", "promoteWindow(\"0x" + w.address + "\")"])
        else root.act(w, a, a === "float" ? "action=\"toggle\"" : "")
    }
    function kill(w) { Hyprland.dispatch("hl.dsp.window.kill({window=\"address:0x" + w.address + "\"})") }

    readonly property bool single: windows.length === 1


    FlyoutHeading {
        text: root.app ? root.app.name.toUpperCase() : ""
        hints: root.windows.length > 1 ? [root.windows.length + " windows · "
            + root.workspaceCount + (root.workspaceCount === 1 ? " workspace" : " workspaces")] : []
    }

    // the app's own windows, each followed by the popouts it opened; any
    // popout whose window isn't known comes last, unindented
    readonly property var rows: {
        var mains = windows.filter(w => !w.popout)
        var pops = windows.filter(w => w.popout)
        var out = [], placed = {}
        mains.forEach(w => {
            out.push({ win: w, child: false })
            pops.forEach(p => {
                if (p.from === w.address) {
                    out.push({ win: p, child: true })
                    placed[p.address] = true
                }
            })
        })
        pops.forEach(p => { if (!placed[p.address]) out.push({ win: p, child: false }) })
        return out
    }

    // --- several windows: the list, a window's actions as a toolbar -------------

    Repeater {
        model: root.single ? [] : root.rows

        Column {
            id: entry
            required property var modelData
            readonly property var win: modelData.win
            readonly property var ipc: win.toplevel && win.toplevel.lastIpcObject ? win.toplevel.lastIpcObject : ({})
            readonly property int ws: root.wsOf(win)
            readonly property bool expanded: root.bar.appWindowsOpen === win.address
            readonly property int indent: modelData.child ? Theme.fit(14) : 0
            // the toolbar button under the pointer, named in the row
            property string toolHint: ""
            width: parent ? parent.width : 0
            spacing: Theme.spaceXs

            Item {
                width: parent.width
                implicitHeight: row.implicitHeight

                // the elbow from the window above
                Rectangle {
                    visible: entry.modelData.child
                    x: entry.indent - Theme.fit(9)
                    y: -Theme.fit(4)
                    width: 1
                    height: parent.height / 2 + Theme.fit(4)
                    color: Theme.muted
                }
                Rectangle {
                    visible: entry.modelData.child
                    x: entry.indent - Theme.fit(9)
                    y: parent.height / 2
                    width: Theme.fit(6)
                    height: 1
                    color: Theme.muted
                }

                FlyoutRow {
                    id: row
                    x: entry.indent
                    width: parent.width - entry.indent
                    leadingImage: entry.win.source
                    leadingIcon: entry.win.source === "" ? entry.win.glyph : ""
                    label: entry.win.toplevel ? entry.win.toplevel.title || entry.win.name : entry.win.name
                    note: entry.expanded && entry.toolHint !== "" ? entry.toolHint
                        : entry.win.popout && !entry.modelData.child ? "Popout" : ""
                    dimmed: entry.win.blocked
                    trailing: !entry.win.blocked && entry.ws > 0 ? "ws " + entry.ws : ""
                    trailingIcons: entry.win.blocked ? ["󰌾"] : []
                    highlighted: !!Hyprland.activeToplevel && Hyprland.activeToplevel.address === entry.win.address
                    actionIcon: "󰅖"
                    actionHint: "Close"
                    extraIcon: entry.expanded ? "󰅃" : "󰅀"
                    onActivated: root.focusWin(entry.win)
                    onAction: root.closeWin(entry.win)
                    onExtra: root.bar.appWindowsOpen = entry.expanded ? "" : entry.win.address
                }
            }

            // its actions, open under it: mode, workspaces (its own lit), close, kill
            Flow {
                visible: entry.expanded
                x: entry.indent + Theme.iconCell
                width: parent.width - x
                spacing: 2
                bottomPadding: Theme.spaceXs

                Repeater {
                    model: root.modeTools(entry.win, entry.ipc)
                    IconButton {
                        required property var modelData
                        readonly property string name: modelData.name
                        icon: modelData.icon
                        lit: !!modelData.lit
                        HoverHandler { onHoveredChanged: entry.toolHint = hovered ? parent.name : "" }
                        onClicked: root.runTool(entry.win, modelData.act)
                    }
                }
                Item {
                    width: Theme.spaceS
                    height: Theme.controlSize
                    Rectangle { anchors.centerIn: parent; width: 1; height: parent.height * 0.6; color: Theme.border }
                }
                Repeater {
                    model: Settings.workspaceCount
                    IconButton {
                        required property int index
                        icon: String(index + 1)
                        readonly property string name: entry.ws === index + 1 ? "On workspace " + (index + 1) : "Move to workspace " + (index + 1)
                        lit: entry.ws === index + 1
                        HoverHandler { onHoveredChanged: entry.toolHint = hovered ? parent.name : "" }
                        onClicked: if (!lit) root.act(entry.win, "move", "workspace=" + (index + 1))
                    }
                }
                Item {
                    width: Theme.spaceS
                    height: Theme.controlSize
                    Rectangle { anchors.centerIn: parent; width: 1; height: parent.height * 0.6; color: Theme.border }
                }
                IconButton {
                    icon: "󰅖"
                    readonly property string name: "Close"
                    HoverHandler { onHoveredChanged: entry.toolHint = hovered ? parent.name : "" }
                    onClicked: root.closeWin(entry.win)
                }
                // for a window that ignores the polite one
                IconButton {
                    icon: "󰚌"
                    readonly property string name: armed ? "Kill it?" : "Kill"
                    warn: true
                    confirm: true
                    HoverHandler { onHoveredChanged: entry.toolHint = hovered ? parent.name : "" }
                    onArmedChanged: entry.toolHint = armed ? "Kill it?" : ""
                    onClicked: root.kill(entry.win)
                }
            }
        }
    }

    // --- one window: its actions as menu rows ------------------------------------

    Column {
        id: one
        visible: root.single && root.rows.length === 1
        width: parent.width
        readonly property var win: root.rows.length === 1 ? root.rows[0].win : null
        readonly property var ipc: win && win.toplevel && win.toplevel.lastIpcObject ? win.toplevel.lastIpcObject : ({})
        readonly property int ws: win ? root.wsOf(win) : -1

        FlyoutRow {
            leadingImage: one.win ? one.win.source : ""
            leadingIcon: one.win && one.win.source === "" ? one.win.glyph : ""
            label: !one.win ? "" : one.win.toplevel ? one.win.toplevel.title || one.win.name : one.win.name
            dimmed: !!one.win && one.win.blocked
            trailing: one.win && !one.win.blocked && one.ws > 0 ? "ws " + one.ws : ""
            trailingIcons: one.win && one.win.blocked ? ["󰌾"] : []
            highlighted: !!one.win && !!Hyprland.activeToplevel && Hyprland.activeToplevel.address === one.win.address
            onActivated: root.focusWin(one.win)
        }
    }

    FlyoutDivider { visible: one.visible }

    Column {
        visible: one.visible
        width: parent.width

        Repeater {
            model: one.win ? root.modeTools(one.win, one.ipc) : []
            FlyoutRow {
                required property var modelData
                leadingIcon: modelData.icon
                label: modelData.name
                highlighted: !!modelData.lit
                onActivated: root.runTool(one.win, modelData.act)
            }
        }

        // the workspaces it can go to, its own lit
        FlyoutRow {
            leadingIcon: "󰁔"
            label: "Move"
            enabled: false

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: Settings.workspaceCount
                    IconButton {
                        required property int index
                        icon: String(index + 1)
                        lit: one.ws === index + 1
                        onClicked: if (!lit) root.act(one.win, "move", "workspace=" + (index + 1))
                    }
                }
            }
        }
    }

    FlyoutDivider { visible: one.visible || root.windows.length > 1 }

    // --- the app's actions ------------------------------------------------------

    Column {
        width: parent.width

        FlyoutRow {
            visible: !!root.entry
            leadingIcon: "󰖯"
            label: "New window"
            onActivated: root.newWindow()
        }
        FlyoutRow {
            visible: root.windows.length > 1
            leadingIcon: "󰁌"
            label: "Bring all here"
            onActivated: root.bringHere()
        }
        FlyoutRow {
            visible: root.windows.length > 1
            leadingIcon: "󰅖"
            label: "Close all"
            confirmText: "Close all " + root.windows.length + "?"
            onActivated: root.closeAll()
        }
        FlyoutRow {
            visible: one.visible
            leadingIcon: "󰅖"
            label: "Close"
            onActivated: root.closeWin(one.win)
        }
        // for a window that ignores the polite one
        FlyoutRow {
            visible: one.visible
            leadingIcon: "󰚌"
            label: "Kill"
            alert: true
            confirmText: "Kill it?"
            onActivated: root.kill(one.win)
        }
    }
}
