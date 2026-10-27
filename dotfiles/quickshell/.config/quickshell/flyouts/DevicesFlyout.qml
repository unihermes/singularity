// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DevicesFlyout.qml
//
// DEVICES: one section, a row per device (its glyph and name, its level
// as a meter and a number, red when it runs low). The phone's row comes
// first with a Mirror button before its level (Stop while it's on screen), and
// opens a tray under its label, an accent rail down from its icon: Screenshot over adb, which joins a phone on Wi-Fi just for it;
// Ring and Send file through the phone link; the phone's notifications,
// a click on one opening it in place as an opened history card: the
// larger title, its app and age, its text in full, its reply field, and
// Open (its app, here or on the mirror) and its actions as links.
// A paired phone out of reach shows as away; a phone asking to pair, with
// Accept and Decline. Then every peripheral with a battery (Peripherals),
// and Settings. Self-contained: only needs Phone, PhoneLink and
// Peripherals.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "devices"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var notes: PhoneLink.connected ? PhoneLink.device.notifications : []
    // the notification opened in place, for more of it, a reply and its
    // actions, by id
    property string picked: ""
    // the phone's tray, shut each time the flyout opens
    property bool trayOpen: false
    onOpenChanged: if (!open) { picked = ""; trayOpen = false }

    readonly property bool phoneOn: Phone.connected || PhoneLink.connected
    // the paired phone while it's out of reach
    readonly property var awayPhone: phoneOn ? null : PhoneLink.devices.find(d => d.paired) || null
    readonly property bool phoneShown: phoneOn || Phone.reachable || awayPhone !== null

    // the tray's, after Mirror
    readonly property var actions: (Phone.reachable ? [{ glyph: "󰹑", text: "Screenshot", act: "shot" }] : []).concat(PhoneLink.connected ? [{ glyph: "󰂞", text: "Ring", act: "ring" }] : [])
        .concat(PhoneLink.connected && PhoneLink.canPick ? [{ glyph: "󰒊", text: "Send file", act: "send" }] : [])

    function phoneAct(act) {
        if (act === "ring") { PhoneLink.ring(); return }
        root.scope.openFlyout = ""
        if (act === "mirror") Phone.toggleMirror()
        else if (act === "shot") Phone.screenshot()
        else if (act === "send") PhoneLink.pickFiles()
    }

    FlyoutHeading { text: "DEVICES" }

    // --- the phone ---

    // the phone's row, with Mirror (Stop while it's on screen) before its level
    Item {
        visible: root.phoneShown
        width: parent.width
        height: phoneRow.height

        FlyoutRow {
            id: phoneRow
            reserve: mirrorBtn.visible ? mirrorBtn.width + Theme.spaceS : 0
            leadingIcon: "󰄜"
            label: root.awayPhone ? root.awayPhone.name : Phone.shownName || "Phone"
            note: Phone.mirroring ? "On screen" : !root.trayOpen && root.notes.length
                ? root.notes.length + (root.notes.length === 1 ? " notification" : " notifications") : ""
            trailing: root.awayPhone ? "away" : Phone.shownBattery < 0 ? (root.trayOpen ? "󰅃" : "󰅀")
                : (Phone.shownCharging ? "󱐋 " : "") + Phone.shownBattery + "%"
            trailingIsValue: !root.awayPhone && Phone.shownBattery >= 0
            level: root.awayPhone ? -1 : Phone.shownBattery
            charging: Phone.shownCharging
            trailingAlert: !root.awayPhone && Peripherals.isLow({ level: Phone.shownBattery, charging: Phone.shownCharging })
            dimmed: root.awayPhone !== null
            enabled: !root.awayPhone
            onActivated: { root.trayOpen = !root.trayOpen; root.picked = "" }
        }

        IconButton {
            id: mirrorBtn
            visible: Phone.reachable
            x: phoneRow.trailingStart - Theme.spaceS - width
            anchors.verticalCenter: parent.verticalCenter
            icon: Phone.mirroring ? "󰓛" : "󰍹"
            lit: Phone.mirroring
            onClicked: root.phoneAct("mirror")
        }
    }

    // --- the tray: the phone's actions and notifications, under the
    // phone's label, an accent rail down from its icon ---

    Item {
        visible: root.trayOpen
        width: parent.width
        height: tray.height

        Rectangle {
            x: (Theme.iconCell - width) / 2
            width: Theme.indicatorWidth
            height: tray.height
            radius: width / 2
            color: Theme.accent
        }

        Column {
            id: tray
            x: Theme.iconCell + Theme.spaceM
            width: parent.width - x
            spacing: Theme.flyoutSpacing

            Repeater {
                model: root.trayOpen ? root.actions : []
                FlyoutRow {
                    required property var modelData
                    leadingIcon: modelData.glyph
                    label: modelData.text
                    onActivated: root.phoneAct(modelData.act)
                }
            }

            Repeater {
                model: root.trayOpen ? root.notes.slice(0, 8) : []

                Item {
                    id: phoneNote
                    required property var modelData
                    readonly property bool open: root.picked === modelData.id
                    readonly property string appIcon: Notifications.iconOf({
                        icon: modelData.icon ? "file://" + modelData.icon : "", phone: true, picture: "",
                        appName: modelData.app, desktopEntry: "", summary: modelData.title })
                    // the title's left edge, a row label's, which everything under
                    // the opened title shares
                    readonly property real textX: Theme.iconCell + Theme.spaceM
                    width: parent.width
                    height: open ? body.y + body.height + Theme.spaceXs : noteRow.height

                    FlyoutRow {
                        id: noteRow
                        visible: !phoneNote.open
                        width: parent.width
                        leadingImage: phoneNote.appIcon
                        leadingIcon: phoneNote.appIcon ? "" : "󰂚"
                        label: phoneNote.modelData.title || phoneNote.modelData.app
                        note: phoneNote.modelData.text !== label ? phoneNote.modelData.text : ""
                        actionIcon: phoneNote.modelData.clearable ? "󰅖" : ""
                        actionHint: "Dismiss on the phone"
                        onAction: PhoneLink.dismiss(phoneNote.modelData)
                        onActivated: root.picked = phoneNote.modelData.id
                    }

                    // opened, as an opened history card: the icon stays put, an
                    // accent rail runs down from it, and the larger title leads,
                    // the app and age under it, the text in full, a reply field and
                    // the buttons as links
                    Item {
                        id: openHead
                        visible: phoneNote.open
                        width: parent.width
                        height: Math.max(Theme.rowHeight, openTitle.y + openTitle.height)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked = ""
                        }

                        Image {
                            visible: phoneNote.appIcon !== ""
                            x: (Theme.iconCell - width) / 2
                            y: (Theme.rowHeight - height) / 2
                            width: Theme.fontBody
                            height: width
                            sourceSize: Qt.size(width * 2, height * 2)
                            source: phoneNote.appIcon
                        }

                        Text {
                            visible: phoneNote.appIcon === ""
                            width: Theme.iconCell
                            height: Theme.rowHeight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "󰂚"
                            color: Theme.subtext
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontBody
                        }

                        Text {
                            id: openTitle
                            x: phoneNote.textX
                            y: Math.max(0, (Theme.rowHeight - titleMetrics.height) / 2)
                            width: (dismissBtn.visible ? dismissBtn.x - Theme.spaceS : parent.width) - x
                            text: phoneNote.modelData.title || phoneNote.modelData.app
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.bright
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontLead
                            font.weight: Theme.weightStrong
                        }

                        FontMetrics {
                            id: titleMetrics
                            font: openTitle.font
                        }

                        IconButton {
                            id: dismissBtn
                            visible: phoneNote.modelData.clearable
                            anchors.right: parent.right
                            y: (Theme.rowHeight - height) / 2
                            icon: "󰅖"
                            confirm: true
                            onClicked: PhoneLink.dismiss(phoneNote.modelData)
                        }
                    }

                    Rectangle {
                        visible: phoneNote.open
                        x: (Theme.iconCell - width) / 2
                        y: Theme.rowHeight + Theme.spaceXs
                        width: Theme.indicatorWidth
                        height: Math.max(0, body.y + body.height - y)
                        radius: width / 2
                        color: Theme.accent
                    }

                    Column {
                        id: body
                        visible: phoneNote.open
                        x: phoneNote.textX
                        y: openHead.height
                        width: parent.width - x
                        spacing: Theme.spaceS

                        Text {
                            width: parent.width
                            text: [phoneNote.modelData.app, Notifications.ago(phoneNote.modelData)].filter(t => t).join(" · ")
                            elide: Text.ElideRight
                            color: Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontSmall
                            font.weight: Theme.weightBody
                        }

                        Text {
                            visible: text !== ""
                            width: parent.width
                            text: phoneNote.modelData.text
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontBody
                            font.weight: Theme.weightBody
                        }

                        FlyoutInput {
                            visible: phoneNote.open && phoneNote.modelData.replyId !== ""
                            width: parent.width
                            bleed: true
                            placeholder: "Reply to " + (phoneNote.modelData.title || phoneNote.modelData.app)
                            onVisibleChanged: text = ""
                            onAccepted: {
                                if (text.trim() === "") return
                                PhoneLink.reply(phoneNote.modelData, text)
                                root.picked = ""
                            }
                            onEscapePressed: root.picked = ""
                        }

                        LinkLine {
                            visible: links.length > 0
                            links: {
                                const n = phoneNote.modelData
                                const l = n.package ? [{ text: "Open", primary: true, run: () => {
                                    root.picked = ""
                                    root.scope.openFlyout = ""
                                    Notifications.activate({ appName: n.app, desktopEntry: "", phone: true, phonePackage: n.package })
                                } }] : []
                                return l.concat(n.actions.map(a => ({ text: a, primary: false, run: () => {
                                    root.picked = ""
                                    PhoneLink.act(n, a)
                                } })))
                            }
                        }
                    }
                }
            }

            FlyoutRow {
                visible: PhoneLink.connected && root.notes.length === 0
                label: "No notifications"
                enabled: false
            }
        }
    }

    HeadCard {
        visible: PhoneLink.request !== null
        glyph: "󰄜"
        title: PhoneLink.request ? PhoneLink.request.name : ""
        lines: ["Asks to pair"]

        FlyoutChip { text: "Accept"; onClicked: PhoneLink.accept(PhoneLink.request.id) }
        FlyoutChip { text: "Decline"; onClicked: PhoneLink.reject(PhoneLink.request.id) }
    }

    FlyoutRow {
        visible: Phone.unauthorized
        leadingIcon: "󰄜"
        label: "Allow USB debugging on the phone"
        enabled: false
    }

    // --- the peripherals ---

    Repeater {
        model: Peripherals.devices
        FlyoutRow {
            required property var modelData
            leadingIcon: modelData.glyph
            label: modelData.name
            trailing: modelData.level < 0 ? "Off" : (modelData.charging ? "󱐋 " : "") + modelData.level + "%"
            trailingIsValue: modelData.level >= 0
            level: modelData.level
            charging: modelData.charging
            trailingAlert: Peripherals.isLow(modelData)
            dimmed: modelData.level < 0
            enabled: false
        }
    }

    FlyoutRow {
        visible: !root.phoneShown && Peripherals.devices.length === 0
        label: "No devices"
        enabled: false
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: root.scope.openSettings("devices")
    }
}
