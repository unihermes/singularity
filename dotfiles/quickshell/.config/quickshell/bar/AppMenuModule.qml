// The menu bar's application menus: the focused app's File, Edit, View… and
// the shell's Window menu, as titles after its name (services/AppMenus.qml).
// A click opens a title's menu in AppMenuFlyout; while one is open,
// pointing at another title opens that one instead, as on a Mac.

import Quickshell
import QtQuick
import "../services"

Row {
    id: root

    required property var host
    readonly property var screenScope: host.screenScope

    visible: Settings.widgetVisible("appmenu") && AppMenus.menus.length > 0
        && !Apps.isShellWindow(AppMenus.focused)
    height: Theme.barHeight

    // slides to its new slot when Bar Widgets reorders the bar
    property bool slideX: false
    Behavior on x {
        enabled: root.slideX
        NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
    }

    // the open menu's index in AppMenus.menus, -1 when none
    property int current: -1
    readonly property bool menuOpen: screenScope.openFlyout === "appmenu"
    onMenuOpenChanged: if (!menuOpen) current = -1

    function show(index, item) {
        current = index
        if (!menuOpen) {
            AppMenus.refresh()
            screenScope.toggleFlyout("appmenu", item)
            return
        }
        screenScope.flyoutAnchorX = item.mapToItem(null, item.width / 2, 0).x
        screenScope.flyoutAnchorItem = item
    }

    Repeater {
        // titles only, so a menu's entries changing doesn't rebuild the
        // title the open menu hangs from
        model: ScriptModel { values: AppMenus.menus.map(m => m.label) }

        BarModule {
            id: title
            required property string modelData
            required property int index
            label: modelData
            labelMaxWidth: Theme.sp(140)
            active: root.menuOpen && root.current === index
            onActivated: {
                if (root.menuOpen && root.current === index) root.screenScope.openFlyout = ""
                else root.show(index, title)
            }

            HoverHandler {
                onHoveredChanged: if (hovered && root.menuOpen && root.current !== title.index)
                    root.show(title.index, title)
            }
        }
    }
}
