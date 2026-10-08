// Singularity - Quickshell
// ~/.config/quickshell/flyouts/TrayMenuFlyout.qml
//
// The system tray's own D-Bus menu, drawn as flyout rows so it matches
// everything else rather than popping a native Qt menu. Submenus drill down
// in place, like the control centre. Split out of shell.qml; `item` and
// `stack` are set from outside by BarModules.qml when a tray icon is
// right-clicked.

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: trayMenu
    flyout: "traymenu"
    menuWidth: 240

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

    Repeater {
        model: trayMenu.open ? trayOpener.children.values : []

        Item {
            id: entryRow
            required property var modelData
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
}
