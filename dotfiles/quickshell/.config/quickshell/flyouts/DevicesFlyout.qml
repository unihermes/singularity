// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DevicesFlyout.qml
//
// DEVICES: the phone and every peripheral with a battery (Peripherals) as
// a row each with its level as a meter and a number, red when it runs
// low; a paired phone out of reach as away. Then the phone: its name as a card, with Ring
// and Send file through the phone link; a phone asking to pair, with
// Accept and Decline; its notifications, a click on one opening it in
// place: its app and age, its text in full, its reply field, Open (its
// app, here or on the mirror) and its actions; then Mirror (Stop while
// it's on screen) and Screenshot over adb, which joins a phone on Wi-Fi
// just for them, and Settings. Self-contained: only needs Phone,
// PhoneLink and Peripherals.

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
    onOpenChanged: if (!open) picked = ""

    readonly property bool phoneOn: Phone.connected || PhoneLink.connected
    // the paired phone while it's out of reach
    readonly property var awayPhone: phoneOn ? null : PhoneLink.devices.find(d => d.paired) || null

    FlyoutHeading { text: "DEVICES" }

    FlyoutRow {
        visible: root.phoneOn || root.awayPhone !== null
        leadingIcon: "󰄜"
        label: root.phoneOn ? Phone.shownName || "Phone" : root.awayPhone ? root.awayPhone.name : ""
        trailing: !root.phoneOn ? "away" : Phone.shownBattery < 0 ? ""
            : (Phone.shownCharging ? "󱐋 " : "") + Phone.shownBattery + "%"
        trailingIsValue: root.phoneOn
        level: root.phoneOn ? Phone.shownBattery : -1
        charging: Phone.shownCharging
        trailingAlert: root.phoneOn && Peripherals.isLow({ level: Phone.shownBattery, charging: Phone.shownCharging })
        dimmed: !root.phoneOn
        enabled: false
    }

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

    // --- the phone ---

    FlyoutHeading {
        visible: Phone.reachable || PhoneLink.connected || PhoneLink.request !== null || Phone.unauthorized
        text: "PHONE"
    }

    HeadCard {
        visible: Phone.reachable || PhoneLink.connected
        glyph: "󰄜"
        title: Phone.shownName || "Phone"
        lines: [Phone.mirroring ? "On screen" : "Not on screen"]

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
