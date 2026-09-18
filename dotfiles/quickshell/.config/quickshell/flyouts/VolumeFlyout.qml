// Neutrino - Quickshell
// ~/.config/quickshell/flyouts/VolumeFlyout.qml
//
// Needs bar's sink/volume state.

import "../services"
import Quickshell
import QtQuick

FlyoutPanel {
    flyout: "volume"
    menuWidth: 220

    required property var bar

    FlyoutHeading {
        text: "VOLUME  " + (bar.volumeMuted() ? "MUTED" : bar.volumePercent() + "%")
    }

    Slider {
        width: parent.width
        value: bar.volumePercent()
        onMoved: v => bar.setVolume(v)
    }

    FlyoutRow {
        label: bar.volumeMuted() ? "Unmute" : "Mute"
        onActivated: {
            if (bar.sink && bar.sink.ready && bar.sink.audio)
                bar.sink.audio.muted = !bar.sink.audio.muted
        }
    }

    FlyoutRow {
        label: "Sound settings"
        onActivated: {
            scope.openFlyout = ""
            Quickshell.execDetached(["pavucontrol"])
        }
    }
}
