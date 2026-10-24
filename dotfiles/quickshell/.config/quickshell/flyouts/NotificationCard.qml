// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationCard.qml
//
// One notification: icon, app, age, summary, body, image, and actions while
// the sender holds it; a click opens what it's about (Notifications.activate).
// In a popup, close and actions
// only dismiss the popup; in the history (`inHistory`) close clears the
// entry and new ones are marked. Popups follow Theme.notifStyle, with an
// urgency stripe on its left edge shortening with `life`, and stand for `count` when grouped.
// `standalone` (the reload toast): close only emits dismissed(), critical
// always in full.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../services"

Item {
    id: root

    required property var entry
    property bool framed: true
    property bool inHistory: false
    // grouped popups: how many this card stands for, and the others it
    // takes down with it
    property int count: 1
    property var others: []
    property bool standalone: false
    property int bodyLines: framed ? 4 : 6
    signal dismissed()

    readonly property bool popup: framed && !inHistory
    readonly property string style: popup && !(standalone && critical) ? Theme.notifStyle : "full"
    readonly property bool banner: style === "banner"
    // compact shows the rest while the pointer is on it
    readonly property bool expanded: style === "full" || (style === "compact" && hovered)

    // the popup's timer holds off while the pointer is on the card
    readonly property bool hovered: hover.hovered

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property bool low: entry.urgency === NotificationUrgency.Low
    readonly property int stripeW: framed ? Math.max(3, Theme.borderWidth * 3) : 0
    // how much of a popup's time is left, 1 to 0; the stripe shows it
    property real life: 1
    readonly property var actions: entry.live && entry.live.tracked ? entry.live.actions : []
    readonly property var buttons: actions.filter(a => a.identifier !== "default" && a.text !== "")
    readonly property bool unread: inHistory && Notifications.isNew(entry)

    function close() {
        if (standalone) dismissed()
        else if (inHistory) Notifications.remove(entry)
        else {
            Notifications.hidePopup(entry)
            for (var i = 0; i < others.length; i++) Notifications.hidePopup(others[i])
        }
    }

    implicitHeight: col.implicitHeight + (framed ? Theme.panelPad * 2 : 0)

    HoverHandler { id: hover }

    PanelFrame {
        id: frame
        anchors.fill: parent
        visible: root.framed
        border.color: root.critical ? Theme.alert : Theme.stroke

        // the urgency stripe on the frame's very edge, over its strokes: a
        // slice of the frame's shape, so it follows the corners
        Item {
            visible: root.framed
            width: root.stripeW
            height: parent.height * root.life
            clip: true

            Rectangle {
                width: frame.width
                height: frame.height
                topLeftRadius: frame.topLeftRadius
                bottomLeftRadius: frame.bottomLeftRadius
                color: root.critical ? Theme.alert : root.low ? Theme.muted : Theme.accent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.standalone ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.standalone ? root.close() : Notifications.activate(root.entry)
    }

    Column {
        id: col
        x: root.framed ? Theme.panelPad + root.stripeW : 0
        y: root.framed ? Theme.panelPad : 0
        width: parent.width - x - (root.framed ? Theme.panelPad : 0)
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
                // a banner puts the summary and body here, on the one line
                text: root.banner
                    ? [root.entry.summary, String(root.entry.body || "").replace(/<[^>]*>/g, "")]
                        .filter(t => t !== "").join("  ·  ") || root.entry.appName || "Notification"
                    : root.entry.appName || "Notification"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.weight: (root.banner && !!root.entry.summary) ? Theme.weightStrong : Theme.weightBody
                color: root.critical ? Theme.alert : root.banner ? Theme.text : Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Text {
                id: when
                anchors.right: close.left
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                text: (root.count > 1 ? "+" + (root.count - 1) + " · " : "")
                    + (root.unread ? "new · " : "") + Notifications.ago(root.entry)
                color: root.unread ? Theme.accent : Theme.muted
                font.family: Theme.fontText
                font.weight: Theme.weightBody
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
            visible: text !== "" && !root.banner
            text: root.entry.summary
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Theme.bright
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            font.weight: Theme.weightStrong
        }

        Text {
            width: parent.width
            visible: text !== "" && root.expanded
            // without its <img> tags: the server doesn't offer body images,
            // and StyledText would fetch one from wherever it points
            text: String(root.entry.body || "").replace(/<img\b[^>]*>/gi, "")
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.bodyLines
            elide: Text.ElideRight
            color: Theme.text
            linkColor: Theme.strokeFocus
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            font.weight: Theme.weightBody
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Image {
            visible: status === Image.Ready && root.expanded
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
            visible: root.buttons.length > 0 && root.expanded
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
