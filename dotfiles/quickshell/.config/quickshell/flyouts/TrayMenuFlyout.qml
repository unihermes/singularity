// Singularity - Quickshell
// ~/.config/quickshell/flyouts/TrayMenuFlyout.qml
//
// The system tray's own D-Bus menu, drawn as flyout rows so it matches
// everything else rather than popping a native Qt menu. Submenus drill down
// in place, like the control centre. Split out of shell.qml; `item` and
// `stack` are set from outside by BarModules.qml when a tray icon is
// right-clicked. The app's separators split the menu into sections. At the
// top level the two things every app has, showing its window and quitting,
// come out of the list as chips at the end, the same place in every menu.

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

    readonly property string appTitle: item ? (item.title || item.id || "MENU").toUpperCase() : "MENU"
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

    // with the tray drawer on: keep this app's icon out of the drawer
    FlyoutRow {
        visible: Settings.trayDrawer && trayMenu.stack.length === 0 && !!trayMenu.item
        readonly property bool pinned: !!trayMenu.item && Settings.trayPinned.indexOf(trayMenu.item.id) !== -1
        leadingIcon: pinned ? "󰐄" : "󰐃"
        label: pinned ? "Unpin from the bar" : "Pin to the bar"
        onActivated: {
            Settings.setTrayPinned(trayMenu.item.id, !pinned)
            scope.openFlyout = ""
        }
    }

    readonly property bool atTop: stack.length === 0
    function plain(e) { return e.text.replace(/_/g, "").replace(/\.+$|…$/, "").trim().toLowerCase() }
    function isShow(e) {
        var t = plain(e), title = item ? (item.title || "").toLowerCase() : ""
        return /^(show|restore|unhide)\b/.test(t) || t === "open" || t === "open " + title
            || /^open (app|window|main window|\S+)$/.test(t)
    }
    function isQuit(e) { return /^(quit|exit)\b/.test(plain(e)) }
    // the app's Quit entry, null when it has none
    readonly property var quitEntry: {
        if (!open || !atTop) return null
        var es = trayOpener.children.values
        for (var i = 0; i < es.length; i++)
            if (!es[i].isSeparator && !es[i].hasChildren && isQuit(es[i])) return es[i]
        return null
    }
    // the rows: at the top level without the show and quit entries, and no
    // separator left leading, trailing or doubled
    readonly property var entries: {
        if (!open) return []
        var es = trayOpener.children.values.filter(e => !atTop || e.isSeparator || e.hasChildren || !(isShow(e) || isQuit(e)))
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

    // the way out, at the top level
    FlyoutDivider { visible: trayMenu.atTop }

    Row {
        id: tail
        visible: trayMenu.atTop
        width: parent.width
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing * (quitChip.visible ? 1 : 0)) / (quitChip.visible ? 2 : 1)

        FlyoutChip {
            width: tail.cell
            icon: "󰖯"
            text: "Show window"
            onClicked: {
                var tray = scope.barWindow.widgetItem("tray")
                var win = scope.barWindow.trayItemWindow(trayMenu.item)
                if (win) tray.raise(win)
                else tray.showApp(trayMenu.item)
                scope.openFlyout = ""
            }
        }
        FlyoutChip {
            id: quitChip
            visible: trayMenu.quitEntry !== null
            width: tail.cell
            icon: "󰅖"
            text: "Quit"
            onClicked: {
                trayMenu.quitEntry.triggered()
                scope.openFlyout = ""
            }
        }
    }
}
