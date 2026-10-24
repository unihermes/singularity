// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PhoneFlyout.qml
//
// The phone as a card (its name, battery, and how it's connected), with
// Ring and Send file on it through the phone link; a phone asking to pair,
// with Accept and Decline; the phone's notifications, a click on one
// opening its reply field, Open (its app, here or on the mirror) and its
// actions; then Mirror (Stop while it's on
// screen) and Screenshot over adb, which joins a phone on Wi-Fi just for
// them, and Settings. Self-contained: only needs Phone and PhoneLink.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "phone"
    menuWidth: Theme.flyoutMenuWidth

    readonly property var notes: PhoneLink.connected ? PhoneLink.device.notifications : []
    // the notification picked for a reply or its actions, by id
    property string picked: ""
    readonly property var pickedNote: notes.find(n => n.id === picked) || null
    onOpenChanged: if (!open) { picked = ""; replyField.text = "" }
    onPickedChanged: replyField.text = ""

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
        FlyoutRow {
            required property var modelData
            leadingImage: modelData.icon ? "file://" + modelData.icon : ""
            leadingIcon: modelData.icon ? "" : "󰂚"
            label: modelData.title || modelData.app
            note: modelData.text !== label ? modelData.text : ""
            highlighted: root.picked === modelData.id
            enabled: modelData.replyId !== "" || modelData.actions.length > 0 || modelData.package !== ""
            actionIcon: modelData.clearable ? "󰅖" : ""
            actionHint: "Dismiss on the phone"
            onAction: PhoneLink.dismiss(modelData)
            onActivated: root.picked = root.picked === modelData.id ? "" : modelData.id
        }
    }

    FlyoutRow {
        visible: PhoneLink.connected && root.notes.length === 0
        label: "No notifications"
        enabled: false
    }

    FlyoutInput {
        id: replyField
        visible: root.pickedNote !== null && root.pickedNote.replyId !== ""
        bleed: true
        placeholder: root.pickedNote ? "Reply to " + (root.pickedNote.title || root.pickedNote.app) : ""
        onAccepted: {
            if (text.trim() === "") return
            PhoneLink.reply(root.pickedNote, text)
            root.picked = ""
        }
        onEscapePressed: root.picked = ""
    }

    FlyoutChipLine {
        visible: chips.length > 0
        chips: !root.pickedNote ? []
            : (root.pickedNote.package ? [{ icon: "󰏌", text: "Open", act: "open" }] : [])
                .concat(root.pickedNote.actions.map(a => ({ icon: "", text: a, act: "action:" + a })))
        onPicked: act => {
            const n = root.pickedNote
            root.picked = ""
            if (act !== "open") { PhoneLink.act(n, act.slice("action:".length)); return }
            root.scope.openFlyout = ""
            Notifications.activate({ appName: n.app, desktopEntry: "", phone: true, phonePackage: n.package })
        }
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
