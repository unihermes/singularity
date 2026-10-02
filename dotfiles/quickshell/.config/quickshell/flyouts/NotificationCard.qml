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
//
// A popup is drawn as Theme.notifStyle says (the history always shows
// everything), with an urgency stripe down its edge when Theme.notifStripe,
// and stands for `count` popups when the popups are grouped by app.

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

    readonly property bool popup: framed && !inHistory
    readonly property string style: popup ? Theme.notifStyle : "full"
    readonly property bool banner: style === "banner"
    // compact shows the rest while the pointer is on it
    readonly property bool expanded: style === "full" || (style === "compact" && hovered)
    readonly property bool low: entry.urgency === NotificationUrgency.Low
    readonly property bool stripe: framed && Theme.notifStripe
    readonly property int stripeW: stripe ? Math.max(3, Theme.borderWidth * 3) : 0

    // the popup's timer holds off while the pointer is on the card
    readonly property bool hovered: hover.hovered

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property var actions: entry.live && entry.live.tracked ? entry.live.actions : []
    readonly property var defaultAction: actions.find(a => a.identifier === "default") || null
    readonly property var buttons: actions.filter(a => a.identifier !== "default" && a.text !== "")
    readonly property bool unread: inHistory && Notifications.isNew(entry)

    function close() {
        if (inHistory) Notifications.remove(entry)
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

        // the urgency stripe, inside the frame's strokes
        Rectangle {
            visible: root.stripe
            readonly property int inset: Theme.frameDouble || Theme.frameChiselled ? Theme.frameInset + Theme.borderWidth
                : Theme.frameStroked ? Theme.borderWidth : 0
            x: inset
            y: inset
            width: root.stripeW
            height: parent.height - inset * 2
            topLeftRadius: Math.max(0, frame.topLeftRadius - inset)
            bottomLeftRadius: Math.max(0, frame.bottomLeftRadius - inset)
            color: root.critical ? Theme.alert : root.low ? Theme.muted : Theme.accent
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.defaultAction) Notifications.invoke(root.entry, root.defaultAction)
            else if (!root.inHistory) root.close()
        }
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
            text: root.entry.body
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.framed ? 4 : 6
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
