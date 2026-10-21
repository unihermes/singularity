// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationsFlyout.qml
//
// The notification history, newest first, a line each: the app's icon, the
// summary and its age, a close on hover. A click opens the whole card in
// place (body, picture, actions). Do Not Disturb and Clear all share the
// last line. Empty, it says so in a card. Opening it marks everything
// read; what was new stays marked while it's open.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "notifications"
    menuWidth: Theme.fit(360)
    // the bell sits near the bar's right end, so run into the corner
    edgeMargin: 0

    // the key of the entry opened in place, "" for none
    property string expanded: ""

    onOpenChanged: {
        Notifications.setViewing(open)
        expanded = ""
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
                    leadingImage: entry.modelData.icon || ""
                    leadingIcon: entry.modelData.icon ? "" : "󰂚"
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

    Item {
        width: parent.width
        implicitHeight: Theme.chipHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifications.dnd
                onToggled: Notifications.toggleDnd()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifications.dnd ? "Do Not Disturb · popups held" : "Do Not Disturb"
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        FlyoutChip {
            visible: Notifications.count > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear all"
            confirmText: "Clear " + Notifications.count + "?"
            onClicked: Notifications.clearAll()
        }
    }
}
