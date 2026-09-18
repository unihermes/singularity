// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VolumeFlyout.qml

import "../services"
import Quickshell
import QtQuick

FlyoutPanel {
    flyout: "volume"
    menuWidth: 220

    FlyoutHeading {
        text: "VOLUME  " + (Audio.muted ? "MUTED" : Audio.percent + "%")
    }

    Slider {
        width: parent.width
        value: Audio.percent
        onMoved: v => Audio.setVolume(v)
    }

    FlyoutRow {
        label: Audio.muted ? "Unmute" : "Mute"
        onActivated: Audio.toggleMute()
    }

    FlyoutRow {
        label: "Sound settings"
        onActivated: {
            scope.openFlyout = ""
            Quickshell.execDetached(["pavucontrol"])
        }
    }
}
