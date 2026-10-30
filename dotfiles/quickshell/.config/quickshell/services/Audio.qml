// Singularity - Quickshell
// ~/.config/quickshell/services/Audio.qml
//
// The default sink's volume and mute, bound live so the OSD and bar catch
// any change; plus the device and stream lists and names the volume flyout
// and Audio page share (tracked while those are open). The Game, Chat and
// Media channels are in neither list (Channels has them).

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && sink.ready && !!sink.audio
    readonly property int percent: ready ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    function setVolume(pct) {
        if (!ready) return
        sink.audio.volume = Math.max(0, Math.min(1, pct / 100))
    }

    function toggleMute() {
        if (ready) sink.audio.muted = !sink.audio.muted
    }

    // --- every device and stream, for the flyout and the Settings page ------

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !isChannel(n))
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && !isChannel(n))
    // split by media.class (isSink reads backwards on streams)
    readonly property var playing: streams.filter(n => mediaClass(n) === "Stream/Output/Audio")
    readonly property var recording: streams.filter(n => mediaClass(n) === "Stream/Input/Audio")
    // streams grouped by app, so a browser's tabs share one row:
    // [{ name, nodes }] in the order each app first appears
    function byApp(streams) {
        var apps = []
        streams.forEach(n => {
            var name = appName(n)
            var app = apps.find(a => a.name === name)
            if (app) app.nodes.push(n)
            else apps.push({ name: name, nodes: [n] })
        })
        return apps
    }
    readonly property var playingApps: byApp(playing)
    readonly property var recordingApps: byApp(recording)

    // Asked of pactl, which knows the ports and sink-inputs Quickshell's
    // service doesn't, whenever refreshPorts() runs; again whenever a
    // device or stream comes or goes, and every few seconds while
    // something plays (an app can be moved from outside), while the volume
    // flyout or the Audio page is up (`watched`).
    // node ids of outputs whose every port is "not available": an HDMI or
    // DisplayPort output with no screen on it
    property var unplugged: []
    // stream node id -> { input, sink }: its sink-input index, and the node
    // id of the output or channel it plays on
    property var playsOn: ({})
    property bool flyoutWatching: false
    property bool pageWatching: false
    readonly property bool watched: flyoutWatching || pageWatching
    function refreshPorts() { portsProc.running = true }

    Process {
        id: portsProc
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
                root.unplugged = sinks.filter(s => s.ports && s.ports.length > 0
                    && s.ports.every(p => p.availability === "not available")).map(s => nodeOf[s.index])
                var on = {}
                inputs.forEach(i => {
                    var id = Number((i.properties || {})["object.id"])
                    if (!isNaN(id)) on[id] = { input: i.index, sink: nodeOf[i.sink] }
                })
                root.playsOn = on
            }
        }
    }
    Timer {
        id: portsSoon
        interval: 300
        onTriggered: root.refreshPorts()
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.watched && root.playing.length > 0
        onTriggered: root.refreshPorts()
    }
    onDevicesChanged: if (watched) portsSoon.restart()
    onStreamsChanged: if (watched) portsSoon.restart()
    onWatchedChanged: if (watched) refreshPorts()

    // Every stream of an app onto an output or channel at once. Wireplumber
    // remembers it, so the app plays there next time too.
    function moveApp(streams, sink) {
        var inputs = streams.map(n => playsOn[n.id]).filter(on => on).map(on => String(on.input))
        if (inputs.length === 0 || !sink) return false
        moveProc.command = ["sh", "-c", 't=$1; shift; for i; do pactl move-sink-input "$i" "$t"; done',
            "sh", sink.name].concat(inputs)
        moveProc.running = true
        return true
    }
    Process {
        id: moveProc
        onExited: portsSoon.restart()
    }

    // a Game, Chat or Media channel's sink or stream (pipewire.conf.d/channels.conf),
    // by its name: properties are only filled in once a node is bound
    function isChannel(n) {
        return !!n && n.name.startsWith("channel.")
    }

    function mediaClass(n) {
        return (n && n.properties) ? (n.properties["media.class"] || "") : ""
    }

    function nodeName(n) {
        return n ? (n.description || n.nickname || n.name) : ""
    }

    // a device's name minus the words it shares with its card's others
    // ("Speaker"); a single-device card keeps its whole name
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

    // "HDMI / DisplayPort 1 Output [Dell S2417DG] (Stereo)" -> the screen's
    // name, and "DisplayPort 1" for where it is; with no screen named, the
    // port is the name. A name that's only its profile once shortName has
    // taken the card's words ("Analog Stereo" on a headset whose mic is
    // "Mono") is the card's own nickname instead, and a trailing profile
    // goes ("P2418HZm Analog Stereo" -> "P2418HZm").
    readonly property var profileWords: /^(?:(?:Analog|Digital|Pro) )?(?:Stereo|Mono|Surround [\d.]+|Audio)$/
    function plainName(n) {
        var name = shortName(n)
        var m = name.match(/DisplayPort (\d+)[^\[]*(?:\[([^\]]+)\])?/)
        if (m) return m[2] || "DisplayPort " + m[1]
        if (profileWords.test(name)) name = n.nickname || (n.properties || {})["api.alsa.card.name"] || nodeName(n)
        return name.replace(/ \((Stereo|Mono|Analog Stereo|Digital Stereo)\)$/, "")
            .replace(/ (?:Analog|Digital) (?:Stereo|Mono)$/, "")
    }

    // headphones or a headset (Bluetooth, or an output that says so)
    function onHead(n) {
        if (!n || !n.properties) return false
        var p = n.properties
        return p["device.bus"] === "bluetooth" || /^(headset|headphone|hands-free)$/.test(p["device.form-factor"] || "")
    }

    function glyph(n) {
        if (!n) return ""
        if (!n.isSink) return "󰍬"
        if (onHead(n)) return "󰋋"
        return /DisplayPort|HDMI/.test(nodeName(n)) ? "󰍹" : "󰓃"
    }

    // An app's own name for itself, falling back to the node's. Pipewire fills
    // application.name for anything launched normally; a bare node (a script
    // piping into pw-play, the visualiser's capture) may only have a name.
    // Chromium's voice engine names itself, not the app (Discord's calls), so
    // that goes by the app's binary.
    function appName(n) {
        if (!n) return ""
        var p = n.properties || {}
        var name = p["application.name"] || ""
        if (/^(WEBRTC VoiceEngine|Chromium input)$/.test(name) && p["application.process.binary"])
            return Apps.nameForWindow(p["application.process.binary"], "")
        return name || n.description || n.nickname || n.name
    }

    // an app stream's icon path: its own icon name, else the app's found
    // by its binary (Floorp names none); "" for neither
    function appIcon(n) {
        var p = (n && n.properties) || {}
        return p["application.icon-name"] ? Quickshell.iconPath(p["application.icon-name"], true)
            : Apps.iconForClass(p["application.process.binary"] || p["application.name"] || "")
    }

    // Pipewire nodes are unbound by default: audio.volume / audio.muted stay
    // invalid until the node is tracked, so the sink has to be listed here
    // for anything to read or write it at all.
    PwObjectTracker {
        objects: [root.sink]
    }
}
