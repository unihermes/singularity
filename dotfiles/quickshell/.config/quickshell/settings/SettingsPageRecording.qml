// Screen recording and instant replay (services/Recorder.qml): whether a
// replay is held while a game has focus, how long it is, and where the
// files go (folders picked with zenity).

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Recording"
    description: "Screen recording and instant replay."

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
        hint: "Estimated memory use: " + Math.round(Settings.replaySeconds * 6.25) + " MB"
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
        hint: !Recorder.av1Supported ? "AV1 encoding unavailable on this GPU"
            : Settings.recordCodec === "av1" ? "Smaller files; limited support on older devices"
            : "Wider compatibility; larger files"

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

    // a folder row: where its files go, Change (a folder dialog), Default
    // once moved, and Open
    component FolderField: SettingsField {
        id: folderRow
        required property string key
        required property string dir
        required property string defaultDir
        required property string grouping
        hint: dir.replace(Quickshell.env("HOME"), "~") + " · " + grouping

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutChip {
                visible: folderRow.dir !== folderRow.defaultDir
                icon: "󰑓"
                text: "Default"
                onClicked: {
                    Settings.setRecordFolder(folderRow.key, "")
                    page.say(folderRow.label + " go to " + folderRow.defaultDir.replace(Quickshell.env("HOME"), "~"), false)
                }
            }
            FlyoutChip {
                visible: zenityProbe.found
                enabled: !picker.running
                icon: "󰉖"
                text: "Change"
                onClicked: {
                    picker.key = folderRow.key
                    picker.label = folderRow.label
                    picker.command = ["sh", "-c", 'cd "$1" 2>/dev/null || cd; exec zenity --file-selection --directory --title="$2"',
                                      "sh", folderRow.dir, folderRow.label + " folder"]
                    picker.running = true
                }
            }
            FlyoutChip {
                icon: "󰉋"
                text: "Open"
                onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", folderRow.dir])
            }
        }
    }

    FolderField {
        label: "Recordings"
        key: "recordDir"
        dir: Recorder.recordDir
        defaultDir: Recorder.defaultRecordDir
        grouping: "Grouped by app"
    }

    FolderField {
        label: "Replays"
        key: "replayDir"
        dir: Recorder.replayDir
        defaultDir: Recorder.defaultReplayDir
        grouping: "Grouped by game"
    }

    // the folder dialog for whichever row asked; a cancel prints nothing
    Process {
        id: picker
        property string key: ""
        property string label: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim()
                if (path === "") return
                Settings.setRecordFolder(picker.key, path)
                page.say(picker.label + " go to " + path.replace(Quickshell.env("HOME"), "~"), false)
            }
        }
    }
    CommandProbe { id: zenityProbe; name: "zenity" }

    SettingsNote {
        text: "SUPER+R saves the replay, SUPER+SHIFT+S records"
    }
}
