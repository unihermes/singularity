// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationCard.qml
//
// One history entry (services/Notifications.qml): app icon and name, how long
// ago, summary, body, an attached image, and the sender's actions as chips
// while it still holds the notification. Clicking the card runs the
// "default" action, if there is one. Shared by the popups, where the close
// glyph and any action only take the popup down, and the history flyout
// (`inHistory`), where the close glyph clears the entry for good and new
// entries are marked.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../services"

Item {
    id: root

    required property var entry
    property bool framed: true
    property bool inHistory: false

    // the popup's timer holds off while the pointer is on the card
    readonly property bool hovered: hover.hovered

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property var actions: entry.live && entry.live.tracked ? entry.live.actions : []
    readonly property var defaultAction: actions.find(a => a.identifier === "default") || null
    readonly property var buttons: actions.filter(a => a.identifier !== "default" && a.text !== "")
    readonly property bool unread: inHistory && Notifications.isNew(entry)

    function close() {
        if (inHistory) Notifications.remove(entry)
        else Notifications.hidePopup(entry)
    }

    implicitHeight: col.implicitHeight + (framed ? Theme.panelPad * 2 : 0)

    HoverHandler { id: hover }

    PanelFrame {
        anchors.fill: parent
        visible: root.framed
        border.color: root.critical ? Theme.alert : Theme.stroke
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction) Notifications.invoke(root.entry, root.defaultAction)
            else if (!root.inHistory) Notifications.hidePopup(root.entry)
        }
    }

    Column {
        id: col
        x: root.framed ? Theme.panelPad : 0
        y: root.framed ? Theme.panelPad : 0
        width: parent.width - x * 2
        spacing: Theme.spaceS

        // app, time, close
        Item {
            width: parent.width
            height: Theme.iconCell

            Image {
                id: appIcon
                visible: status === Image.Ready
                width: visible ? Theme.iconCell : 0
                height: Theme.iconCell
                anchors.verticalCenter: parent.verticalCenter
                source: root.entry.icon
                sourceSize: Qt.size(Theme.iconCell * 2, Theme.iconCell * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                anchors.left: appIcon.right
                anchors.leftMargin: appIcon.visible ? Theme.spaceM : 0
                anchors.right: when.left
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                text: root.entry.appName || "Notification"
                elide: Text.ElideRight
                color: root.critical ? Theme.alert : Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Text {
                id: when
                anchors.right: close.left
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                text: (root.unread ? "new · " : "") + Notifications.ago(root.entry)
                color: root.unread ? Theme.accent : Theme.muted
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            IconButton {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰅖"
                onClicked: root.close()
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.entry.summary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Theme.bright
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            font.bold: true
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.entry.body
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.framed ? 4 : 6
            elide: Text.ElideRight
            color: Theme.text
            linkColor: Theme.strokeFocus
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Image {
            visible: status === Image.Ready
            width: Math.min(parent.width, implicitWidth)
            height: visible ? Math.min(Theme.fs(120), implicitHeight * width / Math.max(1, implicitWidth)) : 0
            source: Notifications.pictureOf(root.entry)
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            sourceSize.width: parent.width * 2
            asynchronous: true
        }

        Flow {
            width: parent.width
            visible: root.buttons.length > 0
            spacing: Theme.spaceS

            Repeater {
                model: root.buttons

                FlyoutChip {
                    required property var modelData
                    text: modelData.text
                    onClicked: Notifications.invoke(root.entry, modelData)
                }
            }
        }
    }
}
