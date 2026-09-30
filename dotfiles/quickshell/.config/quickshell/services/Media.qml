// Singularity - Quickshell
// ~/.config/quickshell/services/Media.qml
//
// The MPRIS player the bar's media module follows: whichever is playing,
// else the last one that was, else the first one there is. One picked in
// the flyout wins over all of those until another player starts playing. Browsers expose
// a player per tab that has ever had media, so "the first one" alone would
// often pick a silent tab over the song that's actually on.

pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    property var lastPlaying: null
    property var picked: null

    readonly property var players: Mpris.players.values

    readonly property var player: {
        var ps = players
        if (picked && ps.indexOf(picked) !== -1) return picked
        for (var i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        if (lastPlaying && ps.indexOf(lastPlaying) !== -1) return lastPlaying
        return ps.length > 0 ? ps[0] : null
    }

    onPlayerChanged: if (player && player.isPlaying) lastPlaying = player

    Connections {
        target: root.player
        function onIsPlayingChanged() { if (root.player.isPlaying) root.lastPlaying = root.player }
    }

    function pick(p) {
        picked = p
        lastPlaying = p
    }

    // a player other than the picked one starting drops the pick
    Variants {
        model: root.players
        Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying && modelData !== root.picked) root.picked = null
            }
        }
    }

    // for the media keys; each is a no-op when the player can't do it
    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function play() { if (player && player.canPlay) player.play() }
    function pause() { if (player && player.canPause) player.pause() }
    function stop() { if (player && player.canControl) player.stop() }
    function next() { if (player && player.canGoNext) player.next() }
    function previous() { if (player && player.canGoPrevious) player.previous() }

    function fmtTime(sec) {
        if (!(sec >= 0)) return "--:--"
        var m = Math.floor(sec / 60), s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
