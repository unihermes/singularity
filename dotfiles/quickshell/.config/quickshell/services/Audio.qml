// Singularity - Quickshell
// ~/.config/quickshell/services/Audio.qml
//
// The default sink's volume and mute, bound live so the OSD and bar catch
// any change; plus the device and stream lists and names the volume flyout
// and Audio page share (tracked while those are open). The Game, Chat and
// Media channels (Channels) are in neither list.

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

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !Channels.isChannel(n))
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && !Channels.isChannel(n))
    // split by media.class (isSink reads backwards on streams)
    readonly property var playing: streams.filter(n => mediaClass(n) === "Stream/Output/Audio")
    readonly property var recording: streams.filter(n => mediaClass(n) === "Stream/Input/Audio")
    // playing streams grouped by app, so a browser's tabs share one row:
    // [{ name, nodes }] in the order each app first appears
    readonly property var playingApps: {
        var apps = []
        playing.forEach(n => {
            var name = appName(n)
            var app = apps.find(a => a.name === name)
            if (app) app.nodes.push(n)
            else apps.push({ name: name, nodes: [n] })
        })
        return apps
    }

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
    function appName(n) {
        if (!n) return ""
        var p = n.properties || {}
        return p["application.name"] || n.description || n.nickname || n.name
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
