// Singularity - Quickshell
// ~/.config/quickshell/services/Audio.qml
//
// The default output sink's volume and mute, bound live so anything
// watching `percent` / `muted` (the OSD, the bar chip) catches a change
// from anywhere -- hardware keys, a slider, scroll-on-chip -- without each
// call site having to announce it. Below that, the device and stream lists
// and their names, which the volume flyout and the Audio page share; those
// track the nodes themselves (PwObjectTracker) while they're open.

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

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)
    // Streams split by Pipewire's own media.class rather than by isSink:
    // for a stream that flag reads as the direction of the node it feeds,
    // which is the opposite of how it reads on a device and easy to get
    // backwards. media.class says exactly which it is.
    readonly property var playing: streams.filter(n => mediaClass(n) === "Stream/Output/Audio")
    readonly property var recording: streams.filter(n => mediaClass(n) === "Stream/Input/Audio")

    // node ids of outputs whose every port is "not available": an HDMI or
    // DisplayPort output with no screen on it. Asked of pactl, which knows
    // the ports Quickshell's service doesn't, whenever refreshPorts() runs.
    property var unplugged: []
    function refreshPorts() { portsProc.running = true }

    Process {
        id: portsProc
        command: ["pactl", "-f", "json", "list", "sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                var sinks = []
                try { sinks = JSON.parse(text) } catch (e) { return }
                // pactl numbers sinks by object.serial; object.id is the node
                root.unplugged = sinks.filter(s => s.ports && s.ports.length > 0
                    && s.ports.every(p => p.availability === "not available"))
                    .map(s => Number((s.properties || {})["object.id"]))
            }
        }
    }

    function mediaClass(n) {
        return (n && n.properties) ? (n.properties["media.class"] || "") : ""
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

    // "HDMI / DisplayPort 1 Output [Dell S2417DG] (Stereo)" -> the screen's
    // name, and "DisplayPort 1" for where it is; with no screen named, the
    // port is the name
    function plainName(n) {
        var name = shortName(n)
        var m = name.match(/DisplayPort (\d+)[^\[]*(?:\[([^\]]+)\])?/)
        if (m) return m[2] || "DisplayPort " + m[1]
        return name.replace(/ \((Stereo|Mono|Analog Stereo|Digital Stereo)\)$/, "")
    }

    function glyph(n) {
        if (!n) return ""
        if (!n.isSink) return "󰍬"
        var bus = n.properties ? n.properties["device.bus"] || "" : ""
        if (bus === "bluetooth") return "󰋋"
        return /DisplayPort|HDMI/.test(nodeName(n)) ? "󰍹" : "󰓃"
    }

    // An app's own name for itself, falling back to the node's. Pipewire fills
    // application.name for anything launched normally; a bare node (a script
    // piping into pw-play, the visualiser's capture) may only have a name.
    function appName(n) {
        if (!n) return ""
        var p = n.properties || {}
        return p["application.name"] || n.description || n.nickname || n.name
    }

    // Pipewire nodes are unbound by default: audio.volume / audio.muted stay
    // invalid until the node is tracked, so the sink has to be listed here
    // for anything to read or write it at all.
    PwObjectTracker {
        objects: [root.sink]
    }
}
