// One of the menu bar's application menus (bar/AppMenuModule.qml), drawn as
// flyout rows like the tray's menus: shortcuts as values on the right, the
// checked entry lit, submenus drilling down in place with the way back in
// the heading. An entry runs once the menu has closed (AppMenus.activate).

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: appMenu
    flyout: "appmenu"
    menuWidth: 300
    compactMenu: true

    readonly property var module: scope.barWindow ? scope.barWindow.widgetItem("appmenu") : null
    readonly property var top: module && module.current >= 0 ? AppMenus.menus[module.current] || null : null

    // ids of the submenus drilled into, innermost last; looked up in the
    // live menu, so an app's update shows while it's open
    property var stack: []
    onTopChanged: stack = []
    onOpenChanged: if (!open) stack = []

    function find(items, id) {
        return (items || []).find(it => it.id === id) || null
    }
    readonly property var path: {
        var out = [], at = top
        for (var i = 0; at && i < stack.length; i++) {
            at = find(at.children, stack[i])
            if (at) out.push(at)
        }
        return out
    }
    readonly property var shown: path.length > 0 ? path[path.length - 1] : top

    // the app's own menu is told which part is showing
    property var told: null
    onShownChanged: {
        if (told) AppMenus.closed(told)
        told = open ? shown : null
        if (told) AppMenus.opened(told)
    }

    // no leading, trailing or doubled separators
    readonly property var entries: {
        if (!shown || !shown.children) return []
        var out = []
        shown.children.forEach(e => {
            if (e.separator && (out.length === 0 || out[out.length - 1].separator)) return
            out.push(e)
        })
        while (out.length > 0 && out[out.length - 1].separator) out.pop()
        return out
    }

    // in a submenu, the heading leads back to the menu above
    FlyoutHeading {
        visible: appMenu.path.length > 0
        crumb: appMenu.path.length > 1 ? appMenu.path[appMenu.path.length - 2].label
            : appMenu.top ? appMenu.top.label : ""
        text: appMenu.shown ? appMenu.shown.label : ""
        onCrumbClicked: appMenu.stack = appMenu.stack.slice(0, -1)
    }

    Repeater {
        model: appMenu.entries

        Item {
            id: entryRow
            required property var modelData
            readonly property bool isSectionBreak: modelData.separator
            width: parent ? parent.width : 0
            implicitHeight: modelData.separator ? divider.implicitHeight : row.implicitHeight
            height: implicitHeight

            FlyoutDivider {
                id: divider
                visible: entryRow.modelData.separator
            }

            FlyoutRow {
                id: row
                visible: !entryRow.modelData.separator
                label: entryRow.modelData.label
                enabled: entryRow.modelData.enabled
                highlighted: entryRow.modelData.checked
                trailing: entryRow.modelData.children ? "󰅂" : entryRow.modelData.shortcut || ""
                trailingIsValue: !entryRow.modelData.children
                onActivated: {
                    if (entryRow.modelData.children) {
                        appMenu.stack = appMenu.stack.concat([entryRow.modelData.id])
                    } else {
                        var it = entryRow.modelData
                        appMenu.scope.openFlyout = ""
                        AppMenus.activate(it)
                    }
                }
            }
        }
    }

    FlyoutRow {
        visible: appMenu.entries.length === 0
        label: "Nothing in this menu"
        enabled: false
    }
}
