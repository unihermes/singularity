// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AppWindowsFlyout.qml
//
// An app's windows from the strip: a card for the app (its icon, how many
// windows on how many workspaces, New window at its end), then a row a
// window with its workspace, popouts indented under their owner and a
// blocked owner dimmed with a lock; Bring all here and Close all as chips.
// A row raises its window, close on hover, and its ⌄ opens the window's
// actions under it (float, fullscreen, pin, move, close); a right-click on
// the bar opens the flyout with that window's actions open. Popouts per
// windows.lua's tags (Bar.isPopout).

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

    FlyoutHeading {
        text: root.app ? root.app.name.toUpperCase() : ""
    }

    HeadCard {
        glyph: root.app ? root.app.glyph : ""
        image: root.app ? root.app.source : ""
        title: root.app ? root.app.name : ""
        lines: [root.windows.length + (root.windows.length === 1 ? " window" : " windows")
            + " · " + root.workspaceCount + (root.workspaceCount === 1 ? " workspace" : " workspaces")]

        IconButton {
            visible: !!root.entry
            icon: "󰖯"
            onClicked: root.newWindow()
        }
    }

    FlyoutDivider {}

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

    Repeater {
        model: root.rows

        Column {
            id: entry
            required property var modelData
            readonly property var win: modelData.win
            readonly property var ipc: win.toplevel && win.toplevel.lastIpcObject ? win.toplevel.lastIpcObject : ({})
            readonly property int ws: root.wsOf(win)
            readonly property bool expanded: root.bar.appWindowsOpen === win.address
            readonly property int indent: modelData.child ? Theme.fit(14) : 0
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
                    note: entry.win.popout && !entry.modelData.child ? "Popout" : ""
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

            // its actions, open under it
            Column {
                visible: entry.expanded
                x: entry.indent + Theme.iconCell
                width: parent.width - x
                spacing: Theme.spaceS
                bottomPadding: Theme.spaceS

                FlyoutChipLine {
                    chips: [
                        { icon: entry.ipc.floating ? "󰕰" : "󰖲", text: entry.ipc.floating ? "Tile" : "Float", act: "float" },
                        { icon: "󰊓", text: "Full", act: "fullscreen" },
                    ].concat(entry.ipc.floating ? [{ icon: "󰐃", text: entry.ipc.pinned ? "Unpin" : "Pin", act: "pin" }] : [])
                     .concat(entry.win.popout ? [{ icon: "󰖯", text: "Promote", act: "promote" }] : [])
                    onPicked: a => {
                        if (a === "promote")
                            Quickshell.execDetached(["hyprctl", "eval", "promoteWindow(\"0x" + entry.win.address + "\")"])
                        else root.act(entry.win, a, a === "float" ? "action=\"toggle\"" : "")
                    }
                }

                // the workspaces it can go to, its own lit
                Row {
                    spacing: Theme.spaceXs

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: Theme.spaceXs
                        text: "MOVE"
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                        font.letterSpacing: 1
                    }

                    Repeater {
                        model: Settings.workspaceCount

                        FlyoutChip {
                            required property int index
                            text: index + 1
                            selected: entry.ws === index + 1
                            onClicked: if (!selected) root.act(entry.win, "move", "workspace=" + (index + 1))
                        }
                    }
                }

                Row {
                    spacing: Theme.spaceS

                    FlyoutChip {
                        icon: "󰅖"
                        text: "Close"
                        onClicked: root.closeWin(entry.win)
                    }
                    // for a window that ignores the polite one
                    FlyoutChip {
                        icon: "󰚌"
                        text: "Kill"
                        confirmText: "Kill it?"
                        onClicked: Hyprland.dispatch("hl.dsp.window.kill({window=\"address:0x" + entry.win.address + "\"})")
                    }
                }
            }
        }
    }

    // --- the app's actions, with more than one window ---------------------------

    FlyoutDivider { visible: root.windows.length > 1 }

    Row {
        id: appChips
        visible: root.windows.length > 1
        width: parent.width
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing) / 2

        FlyoutChip {
            width: appChips.cell
            icon: "󰁌"
            text: "Bring all here"
            onClicked: root.bringHere()
        }
        FlyoutChip {
            width: appChips.cell
            icon: "󰅖"
            text: "Close all"
            confirmText: "Close " + root.windows.length + "?"
            onClicked: root.closeAll()
        }
    }
}
