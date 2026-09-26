// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationsFlyout.qml
//
// Every notification not yet dismissed, newest first, with Do Not Disturb
// and Clear all.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "notifications"
    menuWidth: 380

    FlyoutHeading {
        text: "NOTIFICATIONS" + (Notifications.count > 0 ? "  " + Notifications.count : "")
    }

    Text {
        visible: Notifications.count === 0
        width: parent.width
        height: Theme.row(40)
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: "No notifications"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Item {
        visible: Notifications.count > 0
        width: parent.width
        height: list.height

        ListView {
            id: list
            width: parent.width - (scroll.visible ? scroll.width + Theme.spaceM : 0)
            height: Math.min(contentHeight, Theme.fs(560))
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            spacing: Theme.spaceM
            model: Notifications.list

            delegate: Column {
                id: entry
                required property var modelData
                required property int index
                width: list.width
                spacing: Theme.spaceM

                FlyoutDivider { visible: entry.index > 0 }

                NotificationCard {
                    notification: entry.modelData
                    framed: false
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

    FlyoutRow {
        label: "Clear all"
        trailing: "󰎟"
        enabled: Notifications.count > 0
        onActivated: Notifications.clearAll()
    }
}
