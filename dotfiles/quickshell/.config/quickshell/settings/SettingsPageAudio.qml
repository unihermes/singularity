// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAudio.qml
//
// Output and input devices: which one is the default, its volume, mute -- and
// the per-application mixer for whatever is playing or recording right now,
// each app able to play on an output of its own.
//
// Straight onto Pipewire through Quickshell's service, the same one the bar's
// volume module reads, so the two always agree. Nothing to persist:
// wireplumber remembers the chosen default, each device's volume, and each
// application's volume and output itself. pactl fills in the two things the
// service doesn't say: which outputs have nothing plugged in, and which
// output each app is playing on (and moves it).

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
        objects: page.devices.concat(page.streams)
    }

    function nodeName(n) {
        return n ? (n.description || n.nickname || n.name) : ""
    }

    // A device's name without the words it shares with the card's other
    // devices: "Speaker", not "Alder Lake Smart Sound Technology Audio
    // Controller Speaker". A card with one device, a USB headset say, keeps
    // its whole name, which is the only thing telling it apart.
    function shortName(n) {
        var name = nodeName(n)
        var card = n ? (n.properties || {})["device.id"] : undefined
        if (card === undefined) return name
        var names = devices.filter(d => (d.properties || {})["device.id"] === card)
            .map(d => nodeName(d).split(" "))
        if (names.length < 2) return name
        var k = 0
        while (names.every(w => w.length > k + 1 && w[k] === names[0][k])) k++
        return name.split(" ").slice(k).join(" ")
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
        page.say(page.appName(stream) + " plays on " + page.plainName(sink), false)
    }

    // --- names -----------------------------------------------------------------

    // "HDMI / DisplayPort 1 Output [Dell S2417DG] (Stereo)" -> the screen's
    // name, and "DisplayPort 1" for where it is; with no screen named, the
    // port is the name
    function plainName(n) {
        var name = shortName(n)
        var m = name.match(/DisplayPort (\d+)[^\[]*(?:\[([^\]]+)\])?/)
        if (m) return m[2] || "DisplayPort " + m[1]
        return name.replace(/ \((Stereo|Mono|Analog Stereo|Digital Stereo)\)$/, "")
    }
    function where(n) {
        var m = shortName(n).match(/DisplayPort (\d+)[^\[]*\[/)
        if (m) return "DisplayPort " + m[1]
        var bus = (n && n.properties) ? n.properties["device.bus"] || "" : ""
        return bus === "bluetooth" ? "Bluetooth" : bus === "usb" ? "USB" : bus === "pci" ? "built in" : ""
    }
    function glyph(n) {
        if (!n) return ""
        if (!n.isSink) return "󰍬"
        var bus = n.properties ? n.properties["device.bus"] || "" : ""
        if (bus === "bluetooth") return "󰋋"
        return /DisplayPort|HDMI/.test(nodeName(n)) ? "󰍹" : "󰓃"
    }
    function levelText(n) {
        if (!n || !n.ready || !n.audio) return "--"
        return n.audio.muted ? "Muted" : Math.round(n.audio.volume * 100) + "%"
    }

    // --- shared rows -------------------------------------------------------------

    // The level of one node: the slider, grey while muted, and its readout.
    component Level: SettingsField {
        id: lvl
        property var node: null
        readonly property bool ready: node !== null && node.ready && node.audio !== null
        readonly property bool muted: ready && node.audio.muted

        label: "Volume"

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            Slider {
                width: Theme.fit(220)
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
    }

    component Mute: SettingsField {
        id: mute
        property var node: null
        property string mutedHint: "Silent; the level is kept"
        readonly property bool ready: node !== null && node.ready && node.audio !== null

        label: "Mute"
        hint: ready && node.audio.muted ? mutedHint : ""

        Switch {
            anchors.right: parent.right
            enabled: mute.ready
            checked: mute.ready && mute.node.audio.muted
            onToggled: mute.node.audio.muted = !mute.node.audio.muted
        }
    }

    // A device: its icon, plain name and where it is, its level, and the
    // Default tag; a click makes it the default.
    component DeviceRow: FlyoutRow {
        id: row
        required property var modelData
        property var current: null
        signal chosen(var node)
        readonly property bool isDefault: modelData === current

        leadingIcon: page.glyph(modelData)
        label: page.plainName(modelData)
        note: page.unplugged.indexOf(modelData.id) >= 0 ? "nothing plugged in" : page.where(modelData)
        badge: isDefault ? "Default" : ""
        highlighted: isDefault
        trailing: page.levelText(modelData)
        onActivated: if (!isDefault) chosen(modelData)
    }

    // keeps a list of devices apart from the default's level under it
    component Rule: Item {
        width: parent ? parent.width : 0
        height: Theme.spaceM * 2 + Theme.borderWidth
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.borderWidth
            color: Theme.stroke
        }
    }

    // --- output ------------------------------------------------------------------

    property bool showUnplugged: false
    readonly property var sinksShown: sinks.filter(n => showUnplugged || unplugged.indexOf(n.id) < 0
        || n === Pipewire.defaultAudioSink)
    readonly property int sinksHidden: sinks.length - sinksShown.length

    FlyoutHeading { text: "OUTPUT" }

    Repeater {
        model: page.sinksShown
        DeviceRow {
            current: Pipewire.defaultAudioSink
            onChosen: node => {
                Pipewire.preferredDefaultAudioSink = node
                page.say("Output: " + page.plainName(node), false)
            }
        }
    }

    FlyoutRow {
        visible: page.sinksHidden > 0 || (page.showUnplugged && page.unplugged.length > 0)
        label: page.sinksHidden > 0 ? "Show " + page.sinksHidden + " with nothing plugged in"
            : "Hide the ones with nothing plugged in"
        onActivated: page.showUnplugged = !page.showUnplugged
    }

    FlyoutRow {
        visible: page.sinks.length === 0
        enabled: false
        label: "No outputs found"
    }

    Rule { visible: !!Pipewire.defaultAudioSink }
    Level {
        visible: !!Pipewire.defaultAudioSink
        node: Pipewire.defaultAudioSink
        hint: page.plainName(Pipewire.defaultAudioSink)
    }
    Mute {
        visible: !!Pipewire.defaultAudioSink
        node: Pipewire.defaultAudioSink
    }

    // --- input -------------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "INPUT" }

    Repeater {
        model: page.sources
        DeviceRow {
            current: Pipewire.defaultAudioSource
            onChosen: node => {
                Pipewire.preferredDefaultAudioSource = node
                page.say("Input: " + page.plainName(node), false)
            }
        }
    }

    FlyoutRow {
        visible: page.sources.length === 0
        enabled: false
        label: "No inputs found"
    }

    Rule { visible: !!Pipewire.defaultAudioSource }
    Level {
        visible: !!Pipewire.defaultAudioSource
        node: Pipewire.defaultAudioSource
        hint: page.plainName(Pipewire.defaultAudioSource)
    }
    Mute {
        visible: !!Pipewire.defaultAudioSource
        node: Pipewire.defaultAudioSource
        mutedHint: "Nothing reaches the apps"
    }

    // --- per-application mixer -------------------------------------------
    //
    // Rows come and go with the streams themselves: an app appears when it
    // starts playing and is gone when it stops, which is why there is nothing
    // to persist here and no empty-but-remembered entries. Wireplumber keeps
    // each app's volume against its name for next time.

    property var openStream: null

    // An app: its icon, name and what it's playing, its level, and where it
    // plays when that isn't the default; it opens to its level, mute and
    // (for playback) Plays on.
    component AppBlock: Column {
        id: app
        required property var modelData
        property bool playback: true
        readonly property var n: modelData
        readonly property bool isOpen: page.openStream === n
        readonly property var target: page.playsOn[n.id] || null
        readonly property var sink: target ? page.sinks.find(s => s.id === target.sink) || null : null
        readonly property string iconName: n.properties ? n.properties["application.icon-name"] || "" : ""

        width: parent ? parent.width : 0

        FlyoutRow {
            leadingImage: app.iconName !== "" ? Quickshell.iconPath(app.iconName, true) : ""
            leadingIcon: app.iconName === "" ? (app.playback ? "󰓃" : "󰍬") : ""
            label: page.appName(app.n)
            note: page.streamDetail(app.n)
            highlighted: app.isOpen
            trailing: (app.playback && app.sink && app.sink !== Pipewire.defaultAudioSink
                    ? "on " + page.plainName(app.sink) + "    " : "")
                + page.levelText(app.n) + "  " + (app.isOpen ? "󰅀" : "󰅂")
            onActivated: page.openStream = app.isOpen ? null : app.n
        }

        SettingsIndent {
            visible: app.isOpen

            Level { node: app.n }
            Mute { node: app.n }

            SettingsField {
                visible: app.playback
                label: "Plays on"
                hint: !app.sink ? "" : app.sink === Pipewire.defaultAudioSink ? "The default output"
                    : "Not the default output"

                SettingsDropdown {
                    anchors.right: parent.right
                    width: Theme.fit(240)
                    model: page.sinks.filter(s => page.unplugged.indexOf(s.id) < 0)
                    current: app.sink
                    enabled: app.target !== null
                    placeholder: "…"
                    labelFor: s => page.plainName(s) + (s === Pipewire.defaultAudioSink ? "  default" : "")
                    onPicked: s => { if (s !== app.sink) page.moveTo(app.n, s) }
                }
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PLAYING" + (page.playing.length > 0 ? "  " + page.playing.length : "") }

    Repeater {
        model: page.playing
        AppBlock {}
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
        model: page.recording
        AppBlock { playback: false }
    }
}
