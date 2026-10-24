// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PhoneFlyout.qml
//
// The phone as a card (its name, battery, and USB or Wi-Fi), then Mirror
// (Stop while it's on screen), Screenshot and Settings. Self-contained:
// only needs Phone.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "phone"
    menuWidth: Theme.flyoutMenuWidth

    FlyoutHeading { text: "PHONE" }

    HeadCard {
        visible: Phone.connected
        glyph: Phone.charging ? "󱊥" : "󰄜"
        title: Phone.name || "Phone"
        lines: [
            (Phone.battery >= 0 ? Phone.battery + "%" + (Phone.charging ? " · charging" : "") : ""),
            Phone.connected ? (Phone.device.wifi ? "Over Wi-Fi" : "Over USB") + (Phone.mirroring ? " · on screen" : "") : "",
        ]
    }

    FlyoutRow {
        visible: Phone.unauthorized
        leadingIcon: "󰄜"
        label: "Allow USB debugging on the phone"
        enabled: false
    }

    FlyoutChipLine {
        visible: Phone.connected
        onPicked: act => {
            root.scope.openFlyout = ""
            if (act === "mirror") Phone.toggleMirror()
            else if (act === "shot") Phone.screenshot()
            else if (act === "settings") root.scope.openSettings("phone")
        }
        chips: [
            Phone.mirroring ? { icon: "󰓛", text: "Stop", act: "mirror" } : { icon: "󰍹", text: "Mirror", act: "mirror" },
            { icon: "󰹑", text: "Screenshot", act: "shot" },
            { icon: "󰒓", text: "Settings", act: "settings" },
        ]
    }
}
