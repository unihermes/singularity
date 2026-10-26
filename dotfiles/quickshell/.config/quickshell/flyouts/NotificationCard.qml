// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationCard.qml
//
// One notification, title first: the app's icon beside a large title, its
// age and a close at the right; under the title (never back at the edge)
// the text, picture and what it can do. Buttons: Copy for a one-time code,
// Open (Notifications.activate), the sender's own actions, Open link for a
// link in the text, and ··· for Copy text, silencing the app and Settings.
//
// A popup (framed) shows its buttons while the pointer is on it, follows
// Theme.notifStyle, has an urgency stripe on its left edge shortening with
// `life`, and when grouped lists the `others` it stands for, a line each;
// a click on it opens what it's about. In the history (`inHistory`) it is
// `collapsed` to a few lines (the title, its age, two lines of text) until
// a click opens it in place: the icon stays put, an accent rail runs down
// from it, and the app and age go under the larger title with the buttons
// as links. Either click is toggled(). `standalone` (the reload toast):
// close only emits dismissed(), no buttons, critical always in full.

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../services"

Item {
    id: root

    required property var entry
    property bool framed: true
    property bool inHistory: false
    // grouped popups: the others this card stands for, newest first, which
    // it takes down with it
    property var others: []
    property bool standalone: false
    property int bodyLines: framed ? 4 : 6
    // the history's few lines, until it's opened
    property bool collapsed: false
    signal dismissed()
    signal toggled()

    readonly property bool popup: framed && !inHistory
    readonly property string style: popup && !(standalone && critical) ? Theme.notifStyle : "full"
    readonly property bool banner: style === "banner"
    // compact shows the rest while the pointer is on it
    readonly property bool expanded: style === "full" || (style === "compact" && hovered)

    // the popup's timer holds off while the pointer is on the card or its
    // menu is open
    readonly property bool hovered: hover.hovered || menuOpen
    property bool menuOpen: false

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical
    readonly property bool low: entry.urgency === NotificationUrgency.Low
    readonly property int stripeW: framed ? Math.max(3, Theme.borderWidth * 3) : 0
    // how much of a popup's time is left, 1 to 0; the stripe shows it
    property real life: 1
    readonly property bool unread: inHistory && Notifications.isNew(entry)

    readonly property var actions: entry.live && entry.live.tracked ? entry.live.actions : []
    readonly property string code: standalone ? "" : Notifications.codeIn(entry)
    readonly property string link: standalone ? "" : Notifications.linkIn(entry)
    // [{ text, primary, run }]: a code's Copy leads when there is one, else Open
    readonly property var buttons: {
        if (standalone) return []
        const e = entry
        const b = []
        if (code !== "") b.push({ text: "Copy " + code, primary: true, run: () => Notifications.copy(e, root.code) })
        b.push({ text: e.phone && !Notifications.desktopFor(e) ? "Open on phone" : "Open",
                 primary: code === "", run: () => Notifications.activate(e) })
        actions.filter(a => a.identifier !== "default" && a.text !== "")
            .forEach(a => b.push({ text: a.text, primary: false, run: () => Notifications.invoke(e, a) }))
        if (link !== "") b.push({ text: "Open link", primary: false, run: () => Notifications.openLink(e, root.link) })
        return b
    }
    readonly property bool showButtons: !standalone && !collapsed && (inHistory || !framed || hovered)

    // the icon's cell and the title's left edge, which everything under the
    // title shares
    readonly property real iconCell: popup ? Theme.fit(28) : Theme.fs(26)
    readonly property real iconSize: popup ? iconCell : Theme.fs(22)
    readonly property real textX: iconCell + (popup ? Theme.spaceM + Theme.spaceXs : Theme.spaceM)
    readonly property real pad: framed ? Theme.panelPad : 0
    // the header's first line, the icon centred on it
    readonly property real lineH: Math.max(popup ? iconCell : Theme.rowHeight, iconSize, titleMetrics.height)

    function close() {
        if (standalone) dismissed()
        else if (inHistory) Notifications.remove(entry)
        else {
            Notifications.hidePopup(entry)
            for (var i = 0; i < others.length; i++) Notifications.hidePopup(others[i])
        }
    }

    function plain(s) { return String(s || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() }

    implicitHeight: col.y + col.height + (inHistory ? Theme.spaceXs : pad)

    HoverHandler { id: hover }

    // a history line's hover, as a row's
    Rectangle {
        visible: root.inHistory
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: root.collapsed && hover.hovered ? Theme.hoverFill : "transparent"
    }

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

    // a popup's click opens what it's about; a history line's opens it
    MouseArea {
        anchors.fill: parent
        enabled: !root.inHistory || root.collapsed
        cursorShape: root.standalone ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.inHistory ? root.toggled() : root.standalone ? root.close() : Notifications.activate(root.entry)
    }

    FontMetrics {
        id: titleMetrics
        font: title.font
    }

    // icon, title, age and close
    Item {
        id: header
        x: root.pad + root.stripeW
        y: root.inHistory ? Theme.spaceXs : root.pad
        width: parent.width - x - root.pad
        height: Math.max(root.lineH, title.y + title.height)

        MouseArea {
            anchors.fill: parent
            enabled: root.inHistory && !root.collapsed
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }

        Image {
            id: appIcon
            readonly property bool shown: status === Image.Ready
            x: (root.iconCell - width) / 2
            y: (root.lineH - height) / 2
            width: root.iconSize
            height: root.iconSize
            visible: shown
            source: Notifications.iconOf(root.entry)
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
        }

        // no icon to show: the bell in its cell
        Text {
            visible: !appIcon.shown
            width: root.iconCell
            height: root.lineH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.critical ? "󰀦" : "󰂚"
            color: root.critical ? Theme.alert : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontLead
        }

        Text {
            id: title
            x: root.textX
            y: Math.max(0, (root.lineH - titleMetrics.height) / 2)
            width: when.x - Theme.spaceM - x
            // a banner puts the summary and body on the one line
            text: root.banner
                ? [root.entry.summary, root.plain(root.entry.body)].filter(t => t !== "").join("  ·  ")
                    || root.entry.appName || "Notification"
                : root.entry.summary || root.entry.appName || "Notification"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.banner || root.collapsed ? 1 : 2
            elide: Text.ElideRight
            color: root.critical ? Theme.alert : Theme.bright
            font.family: Theme.fontText
            font.pixelSize: root.collapsed ? Theme.fontBody : Theme.fontLead
            font.weight: Theme.weightStrong
        }

        Text {
            id: when
            anchors.right: closeBtn.visible ? closeBtn.left : parent.right
            anchors.rightMargin: closeBtn.visible ? Theme.spaceS : 0
            anchors.verticalCenter: closeBtn.verticalCenter
            // an open history card gives its age under the title instead
            text: root.inHistory && !root.collapsed ? ""
                : (root.unread ? "new · " : "") + (root.others.length > 0 ? (root.others.length + 1) + " · " : "")
                    + Notifications.ago(root.entry)
            color: root.unread ? Theme.accent : Theme.muted
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        IconButton {
            id: closeBtn
            // a history line's only while the pointer is on it
            visible: !root.collapsed || hover.hovered
            anchors.right: parent.right
            y: (root.lineH - height) / 2
            icon: "󰅖"
            onClicked: root.close()
        }
    }

    // the history's rail, down from the icon beside everything under the title
    Rectangle {
        visible: root.inHistory && !root.collapsed
        x: header.x + (root.iconCell - width) / 2
        y: header.y + root.lineH + Theme.spaceXs
        width: Theme.indicatorWidth
        height: Math.max(0, col.y + col.height - y)
        radius: width / 2
        color: Theme.accent
    }

    Column {
        id: col
        x: header.x + root.textX
        y: header.y + header.height + (root.inHistory ? 0 : Theme.spaceXs)
        width: header.width - root.textX
        spacing: root.collapsed ? 0 : Theme.spaceS

        Text {
            width: parent.width
            visible: root.inHistory && !root.collapsed
            text: (root.unread ? "new · " : "") + (root.entry.appName || "Notification")
                + " · " + Notifications.ago(root.entry)
            elide: Text.ElideRight
            color: root.unread ? Theme.accent : Theme.muted
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        Text {
            width: parent.width
            visible: text !== "" && root.expanded && !root.banner
            // without its <img> tags: the server doesn't offer body images,
            // and StyledText would fetch one from wherever it points.
            // Collapsed, plain and quieter, else the app's name
            text: root.collapsed ? root.plain(root.entry.body) || root.entry.appName || ""
                : String(root.entry.body || "").replace(/<img\b[^>]*>/gi, "")
            textFormat: root.collapsed ? Text.PlainText : Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.collapsed ? 2 : root.bodyLines
            elide: Text.ElideRight
            color: root.collapsed ? Theme.subtext : Theme.text
            linkColor: Theme.strokeFocus
            font.family: Theme.fontText
            font.pixelSize: root.collapsed ? Theme.fontSmall : Theme.fontBody
            font.weight: Theme.weightBody
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        Image {
            visible: status === Image.Ready && root.expanded && !root.banner && !root.collapsed
            width: Math.min(parent.width, implicitWidth)
            height: visible ? Math.min(Theme.fs(120), implicitHeight * width / Math.max(1, implicitWidth)) : 0
            source: root.collapsed ? "" : Notifications.pictureOf(root.entry)
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            sourceSize.width: parent.width * 2
        }

        // a popup's buttons as chips
        Flow {
            width: parent.width
            visible: root.showButtons && !root.inHistory
            spacing: Theme.spaceS

            Repeater {
                model: root.showButtons && !root.inHistory ? root.buttons : []

                FlyoutChip {
                    required property var modelData
                    text: modelData.text
                    selected: modelData.primary
                    onClicked: modelData.run()
                }
            }

            FlyoutChip {
                text: "···"
                selected: root.menuOpen
                onClicked: root.menuOpen = !root.menuOpen
            }
        }

        // the history's as links, a dot between
        LinkLine {
            visible: root.showButtons && root.inHistory
            links: root.showButtons && root.inHistory
                ? root.buttons.concat([{ text: root.menuOpen ? "Less" : "More", primary: false,
                                          run: () => root.menuOpen = !root.menuOpen }])
                : []
        }

        // ···: what any notification can do
        Column {
            width: parent.width
            visible: root.menuOpen && root.showButtons

            FlyoutRow {
                leadingIcon: "󰆏"
                label: "Copy text"
                onActivated: Notifications.copy(root.entry, Notifications.plainText(root.entry))
            }
            FlyoutRow {
                visible: (root.entry.appName || "") !== ""
                leadingIcon: Notifications.silenced(root.entry) ? "󰂚" : "󰂛"
                label: (Notifications.silenced(root.entry) ? "Popups back on for " : "Silence ") + root.entry.appName
                onActivated: Notifications.toggleSilent(root.entry)
            }
            FlyoutRow {
                leadingIcon: "󰒓"
                label: "Notification settings"
                onActivated: Notifications.openSettings(root.entry)
            }
        }

        // a grouped popup's others, a line each; a click opens that one
        Column {
            width: parent.width
            visible: root.popup && root.others.length > 0

            Repeater {
                model: root.popup ? root.others.slice(0, 3) : []

                Item {
                    id: other
                    required property var modelData
                    width: parent.width
                    height: Theme.rowHeightDense

                    Rectangle {
                        width: parent.width
                        height: Theme.borderWidth
                        color: Theme.stroke
                    }

                    Text {
                        id: otherTitle
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.45)
                        text: other.modelData.summary || other.modelData.appName
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: otherMouse.containsMouse ? Theme.bright : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                        font.weight: Theme.weightStrong
                    }

                    Text {
                        anchors.left: otherTitle.right
                        anchors.leftMargin: Theme.spaceM
                        anchors.right: otherAge.left
                        anchors.rightMargin: Theme.spaceM
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.plain(other.modelData.body)
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                    }

                    Text {
                        id: otherAge
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifications.ago(other.modelData)
                        color: Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
                    }

                    MouseArea {
                        id: otherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.activate(other.modelData)
                    }
                }
            }

            Text {
                visible: root.others.length > 3
                text: "+" + (root.others.length - 3) + " more in the history"
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
