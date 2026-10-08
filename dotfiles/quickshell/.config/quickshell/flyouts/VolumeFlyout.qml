// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VolumeFlyout.qml
//
// Sound in three tabs: Output (which device plays, its level and mute),
// Input (the microphone's), and Apps (each app playing right now, with a
// level of its own). Outputs with nothing plugged in are left out. The
// Audio page in Settings has the rest: those outputs, recording apps, and
// moving an app to another output.

import "../services"
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

FlyoutPanel {
    id: volumeFlyout
    flyout: "volume"
    menuWidth: Theme.fit(260)

    property string tab: "output"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: !!source && source.ready && !!source.audio
    readonly property int micPercent: sourceReady ? Math.round(source.audio.volume * 100) : 0
    readonly property bool micMuted: sourceReady && source.audio.muted

    // outputs with nothing plugged in stay out of the list, unless chosen
    readonly property var sinksShown: Audio.sinks.filter(n => Audio.unplugged.indexOf(n.id) < 0 || n === sink)
    onOpenChanged: if (open) Audio.refreshPorts()

    // audio.volume / audio.muted stay invalid until a node is tracked
    PwObjectTracker {
        objects: volumeFlyout.open ? Audio.devices.concat(Audio.streams) : []
    }

    FlyoutSegmented {
        model: [
            { value: "output", text: "Output" },
            { value: "input", text: "Input" },
            { value: "apps", text: Audio.playing.length > 0 ? "Apps " + Audio.playing.length : "Apps" },
        ]
        current: volumeFlyout.tab
        onPicked: v => volumeFlyout.tab = v
    }

    // --- output ---------------------------------------------------------------

    FlyoutHeading {
        visible: volumeFlyout.tab === "output" && volumeFlyout.sinksShown.length > 1
        text: "DEVICE"
    }

    Repeater {
        model: ScriptModel { values: volumeFlyout.tab === "output" && volumeFlyout.sinksShown.length > 1 ? volumeFlyout.sinksShown : [] }
        FlyoutRow {
            required property var modelData
            leadingIcon: Audio.glyph(modelData)
            label: Audio.plainName(modelData)
            highlighted: modelData === volumeFlyout.sink
            onActivated: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    FlyoutHeading {
        visible: volumeFlyout.tab === "output"
        text: "VOLUME  " + (Audio.muted ? "MUTED" : Audio.percent + "%")
    }

    // muted keeps the level on show, dimmed, as the volume toast does
    Slider {
        visible: volumeFlyout.tab === "output"
        width: parent.width
        value: Audio.percent
        opacity: Audio.muted ? 0.5 : 1
        onMoved: v => Audio.setVolume(v)
    }

    FlyoutAction {
        visible: volumeFlyout.tab === "output"
        icon: Audio.muted ? "󰖁" : "󰕾"
        label: "Mute"
        checked: Audio.muted
        onActivated: Audio.toggleMute()
    }

    // --- input ----------------------------------------------------------------

    FlyoutHeading {
        visible: volumeFlyout.tab === "input" && Audio.sources.length > 1
        text: "DEVICE"
    }

    Repeater {
        model: ScriptModel { values: volumeFlyout.tab === "input" && Audio.sources.length > 1 ? Audio.sources : [] }
        FlyoutRow {
            required property var modelData
            leadingIcon: Audio.glyph(modelData)
            label: Audio.plainName(modelData)
            highlighted: modelData === volumeFlyout.source
            onActivated: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    FlyoutHeading {
        visible: volumeFlyout.tab === "input" && volumeFlyout.sourceReady
        text: "LEVEL  " + (volumeFlyout.micMuted ? "MUTED" : volumeFlyout.micPercent + "%")
    }

    Slider {
        visible: volumeFlyout.tab === "input" && volumeFlyout.sourceReady
        width: parent.width
        value: volumeFlyout.micPercent
        opacity: volumeFlyout.micMuted ? 0.5 : 1
        onMoved: v => volumeFlyout.source.audio.volume = v / 100
    }

    FlyoutAction {
        visible: volumeFlyout.tab === "input" && volumeFlyout.sourceReady
        icon: volumeFlyout.micMuted ? "󰍭" : "󰍬"
        label: "Mute microphone"
        checked: volumeFlyout.micMuted
        onActivated: volumeFlyout.source.audio.muted = !volumeFlyout.micMuted
    }

    FlyoutRow {
        visible: volumeFlyout.tab === "input" && Audio.sources.length === 0
        enabled: false
        label: "No microphone found"
    }

    // --- apps -----------------------------------------------------------------

    Repeater {
        model: ScriptModel { values: volumeFlyout.tab === "apps" ? Audio.playing : [] }

        Column {
            id: app
            required property var modelData
            readonly property var n: modelData
            readonly property bool ready: n.ready && !!n.audio
            readonly property bool muted: ready && n.audio.muted
            readonly property string iconName: n.properties ? n.properties["application.icon-name"] || "" : ""
            width: parent ? parent.width : 0

            // the app's name; a click mutes it
            FlyoutRow {
                leadingImage: app.iconName !== "" ? Quickshell.iconPath(app.iconName, true) : ""
                leadingIcon: app.iconName === "" ? "󰓃" : ""
                label: Audio.appName(app.n)
                trailing: !app.ready ? "" : app.muted ? "Muted" : Math.round(app.n.audio.volume * 100) + "%"
                trailingIsValue: true
                onActivated: if (app.ready) app.n.audio.muted = !app.muted
            }

            Slider {
                width: parent.width
                value: app.ready ? Math.round(app.n.audio.volume * 100) : 0
                opacity: app.muted ? 0.5 : 1
                onMoved: v => { if (app.ready) app.n.audio.volume = v / 100 }
            }
        }
    }

    FlyoutRow {
        visible: volumeFlyout.tab === "apps" && Audio.playing.length === 0
        enabled: false
        label: "Nothing is playing"
    }

    FlyoutDivider {}

    FlyoutRow {
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("audio")
    }
}
