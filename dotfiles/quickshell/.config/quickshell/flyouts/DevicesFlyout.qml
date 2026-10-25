// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DevicesFlyout.qml
//
// DEVICES: one section, a row per device (its glyph and name, its level
// as a meter and a number, red when it runs low). The phone's row comes
// first with a Mirror button at its end (Stop while it's on screen), and
// opens a tray: Screenshot over adb, which joins a phone on Wi-Fi just for it;
// Ring and Send file through the phone link; the phone's notifications,
// a click on one opening it in place: its app and age, its text in full,
// its reply field, Open (its app, here or on the mirror) and its actions.
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

    // the phone's row, with Mirror (Stop while it's on screen) at its end
    Item {
        visible: root.phoneShown
        width: parent.width
        height: phoneRow.height

        FlyoutRow {
            id: phoneRow
            width: parent.width - (mirrorBtn.visible ? mirrorBtn.width + Theme.spaceS : 0)
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
            highlighted: root.trayOpen
            dimmed: root.awayPhone !== null
            enabled: !root.awayPhone
            onActivated: { root.trayOpen = !root.trayOpen; root.picked = "" }
        }

        IconButton {
            id: mirrorBtn
            visible: Phone.reachable
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: Phone.mirroring ? "󰓛" : "󰍹"
            lit: Phone.mirroring
            onClicked: root.phoneAct("mirror")
        }
    }

    Repeater {
        model: root.trayOpen ? root.actions : []
        FlyoutRow {
            required property var modelData
            leadingIcon: modelData.glyph
            label: modelData.text
            onActivated: root.phoneAct(modelData.act)
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

    // --- in the tray, the phone's notifications ---

    Repeater {
        model: root.trayOpen ? root.notes.slice(0, 8) : []

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
        visible: root.trayOpen && PhoneLink.connected && root.notes.length === 0
        label: "No notifications"
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
        onPicked: root.scope.openSettings("phone")
    }
}
