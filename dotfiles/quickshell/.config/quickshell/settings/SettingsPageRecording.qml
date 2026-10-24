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

    readonly property var lengths: [30, 60, 90, 120, 300]

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
            labelFor: v => Recorder.lengthLabel(v)
            current: Settings.replaySeconds
            onPicked: v => {
                Settings.setReplaySeconds(v)
                page.say("Replays keep " + Recorder.lengthLabel(v), false)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "FILES" }

    SettingsField {
        label: "Format"
        hint: !Recorder.av1Supported ? "This GPU can't encode AV1, so H.264"
            : Settings.recordCodec === "av1" ? "Smaller files; some older phones can't play them"
            : "Plays anywhere, in bigger files"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            enabled: Recorder.av1Supported
            model: [{ value: "av1", text: "AV1" }, { value: "h264", text: "H.264" }]
            current: Recorder.codec
            onPicked: v => {
                Settings.setRecordCodec(v)
                page.say(v === "av1" ? "Recording in AV1" : "Recording in H.264", false)
            }
        }
    }

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
        text: "SUPER+R saves the replay, SUPER+SHIFT+S records; both work in games"
    }
}
