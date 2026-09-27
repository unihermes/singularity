// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VolumeFlyout.qml

import "../services"
import QtQuick

FlyoutPanel {
    flyout: "volume"
    menuWidth: 220

    FlyoutHeading {
        text: "VOLUME  " + (Audio.muted ? "MUTED" : Audio.percent + "%")
    }

    // muted keeps the level on show, dimmed, as the volume toast does
    Slider {
        width: parent.width
        value: Audio.percent
        opacity: Audio.muted ? 0.5 : 1
        onMoved: v => Audio.setVolume(v)
    }

    FlyoutDivider {}

    FlyoutAction {
        icon: Audio.muted ? "󰖁" : "󰕾"
        label: "Mute"
        checked: Audio.muted
        onActivated: Audio.toggleMute()
    }

    FlyoutRow {
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("audio")
    }
}
