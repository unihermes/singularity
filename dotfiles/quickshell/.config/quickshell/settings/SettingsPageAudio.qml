// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAudio.qml
//
// Output and input: the default device as a card with its level, the
// others under it (a click makes one the default; outputs with nothing
// plugged in are left out). Then the per-app mixer, a level on every app's
// row and the output it plays on beside it. Mute is the button before each
// level. Straight on Pipewire, as the bar is; wireplumber remembers
// everything. pactl finds unplugged outputs and moves streams.

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Audio"
    description: "Where sound goes, how loud, and each app's share."

    // ScriptModels, so a node coming or going doesn't rebuild every row
    readonly property var devices: Audio.devices
    readonly property var sinks: Audio.sinks
    readonly property var sources: Audio.sources
    readonly property var streams: Audio.streams
    readonly property var playing: Audio.playing
    readonly property var recording: Audio.recording

    // tracked, or volume/mute stay invalid
    PwObjectTracker {
        objects: page.devices.concat(page.streams)
    }

    // what an app is playing, as the row's hint; a path cut to its last segment
    function streamDetail(n) {
        if (!n) return ""
        var p = n.properties || {}
        var media = p["media.name"] || ""
        if (media === Audio.appName(n)) return ""
        var tail = media.substring(media.lastIndexOf("/") + 1)
        return tail !== "" ? tail : media
    }

    // --- what pactl knows ----------------------------------------------------

    // node ids of outputs whose every port is "not available": an HDMI or
    // DisplayPort output with no screen on it
    property var unplugged: []
    // stream node id -> { input, sink }: its sink-input index, and the node
    // id of the output it plays on
    property var playsOn: ({})

    Process {
        id: pactlProc
        command: ["sh", "-c", "pactl -f json list sinks; echo; pactl -f json list sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("\n")
                var sinks = [], inputs = []
                try { sinks = JSON.parse(parts[0] || "[]"); inputs = JSON.parse(parts[1] || "[]") } catch (e) { return }
                // pactl numbers sinks by object.serial, which only matches
                // the node id for devices there since boot
                var nodeOf = {}
                sinks.forEach(s => nodeOf[s.index] = Number((s.properties || {})["object.id"]))
                page.unplugged = sinks.filter(s => s.ports && s.ports.length > 0
                    && s.ports.every(p => p.availability === "not available")).map(s => nodeOf[s.index])
                var on = {}
                inputs.forEach(i => {
                    var id = Number((i.properties || {})["object.id"])
                    if (!isNaN(id)) on[id] = { input: i.index, sink: nodeOf[i.sink] }
                })
                page.playsOn = on
            }
        }
    }
    // asked again whenever a device or stream comes or goes
    Timer {
        id: pactlSoon
        interval: 300
        onTriggered: pactlProc.running = true
    }
    // and every few seconds while something plays, since an app can be
    // moved from outside (pavucontrol, the app itself)
    Timer {
        interval: 3000
        repeat: true
        running: page.streams.length > 0
        onTriggered: pactlProc.running = true
    }
    onDevicesChanged: pactlSoon.restart()
    onStreamsChanged: pactlSoon.restart()
    Component.onCompleted: pactlProc.running = true

    Process {
        id: moveProc
        onExited: pactlSoon.restart()
    }
    function moveTo(stream, sink) {
        var on = playsOn[stream.id]
        if (!on) return
        moveProc.command = ["pactl", "move-sink-input", String(on.input), sink.name]
        moveProc.running = true
        page.say(Audio.appName(stream) + " plays on " + Audio.plainName(sink), false)
    }

    // --- names -----------------------------------------------------------------

    function where(n) {
        var m = Audio.shortName(n).match(/DisplayPort (\d+)[^\[]*\[/)
        if (m) return "DisplayPort " + m[1]
        var bus = (n && n.properties) ? n.properties["device.bus"] || "" : ""
        return bus === "bluetooth" ? "Bluetooth" : bus === "usb" ? "USB" : bus === "pci" ? "Built in" : ""
    }
    function levelText(n) {
        if (!n || !n.ready || !n.audio) return "--"
        return n.audio.muted ? "Muted" : Math.round(n.audio.volume * 100) + "%"
    }

    // --- shared rows -------------------------------------------------------------

    // The level of one node: a mute button, the slider (grey while muted)
    // and its readout.
    component LevelControl: Row {
        id: lvl
        property var node: null
        property int sliderWidth: Theme.fit(220)
        readonly property bool ready: node !== null && node.ready && node.audio !== null
        readonly property bool muted: ready && node.audio.muted

        spacing: Theme.sp(10)

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            enabled: lvl.ready
            icon: lvl.muted ? "󰝟" : "󰕾"
            warn: lvl.muted
            onClicked: lvl.node.audio.muted = !lvl.node.audio.muted
        }
        Slider {
            width: lvl.sliderWidth
            anchors.verticalCenter: parent.verticalCenter
            value: lvl.ready ? lvl.node.audio.volume * 100 : 0
            fillColor: lvl.muted ? Theme.muted : Theme.meterFill
            onMoved: v => { if (lvl.ready) lvl.node.audio.volume = v / 100 }
        }
        Text {
            width: Theme.fs(52)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: page.levelText(lvl.node)
            color: lvl.muted ? Theme.subtext : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
    }

    component Level: SettingsField {
        property alias node: control.node
        label: "Volume"
        LevelControl { id: control; anchors.right: parent.right }
    }

    // The default device: its icon and name large, where it is.
    component DefaultCard: HeadCard {
        property var node: null
        glyph: node ? Audio.glyph(node) : ""
        title: node ? Audio.plainName(node) : ""
        lines: [[page.where(node), "Default"].filter(t => t).join("  ·  ")]
        rule: true
    }

    // A device: its icon, plain name and where it is, its level, and the
    // Default tag; a click makes it the default.
    component DeviceRow: FlyoutRow {
        id: row
        required property var modelData
        property var current: null
        signal chosen(var node)
        readonly property bool isDefault: modelData === current

        leadingIcon: Audio.glyph(modelData)
        label: Audio.plainName(modelData)
        note: page.unplugged.indexOf(modelData.id) >= 0 ? "nothing plugged in" : page.where(modelData)
        badge: isDefault ? "Default" : ""
        highlighted: isDefault
        trailing: page.levelText(modelData)
        onActivated: if (!isDefault) chosen(modelData)
    }

    // --- output ------------------------------------------------------------------

    // the others: the default is the card, and outputs with nothing
    // plugged in are left out
    readonly property var sinksShown: sinks.filter(n => n !== Pipewire.defaultAudioSink
        && unplugged.indexOf(n.id) < 0)

    FlyoutHeading { text: "OUTPUT" }

    DefaultCard { visible: !!Pipewire.defaultAudioSink; node: Pipewire.defaultAudioSink }
    Level { visible: !!Pipewire.defaultAudioSink; node: Pipewire.defaultAudioSink }

    Repeater {
        model: ScriptModel { values: page.sinksShown }
        DeviceRow {
            current: Pipewire.defaultAudioSink
            onChosen: node => {
                Pipewire.preferredDefaultAudioSink = node
                page.say("Output: " + Audio.plainName(node), false)
            }
        }
    }

    FlyoutRow {
        visible: page.sinks.length === 0
        enabled: false
        label: "No outputs found"
    }


    // --- input -------------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "INPUT" }

    DefaultCard { visible: !!Pipewire.defaultAudioSource; node: Pipewire.defaultAudioSource }
    Level { visible: !!Pipewire.defaultAudioSource; node: Pipewire.defaultAudioSource }

    Repeater {
        model: ScriptModel { values: page.sources.filter(n => n !== Pipewire.defaultAudioSource) }
        DeviceRow {
            current: Pipewire.defaultAudioSource
            onChosen: node => {
                Pipewire.preferredDefaultAudioSource = node
                page.say("Input: " + Audio.plainName(node), false)
            }
        }
    }

    FlyoutRow {
        visible: page.sources.length === 0
        enabled: false
        label: "No inputs found"
    }


    // --- per-application mixer -------------------------------------------
    // rows come and go with the streams

    // an app: icon, name over what's playing; on the right the output it
    // plays on, then its level
    component AppRow: Item {
        id: app
        required property var modelData
        property bool playback: true
        readonly property var n: modelData
        readonly property var target: page.playsOn[n.id] || null
        readonly property var sink: target ? page.sinks.find(s => s.id === target.sink) || null : null
        // the stream's own icon name, else the app's by its binary (Floorp
        // names none)
        readonly property var props: n.properties || {}
        readonly property string icon: props["application.icon-name"]
            ? Quickshell.iconPath(props["application.icon-name"], true)
            : Apps.iconForClass(props["application.process.binary"] || props["application.name"] || "")

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.fieldHeight, texts.implicitHeight + Theme.spaceM, right.height + Theme.spaceS)

        Image {
            id: appImage
            visible: app.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconCell
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: app.icon
        }
        Text {
            visible: app.icon === ""
            anchors.centerIn: appImage
            text: app.playback ? "󰓃" : "󰍬"
            color: Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        Column {
            id: texts
            anchors.left: appImage.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: right.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: Audio.appName(app.n)
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: page.streamDetail(app.n)
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }

        Row {
            id: right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceL

            SettingsDropdown {
                visible: app.playback
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(150)
                model: page.sinks.filter(s => page.unplugged.indexOf(s.id) < 0)
                current: app.sink
                enabled: app.target !== null
                placeholder: "…"
                labelFor: s => Audio.plainName(s) + (s === Pipewire.defaultAudioSink ? "  default" : "")
                onPicked: s => { if (s !== app.sink) page.moveTo(app.n, s) }
            }
            LevelControl {
                anchors.verticalCenter: parent.verticalCenter
                node: app.n
                sliderWidth: Theme.fit(150)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PLAYING" + (page.playing.length > 0 ? "  " + page.playing.length : "") }

    Repeater {
        model: ScriptModel { values: page.playing }
        AppRow {}
    }

    FlyoutRow {
        visible: page.playing.length === 0
        enabled: false
        label: "Nothing is playing"
    }

    Item { width: 1; height: Theme.spaceM; visible: page.recording.length > 0 }
    FlyoutHeading {
        text: "RECORDING" + "  " + page.recording.length
        visible: page.recording.length > 0
    }

    Repeater {
        model: ScriptModel { values: page.recording }
        AppRow { playback: false }
    }
}
