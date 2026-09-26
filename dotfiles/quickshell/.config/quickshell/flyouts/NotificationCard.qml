// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationCard.qml
//
// One notification: app icon and name, how long ago, summary, body, an
// attached image, and the sender's actions as chips. Clicking the card runs
// the "default" action, if the sender gave one, and dismisses it; the close
// glyph only dismisses. Shared by the popups and the history flyout, which
// sets `framed: false` since it draws its own box.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../services"

Item {
    id: root

    required property var notification
    property bool framed: true

    // the popup's timer holds off while the pointer is on the card
    readonly property bool hovered: hover.hovered

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notification.actions.find(a => a.identifier === "default") || null
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default" && a.text !== "")
    readonly property string icon: Notifications.iconFor(notification)

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
            if (root.defaultAction) root.defaultAction.invoke()
            Notifications.dismiss(root.notification)
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
                source: root.icon
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
                text: root.notification.appName || "Notification"
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
                text: Notifications.ago(root.notification)
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Text {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅖"
                color: closeArea.containsMouse ? Theme.bright : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    anchors.margins: -Theme.spaceS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismiss(root.notification)
                }
            }
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.notification.summary
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
            text: root.notification.body
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
            source: Notifications.pictureFor(root.notification)
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
                    onClicked: {
                        modelData.invoke()
                        Notifications.dismiss(root.notification)
                    }
                }
            }
        }
    }
}
