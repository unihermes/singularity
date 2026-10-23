// Singularity - Quickshell
// ~/.config/quickshell/services/Channels.qml
//
// Game, Chat and Media: the outputs pipewire.conf.d/channels.conf makes,
// each mixing into the real output. New playback lands on Chat, games' on
// Game. A headset's ChatMix dial (read with headsetcontrol) sets Game and
// Chat against each other on the channels' own streams into the output, so
// each channel's level stays the user's. The same tool says whether the
// headset itself is on (headset), for the bar's volume icon.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property var order: ["game", "chat", "media"]

    function key(n) {
        var m = n ? n.name.match(/^channel\.(\w+)/) : null
        return m ? m[1] : ""
    }

    // the channels' sinks, Game first; and their streams into the output
    readonly property var sinks: Pipewire.nodes.values.filter(n => key(n) !== "" && !n.isStream)
        .sort((a, b) => order.indexOf(key(a)) - order.indexOf(key(b)))
    readonly property var outs: Pipewire.nodes.values.filter(n => key(n) !== "" && n.isStream)

    // --- ChatMix ---------------------------------------------------------------

    // the dial, 0 (all Game) to 128 (all Chat) with 64 even; -1 with none
    property int chatmix: -1
    // the dial turned, as against found or lost: what the toasts show
    signal turned()
    // -1 (all Game) .. 1 (all Chat)
    readonly property real balance: chatmix < 0 ? 0 : (chatmix - 64) / 64
    // the side it leans to, a hair either way of the middle counting as even
    readonly property string side: Math.abs(balance) < 0.04 ? "" : balance < 0 ? "game" : "chat"
    readonly property string sideText: side === "game" ? "Game" : side === "chat" ? "Chat" : "Even"
    readonly property string sideIcon: side === "chat" ? "󰭹" : side === "game" ? "󰊴" : "󰓃"
    // "Game 100 · Chat 40": each one's share of its level
    readonly property string mixText: "Game " + Math.round(gameMix * 100) + " · Chat " + Math.round(chatMix * 100)
    readonly property real gameMix: chatmix > 64 ? (128 - chatmix) / 64 : 1
    readonly property real chatMix: chatmix >= 0 && chatmix < 64 ? chatmix / 64 : 1

    function mix(n) {
        var k = key(n)
        return k === "game" ? gameMix : k === "chat" ? chatMix : 1
    }
    // later, never inside the Pipewire callback that changed a node
    function apply() { Qt.callLater(applyNow) }
    function applyNow() {
        outs.forEach(n => {
            if (n.ready && n.audio && Math.abs(n.audio.volume - mix(n)) > 0.005)
                n.audio.volume = mix(n)
        })
    }
    onGameMixChanged: apply()
    onChatMixChanged: apply()

    // audio.volume stays invalid until a node is tracked, and set once ready
    PwObjectTracker {
        objects: root.outs
    }
    Instantiator {
        model: ScriptModel { values: root.outs }
        Connections {
            required property var modelData
            target: modelData
            function onReadyChanged() { root.apply() }
        }
    }

    CommandProbe { id: probe; name: "headsetcontrol" }

    // one read for the dial and the headset's power: quick for a while after
    // the dial turns, slower while the headset is on, slow while it's off
    // (its dial can't move) or nothing answers
    property bool dialBusy: false
    Timer {
        id: dialSettle
        interval: 10000
        onTriggered: root.dialBusy = false
    }
    onTurned: { dialBusy = true; dialSettle.restart() }

    Timer {
        running: probe.found
        repeat: true
        triggeredOnStart: true
        interval: root.chatmix < 0 || root.headset !== "on" ? 3000 : root.dialBusy ? 300 : 1000
        onTriggered: if (!read.running) read.running = true
    }

    // --- The headset itself ----------------------------------------------------

    // from its battery read: "on", "off" (the dongle answers, the headset
    // is off) or "" with no headset found
    property string headset: ""

    Process {
        id: read
        command: ["headsetcontrol", "-b", "-m", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                // a read error or timeout keeps the headset's last state
                var devices = null
                try { devices = JSON.parse(text).devices || [] } catch (e) {}
                var bat = devices ? devices.find(d => d.battery) : null
                var st = bat ? bat.battery.status : ""
                root.headset = /^BATTERY_(AVAILABLE|CHARGING)$/.test(st) ? "on"
                    : st === "BATTERY_UNAVAILABLE" ? "off" : bat || !devices ? root.headset : ""
                // the dial only counts with the channels to set
                var dial = devices && root.sinks.length > 0
                    ? devices.find(d => typeof d.chatmix === "number") : null
                var level = dial ? dial.chatmix : -1
                var was = root.chatmix
                root.chatmix = level
                if (was >= 0 && level >= 0 && was !== level) root.turned()
            }
        }
    }
}
