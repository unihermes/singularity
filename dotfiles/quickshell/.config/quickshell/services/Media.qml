// Singularity - Quickshell
// ~/.config/quickshell/services/Media.qml
//
// The MPRIS player the bar's media module follows: whichever is playing,
// else the last one that was, else the first one there is. One picked in
// the flyout wins over all of those until another player starts playing. Browsers expose
// a player per tab that has ever had media, so "the first one" alone would
// often pick a silent tab over the song that's actually on. The media keys
// skip browsers: they drive the player the module follows when that isn't
// one, else the first player that isn't, so a key never pauses a video.

pragma Singleton

import Quickshell
import Quickshell.Io
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

    // a browser's tab, by its desktop entry or name
    function isBrowser(p) {
        return /floorp|firefox|zen|librewolf|chrom|brave|vivaldi/
            .test(String(p.desktopEntry || p.identity).toLowerCase())
    }

    readonly property var keyPlayer: {
        if (player && !isBrowser(player)) return player
        var ps = players.filter(p => !isBrowser(p))
        for (var i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
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

    // a player other than the picked one starting drops the pick; each
    // length a player reports goes in knownLength
    Variants {
        model: root.players
        Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying && modelData !== root.picked) root.picked = null
            }
            function onMetadataChanged() {
                var len = root.reportedLength(modelData)
                if (len <= 0) return
                var known = Object.assign({}, root.knownLength)
                known[modelData.dbusName] = { track: root.trackKey(modelData), length: len }
                root.knownLength = known
            }
            Component.onCompleted: onMetadataChanged()
        }
    }

    // for the media keys; each is a no-op when the player can't do it
    function toggle() { var p = keyPlayer; if (p && p.canTogglePlaying) p.togglePlaying() }
    function play() { var p = keyPlayer; if (p && p.canPlay) p.play() }
    function pause() { var p = keyPlayer; if (p && p.canPause) p.pause() }
    function stop() { var p = keyPlayer; if (p && p.canControl) p.stop() }
    function next() { var p = keyPlayer; if (p && p.canGoNext) p.next() }
    function previous() { var p = keyPlayer; if (p && p.canGoPrevious) p.previous() }

    // a player's art, best first. A browser's own is often missing or still
    // the last video's, so first what the page itself names: a YouTube
    // video's thumbnails by its id (the full-size one, which not every
    // video has, then the small one), else the page's og:image (pageArt).
    // Then whatever the player gives.
    function artUrls(p) {
        if (!p) return []
        var out = []
        var url = String(p.metadata["xesam:url"] || "")
        var m = /youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/)([\w-]{11})|youtu\.be\/([\w-]{11})/.exec(url)
        if (m) {
            var id = m[1] || m[2]
            out.push("https://i.ytimg.com/vi/" + id + "/maxresdefault.jpg", "https://i.ytimg.com/vi/" + id + "/mqdefault.jpg")
        } else if (pageArt[url]) out.push(pageArt[url])
        if (p.trackArtUrl) out.push(p.trackArtUrl)
        return out
    }

    // page URL -> the picture it names for sharing, "" for none; fetched
    // for the followed player's page when it's a browser's and not YouTube
    property var pageArt: ({})
    readonly property string pageUrl: {
        var url = player && isBrowser(player) ? String(player.metadata["xesam:url"] || "") : ""
        return /^https?:\/\//.test(url) && !/youtube\.com\/|youtu\.be\//.test(url) ? url : ""
    }
    onPageUrlChanged: fetchPageArt()
    function fetchPageArt() {
        if (pageUrl === "" || pageUrl in pageArt || pageFetch.running) return
        pageFetch.url = pageUrl
        pageFetch.running = true
    }

    Process {
        id: pageFetch
        property string url: ""
        command: [Quickshell.shellDir + "/scripts/page-art.py", url]
        stdout: StdioCollector {
            onStreamFinished: {
                var art = Object.assign({}, root.pageArt)
                art[pageFetch.url] = text.trim()
                root.pageArt = art
            }
        }
        // the page may have changed while this one was out
        onRunningChanged: if (!running) Qt.callLater(root.fetchPageArt)
    }

    // a player's track length in seconds, 0 when unknown. Read from the
    // metadata when the player's own length isn't there (yet): browsers
    // send mpris:length after the rest of a new track's metadata
    function reportedLength(p) {
        if (!p) return 0
        if (p.lengthSupported && p.length > 0) return p.length
        var us = Number((p.metadata || {})["mpris:length"] || 0)
        return us > 0 ? us / 1000000 : 0
    }

    // dbusName -> { track, length } of the last length each player
    // reported. Firefox drops mpris:length a second into a YouTube video,
    // so the track keeps the one it had. A track is its URL and title, not
    // uniqueId: Firefox's passing metadata changes count as new tracks
    property var knownLength: ({})
    function trackKey(p) {
        var md = p.metadata || {}
        return String(md["xesam:url"] || "") + "\n" + String(md["xesam:title"] || "")
    }
    function lengthOf(p) {
        var len = reportedLength(p)
        if (len > 0 || !p) return len
        var k = knownLength[p.dbusName]
        return k && k.track === trackKey(p) ? k.length : 0
    }

    // Firefox and its forks (all on an org.mpris.MediaPlayer2.firefox name)
    // only take a video's length and position from the page on a play,
    // pause or seek, so a YouTube video whose stream loads after it starts
    // goes without both (or loses them a second in, its position falling
    // back to 0). A pause and play back to back fills them in: sent once
    // per track to the followed player when it's been playing a moment
    // with no length reported.
    property string nudgedTrack: ""
    Timer {
        interval: 2000
        running: !!root.player && root.player.isPlaying && root.player.canPause
            && root.player.dbusName.startsWith("org.mpris.MediaPlayer2.firefox")
            && root.reportedLength(root.player) === 0 && root.trackKey(root.player) !== root.nudgedTrack
        onTriggered: {
            root.nudgedTrack = root.trackKey(root.player)
            nudge.command = ["sh", "-c", 'for m in Pause Play; do busctl --user call "$1" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player $m; done',
                "sh", root.player.dbusName]
            nudge.running = true
        }
    }
    Process { id: nudge }

    function fmtTime(sec) {
        if (!(sec >= 0)) return "--:--"
        var m = Math.floor(sec / 60), s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
