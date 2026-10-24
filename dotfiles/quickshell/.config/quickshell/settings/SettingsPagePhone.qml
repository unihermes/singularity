// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPagePhone.qml
//
// The Android phone over adb (services/Phone.qml): which one is connected
// and how, and pairing for Wi-Fi through a QR code the phone scans. Then
// the phone link (services/PhoneLink.qml): its switch, and the phones the
// KDE Connect app shows from, to pair or unpair.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Phone"
    description: "Your Android phone on screen, and linked through KDE Connect."

    // the code is only good while this page shows it
    onVisibleChanged: if (!visible) Phone.cancelPair()

    SettingsNote {
        visible: !Phone.available
        text: "scrcpy and android-tools aren't installed"
        alert: true
    }

    FlyoutHeading { text: "CONNECTED" }

    SettingsField {
        label: "Phone"
        hint: Phone.connected
            ? [Phone.device.wifi ? "Over Wi-Fi" : "Over USB",
               Phone.battery >= 0 ? Phone.battery + "%" + (Phone.charging ? " charging" : "") : ""].filter(t => t).join(" · ")
            : Phone.unauthorized ? "Allow USB debugging on the phone"
            : Phone.wifiAddr !== "" ? "Wireless debugging on; joined only for Mirror and Screenshot"
            : "None; plug it in, or pair it over Wi-Fi"

        FlyoutChip {
            anchors.right: parent.right
            visible: Phone.reachable
            icon: Phone.mirroring ? "󰓛" : "󰍹"
            text: Phone.mirroring ? "Stop" : "Mirror"
            onClicked: Phone.toggleMirror()
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WI-FI" }

    SettingsField {
        label: "Pair over Wi-Fi"
        hint: Phone.pairState === "waiting" ? "Scan the code from the phone"
            : Phone.pairState === "pairing" ? "Pairing…"
            : Phone.pairState === "done" ? "Paired; Mirror and Screenshot reach it while Wireless debugging is on"
            : Phone.pairState === "failed" ? Phone.pairError
            : "Once per phone, with the phone on this Wi-Fi"

        FlyoutChip {
            anchors.right: parent.right
            enabled: Phone.available
            icon: Phone.pairState === "waiting" || Phone.pairState === "pairing" ? "󰅖" : "󰐲"
            text: Phone.pairState === "waiting" || Phone.pairState === "pairing" ? "Cancel" : "Show code"
            onClicked: Phone.pairState === "waiting" || Phone.pairState === "pairing" ? Phone.cancelPair() : Phone.pair()
        }
    }

    // the code, white round it as scanners like, with where to find the scanner
    Column {
        visible: Phone.pairState === "waiting" && Phone.pairQr !== ""
        width: parent.width
        spacing: Theme.spaceS

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.fit(200)
            height: width
            radius: Theme.radiusInner
            color: "white"

            Image {
                anchors.fill: parent
                anchors.margins: Theme.spaceS
                source: Phone.pairQr
                smooth: false
                fillMode: Image.PreserveAspectFit
                cache: false
            }
        }

        SettingsNote {
            horizontalAlignment: Text.AlignHCenter
            text: "Developer options › Wireless debugging › Pair device with QR code"
        }
    }

    SettingsNote {
        text: "Wireless debugging turns off on a restart; turn it on again to reconnect"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PHONE LINK" }

    SettingsField {
        label: "Phone link"
        hint: !Settings.phoneLinkOn ? "Off; nothing runs"
            : PhoneLink.error !== "" ? PhoneLink.error
            : PhoneLink.connected ? "Linked to " + PhoneLink.device.name
            : "Open KDE Connect on the phone to find " + (PhoneLink.hostName || "this computer")

        Switch {
            anchors.right: parent.right
            checked: Settings.phoneLinkOn
            onToggled: {
                Settings.setPhoneLinkOn(!Settings.phoneLinkOn)
                page.say(Settings.phoneLinkOn ? "Phone link on" : "Phone link off", false)
            }
        }
    }

    Repeater {
        model: PhoneLink.devices

        SettingsField {
            id: phoneRow
            required property var modelData
            readonly property string pairing: modelData.pairing
            label: modelData.name
            hint: pairing === "requested" ? "Accept on the phone…"
                : pairing === "incoming" ? "Wants to pair"
                : !modelData.paired ? "Not paired"
                : !modelData.reachable ? "Paired · out of reach"
                : "Paired" + (modelData.battery >= 0 ? " · " + modelData.battery + "%" : "")

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS

                FlyoutChip {
                    visible: !phoneRow.modelData.paired && phoneRow.pairing === ""
                    text: "Pair"
                    onClicked: PhoneLink.pair(phoneRow.modelData.id)
                }
                FlyoutChip {
                    visible: phoneRow.pairing === "incoming"
                    text: "Accept"
                    onClicked: PhoneLink.accept(phoneRow.modelData.id)
                }
                FlyoutChip {
                    visible: phoneRow.pairing === "incoming"
                    text: "Decline"
                    onClicked: PhoneLink.reject(phoneRow.modelData.id)
                }
                FlyoutChip {
                    visible: phoneRow.modelData.paired
                    text: "Unpair"
                    confirmText: "Unpair?"
                    onClicked: PhoneLink.unpair(phoneRow.modelData.id)
                }
            }
        }
    }

    SettingsField {
        visible: Settings.phoneLinkOn && PhoneLink.running
        label: "Look again"
        hint: "If the phone doesn't show, with both on the same network"

        FlyoutChip {
            anchors.right: parent.right
            icon: "󰑐"
            text: "Look"
            onClicked: PhoneLink.refresh()
        }
    }

    SettingsNote {
        text: "Needs the KDE Connect app on the phone. Give it notification access there for its notifications here; files it sends land in Downloads. A VPN on the phone has to allow LAN connections."
    }
}
