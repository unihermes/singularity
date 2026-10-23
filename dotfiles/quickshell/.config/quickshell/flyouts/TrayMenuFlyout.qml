// Singularity - Quickshell
// ~/.config/quickshell/flyouts/TrayMenuFlyout.qml
//
// The system tray's own D-Bus menu, drawn as flyout rows so it matches
// everything else rather than popping a native Qt menu. Submenus drill down
// in place, like the control centre. Split out of shell.qml; `item` and
// `stack` are set from outside by BarModules.qml when a tray icon is
// right-clicked. The app's separators split the menu into sections. At the
// top level the shell's own rows close the menu, the same in every app: show
// its window, pin it (with the drawer on), hide it from the tray, quit. The
// app's own show and quit entries come out of the list for them.

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: trayMenu
    flyout: "traymenu"
    menuWidth: Theme.flyoutMenuWidth

    property var item: null
    // submenu handles, innermost last
    property var stack: []
    onOpenChanged: if (!open) stack = []

    QsMenuOpener {
        id: trayOpener
        menu: trayMenu.stack.length > 0 ? trayMenu.stack[trayMenu.stack.length - 1]
            : (trayMenu.item ? trayMenu.item.menu : null)
    }

    readonly property string appName: item ? scope.barWindow.trayName(item) : ""
    readonly property string appTitle: appName !== "" ? appName.toUpperCase() : "MENU"
    function entryTitle(entry) { return entry.text.replace(/_/g, "").toUpperCase() }

    // in a submenu the heading leads with the menu above, the way back
    FlyoutHeading {
        crumb: trayMenu.stack.length === 0 ? ""
            : trayMenu.stack.length === 1 ? trayMenu.appTitle
            : trayMenu.entryTitle(trayMenu.stack[trayMenu.stack.length - 2])
        text: trayMenu.stack.length === 0 ? trayMenu.appTitle
            : trayMenu.entryTitle(trayMenu.stack[trayMenu.stack.length - 1])
        onCrumbClicked: trayMenu.stack = trayMenu.stack.slice(0, -1)
    }

    readonly property bool atTop: stack.length === 0
    function plain(e) { return e.text.replace(/_/g, "").replace(/\.+$|…$/, "").trim().toLowerCase() }
    // how surely an entry shows the app's window, 9 for not at all
    function showRank(e) {
        var t = plain(e), title = appName.toLowerCase()
        return /^(show|restore|unhide)\b/.test(t) ? 0
            : t === "open" || t === "open " + title || /^open (app|window|main window)$/.test(t) ? 1
            : 9
    }
    // the app's own show and quit entries, null when it has none: the last
    // that reads as one, since an app's own sits at the end and an entry
    // above may only share the word (a chat named "Exit")
    readonly property var topEntries: open && atTop
        ? trayOpener.children.values.filter(e => !e.isSeparator && !e.hasChildren) : []
    readonly property var showEntry: {
        var best = null, bestRank = 9
        topEntries.forEach(e => { var r = showRank(e); if (r <= bestRank && r < 9) { best = e; bestRank = r } })
        return best
    }
    readonly property var quitEntry: {
        var found = null
        topEntries.forEach(e => { if (/^(quit|exit)\b/.test(plain(e))) found = e })
        return found
    }
    // the rows: at the top level without those two, and no separator left
    // leading, trailing or doubled
    readonly property var entries: {
        if (!open) return []
        var es = trayOpener.children.values.filter(e => e !== showEntry && e !== quitEntry)
        var out = []
        for (var i = 0; i < es.length; i++) {
            if (es[i].isSeparator && (out.length === 0 || out[out.length - 1].isSeparator)) continue
            out.push(es[i])
        }
        while (out.length > 0 && out[out.length - 1].isSeparator) out.pop()
        return out
    }

    Repeater {
        model: trayMenu.entries

        Item {
            id: entryRow
            required property var modelData
            // the app's separators split the menu into sections
            readonly property bool isSectionBreak: modelData.isSeparator
            width: parent ? parent.width : 0
            implicitHeight: modelData.isSeparator ? divider.implicitHeight : row.implicitHeight
            height: implicitHeight

            FlyoutDivider {
                id: divider
                visible: entryRow.modelData.isSeparator
            }

            FlyoutRow {
                id: row
                visible: !entryRow.modelData.isSeparator
                label: entryRow.modelData.text.replace(/_/g, "")
                enabled: entryRow.modelData.enabled
                // checkState 2 = checked, for toggle and radio entries
                highlighted: entryRow.modelData.checkState === 2
                trailing: entryRow.modelData.hasChildren ? "󰅂" : ""
                onActivated: {
                    if (entryRow.modelData.hasChildren) {
                        trayMenu.stack = trayMenu.stack.concat([entryRow.modelData])
                    } else {
                        entryRow.modelData.triggered()
                        scope.openFlyout = ""
                    }
                }
            }
        }
    }

    // the shell's own rows, at the top level
    FlyoutDivider { visible: trayMenu.atTop && trayMenu.entries.length > 0 }

    Column {
        visible: trayMenu.atTop
        width: parent.width

        FlyoutRow {
            leadingIcon: "󰖯"
            label: "Show window"
            onActivated: {
                var tray = scope.barWindow.widgetItem("tray")
                var win = scope.barWindow.trayItemWindow(trayMenu.item)
                if (win) tray.raise(win)
                else tray.showApp(trayMenu.item)
                scope.openFlyout = ""
            }
        }
        // with the tray drawer on: keep this app's icon out of the drawer
        FlyoutRow {
            visible: Settings.trayDrawer && !!trayMenu.item
            readonly property bool pinned: !!trayMenu.item && Settings.trayPinned.indexOf(trayMenu.item.id) !== -1
            leadingIcon: pinned ? "󰐄" : "󰐃"
            label: pinned ? "Unpin from the bar" : "Pin to the bar"
            onActivated: {
                Settings.setTrayPinned(trayMenu.item.id, !pinned)
                scope.openFlyout = ""
            }
        }
        // shown again from Settings > Appearance > Bar
        FlyoutRow {
            visible: trayMenu.appName !== ""
            leadingIcon: "󰈉"
            label: "Hide from the tray"
            onActivated: {
                Settings.setTrayHidden(trayMenu.appName, true)
                scope.openFlyout = ""
            }
        }
        FlyoutRow {
            visible: trayMenu.quitEntry !== null
            leadingIcon: "󰅖"
            label: "Quit"
            onActivated: {
                trayMenu.quitEntry.triggered()
                scope.openFlyout = ""
            }
        }
    }
}
