// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PrivacyFlyout.qml
//
// The microphone, camera and screen as three tiles, lit while in use with
// the apps using them, then the microphone's mute.

import "../services"
import Quickshell.Services.Pipewire
import QtQuick

FlyoutPanel {
    id: privacyFlyout
    flyout: "privacy"
    menuWidth: Theme.fit(280)

    // unique names: a browser opens one stream per tab
    function names(apps) { return apps.filter((a, i, all) => all.indexOf(a) === i).join(", ") }

    readonly property var sensors: [
        { icon: "󰍬", kind: "Mic",    apps: Privacy.state.mic },
        { icon: "󰄀", kind: "Camera", apps: Privacy.state.camera },
        { icon: "󰍹", kind: "Screen", apps: Privacy.state.screen },
    ]

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: !!source && source.ready && !!source.audio
    PwObjectTracker { objects: privacyFlyout.open && privacyFlyout.source ? [privacyFlyout.source] : [] }

    FlyoutHeading { text: "IN USE" }

    TileGrid {
        columns: 3
        Repeater {
            model: privacyFlyout.sensors
            FlyoutTile {
                required property var modelData
                width: parent.cell
                centred: true
                glyph: modelData.icon
                title: modelData.kind
                caption: modelData.apps.length > 0 ? privacyFlyout.names(modelData.apps) : "Off"
                lit: modelData.apps.length > 0
                dimmed: !lit
            }
        }
    }

    FlyoutAction {
        visible: privacyFlyout.sourceReady
        icon: privacyFlyout.sourceReady && privacyFlyout.source.audio.muted ? "󰍭" : "󰍬"
        label: "Mute microphone"
        checked: privacyFlyout.sourceReady && privacyFlyout.source.audio.muted
        onActivated: privacyFlyout.source.audio.muted = !privacyFlyout.source.audio.muted
    }
}
