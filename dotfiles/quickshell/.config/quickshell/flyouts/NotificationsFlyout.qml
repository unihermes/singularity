// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationsFlyout.qml
//
// The notification history, newest first, a line each: the app's icon, the
// summary and its age, a close on hover. A click opens the whole card in
// place (body, picture, actions). Clear all on the heading while there's
// any, Do Not Disturb under the list, then Settings. Empty, it says so in a
// card. Opening it marks everything read; what was new stays marked while
// it's open.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "notifications"
    menuWidth: Theme.flyoutMenuWidth
    // the bell sits near the bar's right end, so run into the corner
    edgeMargin: 0

    // the key of the entry opened in place, "" for none
    property string expanded: ""

    onOpenChanged: {
        Notifications.setViewing(open)
        expanded = ""
    }

    FlyoutHeading {
        text: "NOTIFICATIONS" + (Notifications.count > 0 ? "  " + Notifications.count : "")
        control: Notifications.count > 0 ? clearChip : null
    }

    Component {
        id: clearChip
        FlyoutChip {
            text: "Clear all"
            confirmText: "Clear " + Notifications.count + "?"
            onClicked: Notifications.clearAll()
        }
    }

    HeadCard {
        visible: Notifications.count === 0
        glyph: "󰄬"
        glyphColor: Theme.good
        title: "All caught up"
        lines: ["The history is empty"]
    }

    Item {
        visible: Notifications.count > 0
        width: parent.width
        height: list.height

        ListView {
            id: list
            width: parent.width - (scroll.visible ? scroll.width + Theme.spaceM : 0)
            height: Math.min(contentHeight, Theme.fs(520))
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: Notifications.history

            delegate: Column {
                id: entry
                required property var modelData
                readonly property bool open: root.expanded === modelData.key
                width: list.width

                FlyoutRow {
                    width: parent.width
                    readonly property string appIcon: Notifications.iconOf(entry.modelData)
                    leadingImage: appIcon
                    leadingIcon: appIcon ? "" : "󰂚"
                    label: entry.modelData.summary || entry.modelData.appName || "Notification"
                    trailing: (Notifications.isNew(entry.modelData) ? "new · " : "") + Notifications.ago(entry.modelData)
                    highlighted: entry.open
                    actionIcon: "󰅖"
                    actionHint: "Clear"
                    onAction: Notifications.remove(entry.modelData)
                    onActivated: root.expanded = entry.open ? "" : entry.modelData.key
                }

                NotificationCard {
                    visible: entry.open
                    entry: entry.modelData
                    framed: false
                    inHistory: true
                    width: parent.width
                }
            }
        }

        ScrollBar {
            id: scroll
            anchors.right: parent.right
            flickable: list
        }
    }

    FlyoutDivider {}

    FlyoutAction {
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        label: "Do Not Disturb"
        status: Notifications.dnd ? "Popups are held" : ""
        checked: Notifications.dnd
        onActivated: Notifications.toggleDnd()
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: scope.openSettings("notifications")
    }
}
