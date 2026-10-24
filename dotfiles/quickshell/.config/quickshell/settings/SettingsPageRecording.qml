// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageRecording.qml
//
// Screen recording and instant replay (services/Recorder.qml): whether a
// replay is held while a game has focus, how long it is, and where the
// files go.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Recording"
    description: "Recordings of the screen, and the last minute of a game kept to save."

    readonly property var lengths: [30, 60, 120, 300]
    function lengthLabel(s) { return s < 60 ? s + " s" : (s / 60) + " min" }

    SettingsNote {
        visible: !Recorder.available
        text: "gpu-screen-recorder isn't installed"
        alert: true
    }

    FlyoutHeading { text: "INSTANT REPLAY" }

    SettingsField {
        label: "Instant replay"
        hint: !Settings.replayOn ? "Off"
            : Recorder.replaying ? "Holding " + Recorder.replayGame + " now"
            : "Runs while a game has focus"

        Switch {
            anchors.right: parent.right
            checked: Settings.replayOn
            onToggled: {
                Settings.setReplayOn(!Settings.replayOn)
                page.say(Settings.replayOn ? "Instant replay on" : "Instant replay off", false)
            }
        }
    }

    SettingsField {
        label: "Replay length"
        hint: "Kept in memory, about " + Math.round(Settings.replaySeconds * 6.25) + " MB"
        dimmed: !Settings.replayOn

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: page.lengths
            labelFor: v => page.lengthLabel(v)
            current: Settings.replaySeconds
            onPicked: v => {
                Settings.setReplaySeconds(v)
                page.say("Replays keep " + page.lengthLabel(v), false)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "FILES" }

    SettingsField {
        label: "Recordings"
        hint: Recorder.recordDir.replace(Quickshell.env("HOME"), "~") + ", a folder an app"

        FlyoutChip {
            anchors.right: parent.right
            icon: "󰉋"
            text: "Open"
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", Recorder.recordDir])
        }
    }

    SettingsField {
        label: "Replays"
        hint: Recorder.replayDir.replace(Quickshell.env("HOME"), "~") + ", a folder a game"

        FlyoutChip {
            anchors.right: parent.right
            icon: "󰉋"
            text: "Open"
            onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", Recorder.replayDir])
        }
    }

    SettingsNote {
        text: "Keys to record and save a replay are among the Keybinds window's presets"
    }
}
