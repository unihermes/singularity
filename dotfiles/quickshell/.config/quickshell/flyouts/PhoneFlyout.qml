// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PhoneFlyout.qml
//
// The phone as a card (its name, battery, and how it's connected), with
// Ring and Send file on it through the phone link; a phone asking to pair,
// with Accept and Decline; the phone's notifications, a click on one
// opening it in place: its app and age, its text in full, its reply field,
// Open (its app, here or on the mirror) and its actions; then Mirror (Stop while it's on
// screen) and Screenshot over adb, which joins a phone on Wi-Fi just for
// them, and Settings. Self-contained: only needs Phone and PhoneLink.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "phone"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var notes: PhoneLink.connected ? PhoneLink.device.notifications : []
    // the notification opened in place, for more of it, a reply and its
    // actions, by id
    property string picked: ""
    onOpenChanged: if (!open) picked = ""

    FlyoutHeading { text: "PHONE" }

    HeadCard {
        visible: Phone.reachable || PhoneLink.connected
        glyph: Phone.shownCharging ? "󱊥" : "󰄜"
        title: Phone.shownName || "Phone"
        lines: [
            (Phone.shownBattery >= 0 ? Phone.shownBattery + "%" + (Phone.shownCharging ? " · charging" : "") : ""),
            Phone.connected ? (Phone.device.wifi ? "Over Wi-Fi" : "Over USB") + (Phone.mirroring ? " · on screen" : "")
                : PhoneLink.connected ? "Through KDE Connect" : "Wireless debugging on",
        ]

        FlyoutChip {
            visible: PhoneLink.connected
            glyph: true
            text: "󰂞"
            onClicked: PhoneLink.ring()
        }
        FlyoutChip {
            visible: PhoneLink.connected && PhoneLink.canPick
            glyph: true
            text: "󰒊"
            onClicked: { root.scope.openFlyout = ""; PhoneLink.pickFiles() }
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

    // --- the phone's notifications ---

    FlyoutHeading {
        visible: PhoneLink.connected
        text: "NOTIFICATIONS" + (root.notes.length ? "  " + root.notes.length : "")
    }

    Repeater {
        model: root.notes.slice(0, 8)

        Column {
            id: phoneNote
            required property var modelData
            readonly property bool open: root.picked === modelData.id
            width: parent.width
            spacing: Theme.spaceS

            FlyoutRow {
                readonly property string appIcon: Notifications.iconOf({
                    icon: phoneNote.modelData.icon ? "file://" + phoneNote.modelData.icon : "", phone: true, picture: "",
                    appName: phoneNote.modelData.app, desktopEntry: "", summary: phoneNote.modelData.title })
                width: parent.width
                leadingImage: appIcon
                leadingIcon: appIcon ? "" : "󰂚"
                label: phoneNote.modelData.title || phoneNote.modelData.app
                note: phoneNote.modelData.text !== label ? phoneNote.modelData.text : ""
                highlighted: phoneNote.open
                actionIcon: phoneNote.modelData.clearable ? "󰅖" : ""
                actionHint: "Dismiss on the phone"
                onAction: PhoneLink.dismiss(phoneNote.modelData)
                onActivated: root.picked = phoneNote.open ? "" : phoneNote.modelData.id
            }

            // opened: the app and age, then the text in full, a few lines
            Text {
                visible: phoneNote.open
                width: parent.width
                text: [phoneNote.modelData.app, Notifications.ago(phoneNote.modelData)].filter(t => t).join("  ·  ")
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
                font.weight: Theme.weightBody
            }

            Text {
                visible: phoneNote.open && text !== ""
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

            FlyoutChipLine {
                visible: phoneNote.open && chips.length > 0
                chips: (phoneNote.modelData.package ? [{ icon: "󰏌", text: "Open", act: "open" }] : [])
                    .concat(phoneNote.modelData.actions.map(a => ({ icon: "", text: a, act: "action:" + a })))
                onPicked: act => {
                    const n = phoneNote.modelData
                    root.picked = ""
                    if (act !== "open") { PhoneLink.act(n, act.slice("action:".length)); return }
                    root.scope.openFlyout = ""
                    Notifications.activate({ appName: n.app, desktopEntry: "", phone: true, phonePackage: n.package })
                }
            }
        }
    }

    FlyoutRow {
        visible: PhoneLink.connected && root.notes.length === 0
        label: "No notifications"
        enabled: false
    }

    FlyoutDivider {}

    FlyoutChipLine {
        onPicked: act => {
            root.scope.openFlyout = ""
            if (act === "mirror") Phone.toggleMirror()
            else if (act === "shot") Phone.screenshot()
            else if (act === "settings") root.scope.openSettings("phone")
        }
        chips: (Phone.reachable ? [
            Phone.mirroring ? { icon: "󰓛", text: "Stop", act: "mirror" } : { icon: "󰍹", text: "Mirror", act: "mirror" },
            { icon: "󰹑", text: "Screenshot", act: "shot" },
        ] : []).concat([{ icon: "󰒓", text: "Settings", act: "settings" }])
    }
}
