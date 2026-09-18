// Neutrino - Quickshell
// ~/.config/quickshell/flyouts/PrivacyFlyout.qml
//
// Self-contained: only needs the Privacy singleton.

import "../services"
import QtQuick

FlyoutPanel {
    flyout: "privacy"
    menuWidth: 240

    FlyoutHeading { text: "IN USE" }

    Repeater {
        model: [
            { icon: "󰍬", kind: "Microphone", apps: Privacy.state.mic },
            { icon: "󰄀", kind: "Camera",     apps: Privacy.state.camera },
            { icon: "󰍹", kind: "Screen",     apps: Privacy.state.screen },
        ].filter(k => k.apps.length > 0)

        FlyoutAction {
            required property var modelData
            checkable: false
            enabled: false
            icon: modelData.icon
            label: modelData.kind
            // unique names: a browser opens one stream per tab
            status: modelData.apps.filter((a, i, all) => all.indexOf(a) === i).join(", ")
        }
    }
}
