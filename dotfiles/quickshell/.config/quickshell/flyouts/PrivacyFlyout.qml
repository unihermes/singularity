// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PrivacyFlyout.qml
//
// Self-contained: only needs the Privacy singleton.

import "../services"
import QtQuick

FlyoutPanel {
    id: privacyFlyout
    flyout: "privacy"
    menuWidth: 240

    readonly property var inUse: [
        { icon: "󰍬", kind: "Microphone", apps: Privacy.state.mic },
        { icon: "󰄀", kind: "Camera",     apps: Privacy.state.camera },
        { icon: "󰍹", kind: "Screen",     apps: Privacy.state.screen },
    ].filter(k => k.apps.length > 0)

    FlyoutHeading { text: "IN USE" }

    // the module lingers a moment after the last stream stops
    FlyoutRow {
        visible: privacyFlyout.inUse.length === 0
        label: "Nothing is recording"
        enabled: false
    }

    Repeater {
        model: privacyFlyout.inUse

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
