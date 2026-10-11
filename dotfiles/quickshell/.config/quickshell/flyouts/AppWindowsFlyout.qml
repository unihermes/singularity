// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AppWindowsFlyout.qml
//
// An app's icon in the bar's open-windows strip, when the app has more
// than one window: every one of them, a row each, as the Windows taskbar
// lists a grouped app's. Each popout sits indented under the window it came
// from; a window a popout is blocking is dimmed, with a lock. A row brings
// that window up; its close action closes it, and a popout's square makes
// it one of the app's own windows. Which windows are popouts, and whose, is
// windows.lua's call (Bar.isPopout).

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
                onActivated: {
                    var addr = "address:0x" + entry.win.address
                    root.requestClose()
                    Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                    Hyprland.dispatch("hl.dsp.window.alter_zorder({mode=\"top\", window=\"" + addr + "\"})")
                }
                onAction: Hyprland.dispatch("hl.dsp.window.close({window=\"address:0x" + entry.win.address + "\"})")
                onExtra: Quickshell.execDetached(["hyprctl", "eval", "promoteWindow(\"0x" + entry.win.address + "\")"])
            }
        }
    }
}
