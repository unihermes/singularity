// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AppWindowsFlyout.qml
//
// An app's windows from the strip, drawn as Settings.appWindowsStyle says:
//   list     a row each; popouts indented under their owner, a blocked
//            owner dimmed with a lock
//   actions  the list, then New window, Bring here and Close all
//   cards    the app large, then a tile per window, the actions as chips
//   compact  the list, then the actions as a line of icons
// A row or tile raises the window; close closes it; a popout's square
// promotes it. Popouts per windows.lua's tags (Bar.isPopout).

import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "appwindows"
    menuWidth: Theme.fit(style === "cards" ? 340 : 300)

    readonly property string style: Settings.appWindowsStyle

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

    FlyoutHeading {
        visible: root.style !== "cards"
        text: root.app ? root.app.name.toUpperCase() : ""
        hints: root.style === "list" ? [] : [root.windows.length + " windows"]
    }

    // cards: the app large, then a tile per window
    Row {
        visible: root.style === "cards"
        spacing: Theme.spaceL
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontHero
            height: width
            IconImage {
                anchors.fill: parent
                visible: !!root.app && root.app.source !== ""
                source: root.app ? root.app.source : ""
            }
            Text {
                anchors.centerIn: parent
                visible: !!root.app && root.app.source === ""
                text: root.app ? root.app.glyph : ""
                color: Theme.textStrong
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontTitle
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: root.app ? root.app.name : ""
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontTitle
            }
            Text {
                text: root.windows.length + " windows"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    TileGrid {
        visible: root.style === "cards"
        columns: 2
        Repeater {
            model: root.style === "cards" ? root.windows : []
            FlyoutTile {
                required property var modelData
                width: parent.cell
                clickable: true
                title: modelData.toplevel ? modelData.toplevel.title || modelData.name : modelData.name
                caption: modelData.popout ? "Popout" : modelData.blocked ? "Waiting on a popout" : "Window"
                lit: !!Hyprland.activeToplevel && Hyprland.activeToplevel.address === modelData.address
                dimmed: modelData.blocked
                onClicked: root.focusWin(modelData)
            }
        }
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

    Repeater {
        model: root.style === "cards" ? [] : root.rows

        Item {
            id: entry
            required property var modelData
            readonly property var win: modelData.win
            readonly property int indent: modelData.child ? Theme.fit(14) : 0
            width: parent ? parent.width : 0
            implicitHeight: row.implicitHeight

            // the elbow from the window above
            Rectangle {
                visible: entry.modelData.child
                x: entry.indent - Theme.fit(9)
                y: -Theme.fit(4)
                width: 1
                height: entry.height / 2 + Theme.fit(4)
                color: Theme.muted
            }
            Rectangle {
                visible: entry.modelData.child
                x: entry.indent - Theme.fit(9)
                y: entry.height / 2
                width: Theme.fit(6)
                height: 1
                color: Theme.muted
            }

            FlyoutRow {
                id: row
                x: entry.indent
                width: entry.width - entry.indent
                leadingImage: entry.win.source
                leadingIcon: entry.win.source === "" ? entry.win.glyph : ""
                label: entry.win.toplevel ? entry.win.toplevel.title || entry.win.name : entry.win.name
                note: entry.win.popout && !entry.modelData.child ? "Popout" : ""
                dimmed: entry.win.blocked
                trailingIcons: entry.win.blocked ? ["󰌾"] : []
                highlighted: !!Hyprland.activeToplevel && Hyprland.activeToplevel.address === entry.win.address
                actionIcon: "󰅖"
                actionHint: "Close"
                extraIcon: entry.win.popout ? "󰖯" : ""
                onActivated: root.focusWin(entry.win)
                onAction: root.closeWin(entry.win)
                onExtra: Quickshell.execDetached(["hyprctl", "eval", "promoteWindow(\"0x" + entry.win.address + "\")"])
            }
        }
    }

    // --- the app's actions ------------------------------------------------------

    FlyoutDivider { visible: root.style !== "list" }

    Repeater {
        model: root.style === "actions" ? [
            { icon: "󰖯", label: "New window", go: () => root.newWindow(), shown: !!root.entry },
            { icon: "󰁌", label: "Bring all here", go: () => root.bringHere(), shown: true },
        ] : []
        FlyoutRow {
            required property var modelData
            visible: modelData.shown
            leadingIcon: modelData.icon
            label: modelData.label
            onActivated: modelData.go()
        }
    }
    FlyoutRow {
        visible: root.style === "actions"
        leadingIcon: "󰅖"
        label: "Close all"
        confirmText: "Close " + root.windows.length + " windows?"
        onActivated: root.closeAll()
    }

    Row {
        visible: root.style === "cards"
        spacing: Theme.spaceS
        FlyoutChip { visible: !!root.entry; text: "New window"; onClicked: root.newWindow() }
        FlyoutChip { text: "Bring here"; onClicked: root.bringHere() }
        FlyoutChip { text: "Close all"; confirmText: "Close all?"; onClicked: root.closeAll() }
    }

    Row {
        visible: root.style === "compact"
        anchors.right: parent.right
        spacing: Theme.spaceXs
        IconButton { visible: !!root.entry; icon: "󰖯"; onClicked: root.newWindow() }
        IconButton { icon: "󰁌"; onClicked: root.bringHere() }
        IconButton { icon: "󰅖"; confirm: true; onClicked: root.closeAll() }
    }
}
