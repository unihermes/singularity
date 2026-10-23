// Singularity - Quickshell
// ~/.config/quickshell/services/Channels.qml
//
// Game, Chat and Media: the outputs pipewire.conf.d/channels.conf makes,
// each mixing into the real output. New playback lands on Media, games' on
// Game. Each has an EQ, its gains set live from Settings. A headset's ChatMix dial (read with headsetcontrol) sets Game and
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

    // --- EQ ----------------------------------------------------------------------

    // Each channel's bands, as channels.conf builds them: the filter's node
    // name, the gain it starts at (dB), and what it's for.
    readonly property var eq: ({
        game: [
            { band: "rumble", label: "Rumble",  hint: "Under 100 Hz: explosions, engines", gain: -4 },
            { band: "cues",   label: "Cues",    hint: "2.8 kHz: footsteps, reloads", gain: 3 },
            { band: "detail", label: "Detail",  hint: "6 kHz: where a sound is", gain: 1.5 }
        ],
        chat: [
            { band: "box",    label: "Boxiness", hint: "250 Hz: cheap headset mics", gain: -3 },
            { band: "words",  label: "Words",    hint: "3 kHz: how clear speech is", gain: 3 },
            { band: "ess",    label: "Esses",    hint: "7.5 kHz: harsh s sounds", gain: -2 }
        ],
        media: [
            { band: "bass",   label: "Bass",   hint: "Under 105 Hz", gain: 0 },
            { band: "mids",   label: "Mids",   hint: "Around 1 kHz", gain: 0 },
            { band: "treble", label: "Treble", hint: "Over 8 kHz", gain: 0 }
        ]
    })
    readonly property real eqRange: 12

    function eqGain(ch, b) {
        var v = (Settings.channelEq[ch] || {})[b.band]
        return typeof v === "number" ? v : b.gain
    }
    function eqMoved(ch) {
        return (eq[ch] || []).some(b => eqGain(ch, b) !== b.gain)
    }
    // only what's off its default is saved
    function setEq(ch, band, v) {
        var all = Object.assign({}, Settings.channelEq)
        var mine = Object.assign({}, all[ch] || {})
        var b = eq[ch].find(x => x.band === band)
        if (v === b.gain) delete mine[band]
        else mine[band] = v
        if (Object.keys(mine).length > 0) all[ch] = mine
        else delete all[ch]
        Settings.setChannelEq(all)
    }
    function resetEq(ch) {
        var all = Object.assign({}, Settings.channelEq)
        delete all[ch]
        Settings.setChannelEq(all)
    }

    // Every channel's gains onto its filter, and `pre` down by the highest
    // boost; again whenever the channels come back (pipewire restarted).
    property bool eqAgain: false
    function applyEq() {
        if (eqProc.running) { eqAgain = true; return }
        var cmds = sinks.filter(n => eq[key(n)]).map(n => {
            var ch = key(n)
            var gains = eq[ch].map(b => eqGain(ch, b))
            var pre = Math.pow(10, -Math.max(0, ...gains) / 20)
            var params = eq[ch].map((b, i) => '"' + b.band + ':Gain" ' + gains[i])
                .concat(['"pre:Gain 1" ' + pre.toFixed(4)])
            return "pw-cli s " + n.id + " Props '{ params = [ " + params.join(" ") + " ] }' >/dev/null"
        })
        if (cmds.length === 0) return
        eqProc.command = ["sh", "-c", cmds.join("; ")]
        eqProc.running = true
    }
    Process {
        id: eqProc
        onExited: if (root.eqAgain) { root.eqAgain = false; root.applyEq() }
    }
    onSinksChanged: Qt.callLater(applyEq)
    Connections {
        target: Settings
        function onChannelEqChanged() { root.applyEq() }
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
