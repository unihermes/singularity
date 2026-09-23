// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAudio.qml
//
// Output and input devices: which one is the default, its volume, mute -- and
// the per-application mixer for whatever is playing or recording right now.
//
// Straight onto Pipewire through Quickshell's service, the same one the bar's
// volume module reads, so the two always agree. Nothing to persist:
// wireplumber remembers the chosen default, each device's volume, and each
// application's volume itself.

import Quickshell.Services.Pipewire
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Audio"
    description: "Default output and input, their levels, and the volume of each app using them. Wireplumber remembers these across restarts."

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)

    // Streams split by Pipewire's own media.class rather than by isSink:
    // for a stream that flag reads as the direction of the node it feeds,
    // which is the opposite of how it reads on a device and easy to get
    // backwards. media.class says exactly which it is.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    readonly property var playing: streams.filter(n => page.mediaClass(n) === "Stream/Output/Audio")
    readonly property var recording: streams.filter(n => page.mediaClass(n) === "Stream/Input/Audio")

    function mediaClass(n) {
        return (n && n.properties) ? (n.properties["media.class"] || "") : ""
    }

    // audio.volume / audio.muted stay invalid until a node is tracked, and
    // that goes for the streams too -- without them here every app row would
    // sit at 0% and refuse to move.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].concat(page.streams)
    }

    function nodeName(n) {
        return n ? (n.description || n.nickname || n.name) : ""
    }

    // An app's own name for itself, falling back to the node's. Pipewire fills
    // application.name for anything launched normally; a bare node (a script
    // piping into pw-play, the visualiser's capture) may only have a name.
    function appName(n) {
        if (!n) return ""
        var p = n.properties || {}
        return p["application.name"] || n.description || n.nickname || n.name
    }

    // What it's playing, when that's something other than the app's own name:
    // a track title, a file, a tab. Shown as the row's hint.
    //
    // A player handed a file often reports the whole path, which is several
    // wrapped lines of a row that only needs to say which file -- so a value
    // that looks like a path is cut down to its last segment.
    function streamDetail(n) {
        if (!n) return ""
        var p = n.properties || {}
        var media = p["media.name"] || ""
        if (media === page.appName(n)) return ""
        var tail = media.substring(media.lastIndexOf("/") + 1)
        return tail !== "" ? tail : media
    }

    // Shared by the two device levels and every app row: the same slider,
    // readout and mute, differing only in what they call themselves.
    component Level: SettingsField {
        id: lvl
        property var node: null
        // the device rows are always "Volume"; an app row names the app
        property string title: "Volume"
        property string subtitle: ""
        // What stands in when there is no subtitle. A device row says which
        // device it is; an app row says nothing, because its title is already
        // the app's name and the node name would only repeat it.
        property string subtitleFallback: ready ? page.nodeName(node) : "No device"
        readonly property bool ready: node !== null && node.ready && node.audio !== null

        label: title
        hint: subtitle !== "" ? subtitle : subtitleFallback

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            Slider {
                width: Theme.fs(220)
                anchors.verticalCenter: parent.verticalCenter
                value: lvl.ready ? lvl.node.audio.volume * 100 : 0
                onMoved: v => { if (lvl.ready) lvl.node.audio.volume = v / 100 }
            }
            Text {
                width: Theme.fs(40)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: lvl.ready ? Math.round(lvl.node.audio.volume * 100) + "%" : "--"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            FlyoutChip {
                anchors.verticalCenter: parent.verticalCenter
                text: lvl.ready && lvl.node.audio.muted ? "Muted" : "Mute"
                selected: lvl.ready && lvl.node.audio.muted
                enabled: lvl.ready
                onClicked: lvl.node.audio.muted = !lvl.node.audio.muted
            }
        }
    }

    component DeviceList: Column {
        id: dl
        property var nodes: []
        property var current: null
        signal picked(var node)

        width: parent.width
        spacing: Theme.spaceXs

        Repeater {
            model: dl.nodes
            FlyoutRow {
                required property var modelData
                label: page.nodeName(modelData)
                highlighted: dl.current === modelData
                trailing: highlighted ? "󰄬" : ""
                onActivated: if (!highlighted) dl.picked(modelData)
            }
        }

        Text {
            visible: dl.nodes.length === 0
            text: "None found"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
    }

    FlyoutHeading { text: "OUTPUT" }

    Level { node: Pipewire.defaultAudioSink }

    DeviceList {
        nodes: page.sinks
        current: Pipewire.defaultAudioSink
        onPicked: node => {
            Pipewire.preferredDefaultAudioSink = node
            page.say("Output: " + page.nodeName(node), false)
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "INPUT" }

    Level { node: Pipewire.defaultAudioSource }

    DeviceList {
        nodes: page.sources
        current: Pipewire.defaultAudioSource
        onPicked: node => {
            Pipewire.preferredDefaultAudioSource = node
            page.say("Input: " + page.nodeName(node), false)
        }
    }

    // --- per-application mixer -------------------------------------------
    //
    // Rows come and go with the streams themselves: an app appears when it
    // starts playing and is gone when it stops, which is why there is nothing
    // to persist here and no empty-but-remembered entries. Wireplumber keeps
    // each app's volume against its name for next time.

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PLAYING" }

    Repeater {
        model: page.playing
        Level {
            required property var modelData
            node: modelData
            title: page.appName(modelData)
            subtitle: page.streamDetail(modelData)
            subtitleFallback: ""
        }
    }

    Text {
        visible: page.playing.length === 0
        text: "Nothing is playing"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Item { width: 1; height: Theme.spaceM; visible: page.recording.length > 0 }
    FlyoutHeading {
        text: "RECORDING"
        visible: page.recording.length > 0
    }

    Repeater {
        model: page.recording
        Level {
            required property var modelData
            node: modelData
            title: page.appName(modelData)
            subtitle: page.streamDetail(modelData)
            subtitleFallback: ""
        }
    }
}
