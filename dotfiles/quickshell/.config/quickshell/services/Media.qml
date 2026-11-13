// The MPRIS player the bar's media module follows: whichever is playing,
// else the last one that was, else the first one there is. One picked in
// the flyout wins over all of those until another player starts playing. Browsers expose
// a player per tab that has ever had media, so "the first one" alone would
// often pick a silent tab over the song that's actually on. The media keys
// skip browsers: they drive the player the module follows when that isn't
// one, else the first player that isn't, so a key never pauses a video.
// A browser's tabs are sources of their own (`sources`), from its
// Pipewire streams, one per tab; the sound settings still group them as
// one app (Audio.byApp).

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
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
        for (var j = 0; j < ps.length; j++) if (tabsOf(ps[j]).some(t => t.running)) return ps[j]
        if (lastPlaying && ps.indexOf(lastPlaying) !== -1) return lastPlaying
        return ps.length > 0 ? ps[0] : null
    }

    function prunePlayers() {
        var live = new Set(players.map(p => p.dbusName))
        var kept = Object.create(null)
        for (var name of Object.keys(knownLength || {}))
            if (live.has(name)) kept[name] = knownLength[name]
        knownLength = kept
        if (picked && players.indexOf(picked) === -1) picked = null
        if (lastPlaying && players.indexOf(lastPlaying) === -1) lastPlaying = null
    }
    onPlayersChanged: prunePlayers()

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
        pickedTab = -1
        lastPlaying = p
    }
    // a source from `sources`: a player, or one of a browser's tabs
    function pickSource(src) {
        pick(src.player)
        pickedTab = src.tab
    }

    // --- a browser's tabs ---------------------------------------------------
    // A browser has one MPRIS player for all its tabs, left on the last one
    // started, but an output stream per tab, named after it (media.name)
    // and running while it sounds. Each track the player shows is bound to
    // the tab that started it (tabTrack, by stream id), so a tab still
    // playing after the player moved on to another, now paused, shows its
    // own title and art (heard). Tabs the player can't reach take no
    // transport (controllable).
    readonly property var outStreams: Pipewire.nodes.values.filter(n =>
        n.type === PwNodeType.AudioOutStream && !String(n.name).startsWith("channel."))
    PwObjectTracker { objects: root.outStreams }
    // the streams' links out, not the visualizer's taps; one active is the
    // stream running
    readonly property var outLinks: Pipewire.linkGroups.values.filter(g => g.source && g.target
        && g.source.type === PwNodeType.AudioOutStream && g.target.name !== "singularity-viz")
    PwObjectTracker { objects: root.outLinks }
    readonly property var runningIds: {
        var ids = []
        outLinks.forEach(g => { if (g.state === PwLinkState.Active && ids.indexOf(g.source.id) === -1) ids.push(g.source.id) })
        return ids
    }
    // stream id -> when it last started running
    property var startedAt: ({})
    property var wasRunning: []
    onRunningIdsChanged: {
        var now = Date.now(), fresh = false
        runningIds.forEach(id => {
            if (wasRunning.indexOf(id) === -1) { startedAt[id] = now; fresh = true }
        })
        wasRunning = runningIds
        // a tab starting drops a picked tab, like a player starting
        if (fresh) pickedTab = -1
    }

    // Forget vanished streams and positions no longer reachable from recent/live tracks.
    function pruneTracks() {
        var alive = new Set(outStreams.map(n => String(n.id)))
        var bound = Object.create(null)
        for (var id of Object.keys(tabTrack || {}))
            if (alive.has(id)) bound[id] = tabTrack[id]
        tabTrack = bound
        for (var id of Object.keys(startedAt || {}))
            if (!alive.has(id)) delete startedAt[id]
        var titles = new Set((seenTracks || []).map(t => t.title))
        Object.values(bound).forEach(t => titles.add(t.title))
        for (var title of Object.keys(trackPos || {}))
            if (!titles.has(title)) delete trackPos[title]
    }
    onOutStreamsChanged: pruneTracks()

    // a player's tabs: [{ id, name, running }], none for a non-browser
    function tabsOf(p) {
        if (!p || !isBrowser(p)) return []
        var app = String(p.desktopEntry || p.identity).toLowerCase()
        return outStreams.filter(n => {
            var pr = n.properties || {}
            return [pr["application.process.binary"], pr["application.name"], n.name]
                .some(v => v && String(v).toLowerCase().indexOf(app) !== -1)
        }).map(n => ({ id: n.id, name: String((n.properties || {})["media.name"] || ""),
            running: runningIds.indexOf(n.id) !== -1 }))
    }

    // stream id -> the track bound to it; mprisTab, the tab the player's
    // own track is bound to (-1 for none known)
    property var tabTrack: ({})
    property int mprisTab: -1
    // bound a moment after the player's track or state changes, once the
    // tab that started it is running: the tab named after the track, else
    // the one that just started, else the same tab moving on, else the one
    // tab running
    function bindTrack(p) {
        if (!p || !isBrowser(p) || p !== player && !p.isPlaying) return
        var t = trackOf(p)
        if (t.title === "") return
        var tabs = tabsOf(p), title = t.title.toLowerCase(), now = Date.now()
        var running = tabs.filter(x => x.running)
        var tab = tabs.find(x => x.name.toLowerCase().indexOf(title) !== -1)
            || running.filter(x => now - (startedAt[x.id] || 0) < 4000)
                .sort((a, b) => startedAt[b.id] - startedAt[a.id])[0]
            || running.find(x => x.id === mprisTab)
            || (running.length === 1 ? running[0] : null)
        if (!tab) { mprisTab = -1; return }
        var bound = Object.assign({}, tabTrack)
        bound[tab.id] = t
        tabTrack = bound
        mprisTab = tab.id
    }
    Timer {
        id: bindLater
        interval: 1500
        onTriggered: root.bindTrack(root.player)
    }

    // a tab's track: the one bound to it, else one seen whose title its
    // name holds
    function trackOfTab(tab) {
        if (tabTrack[tab.id]) return tabTrack[tab.id]
        var name = tab.name.toLowerCase()
        for (var i = seenTracks.length - 1; i >= 0; i--)
            if (seenTracks[i].title !== "" && name.indexOf(seenTracks[i].title.toLowerCase()) !== -1) return seenTracks[i]
        return null
    }

    // what the module can follow: each player, a browser's as one per tab
    // that has played (bound or running) when it has two or more
    readonly property var sources: {
        var out = []
        players.forEach(p => {
            var tabs = tabsOf(p).filter(t => t.running || t.id === mprisTab || trackOfTab(t) !== null)
            if (tabs.length < 2) out.push({ player: p, tab: -1 })
            else tabs.forEach(t => out.push({ player: p, tab: t.id }))
        })
        return out
    }
    function isShown(src) { return src.player === player && (src.tab === -1 || src.tab === shownTab) }

    // the followed browser's tab on show: the picked one, else the player's
    // own while it plays, else the one that started running last, else the
    // player's own
    property int pickedTab: -1
    readonly property int shownTab: {
        var tabs = tabsOf(player)
        if (tabs.length === 0) return -1
        if (pickedTab !== -1 && tabs.some(t => t.id === pickedTab)) return pickedTab
        if (player.isPlaying) return mprisTab
        var run = tabs.filter(t => t.running && t.id !== mprisTab)
            .sort((a, b) => (startedAt[b.id] || 0) - (startedAt[a.id] || 0))
        return run.length > 0 ? run[0].id : mprisTab
    }
    readonly property var shownTabInfo: tabsOf(player).find(t => t.id === shownTab) || null
    // the shown tab's stream name, for the visualizer to hear it
    readonly property string shownTabName: shownTabInfo ? shownTabInfo.name : ""
    // the shown tab's track when it isn't the player's own
    readonly property var heard: shownTabInfo === null || shownTab === mprisTab ? null
        : trackOfTab(shownTabInfo) || { title: shownTabInfo.name, artist: "", url: "", artUrl: "" }
    // the source on show sounding: the player playing, or the heard tab running
    readonly property bool shownPlaying: heard ? shownTabInfo.running : !!player && player.isPlaying
    // the transport reaches the player's own track only
    function controllable(p) { return !!p && !(p === player && heard) }

    property var seenTracks: []
    function trackOf(p) {
        return { title: String(p.trackTitle || ""), artist: String(p.trackArtist || ""),
            url: String(p.metadata["xesam:url"] || ""), artUrl: String(p.trackArtUrl || "") }
    }
    function rememberTrack(p) {
        var t = trackOf(p)
        if (t.title === "") return
        var kept = seenTracks.filter(x => x.title !== t.title).slice(-19)
        kept.push(t)
        seenTracks = kept
        pruneTracks()
    }
    // title -> { pos, at, len } of each browser track when last seen
    // playing, written each second (in place: only read through clock)
    property var trackPos: ({})
    Timer {
        interval: 1000
        repeat: true
        running: !!root.player && root.player.isPlaying && root.isBrowser(root.player)
        onTriggered: {
            var p = root.player
            p.positionChanged()
            if (p.trackTitle) root.trackPos[String(p.trackTitle)] = { pos: p.position, at: Date.now(), len: root.lengthOf(p) }
        }
    }
    // ticks while a heard tab stands in, so its position moves on
    property real clock: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: root.heard !== null
        onTriggered: root.clock = Date.now()
    }
    // a heard tab's position, from where it was last seen playing on: it
    // has played since
    function heardPos() {
        var s = heard ? trackPos[heard.title] : null
        return s ? Math.min(s.len > 0 ? s.len : Infinity, s.pos + Math.max(0, clock - s.at) / 1000) : 0
    }
    function positionOf(p) { return !p ? 0 : p === player && heard ? heardPos() : p.position }
    function titleOf(p) { return p === player && heard ? heard.title : p ? String(p.trackTitle || "") : "" }
    function artistOf(p) { return p === player && heard ? heard.artist : p ? String(p.trackArtist || "") : "" }

    // a player other than the picked one starting drops the pick; each
    // length a player reports goes in knownLength; a browser's tracks go
    // in seenTracks
    Variants {
        model: root.players
        Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying) {
                    if (modelData !== root.picked) root.picked = null
                    root.pickedTab = -1
                }
                if (root.isBrowser(modelData)) bindLater.restart()
            }
            function onMetadataChanged() {
                if (root.isBrowser(modelData)) {
                    root.rememberTrack(modelData)
                    bindLater.restart()
                }
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
        var h = p === player ? heard : null
        var url = h ? h.url : String(p.metadata["xesam:url"] || "")
        var m = /youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/)([\w-]{11})|youtu\.be\/([\w-]{11})/.exec(url)
        if (m) {
            var id = m[1] || m[2]
            out.push("https://i.ytimg.com/vi/" + id + "/maxresdefault.jpg", "https://i.ytimg.com/vi/" + id + "/mqdefault.jpg")
        } else if (pageArt[url]) out.push(pageArt[url])
        var art = h ? h.artUrl : p.trackArtUrl
        if (art) out.push(art)
        return out
    }

    // page URL -> the picture it names for sharing, "" for none; fetched
    // for the followed player's page when it's a browser's and not YouTube
    property var pageArt: ({})
    readonly property string pageUrl: {
        var url = heard ? heard.url : player && isBrowser(player) ? String(player.metadata["xesam:url"] || "") : ""
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
    // reported. Firefox drops mpris:length a second into a YouTube video
    // (YouTube clears the page's media session), so the track
    // keeps the one it had. A track is its URL and title, not
    // uniqueId: Firefox's passing metadata changes count as new tracks
    property var knownLength: ({})
    function trackKey(p) {
        var md = p.metadata || {}
        return String(md["xesam:url"] || "") + "\n" + String(md["xesam:title"] || "")
    }
    function lengthOf(p) {
        if (p && p === player && heard) {
            var s = trackPos[heard.title]
            return s ? s.len : 0
        }
        var len = reportedLength(p)
        if (len > 0 || !p) return len
        var k = knownLength[p.dbusName]
        return k && k.track === trackKey(p) ? k.length : 0
    }

    function fmtTime(sec) {
        if (!(sec >= 0)) return "--:--"
        var m = Math.floor(sec / 60), s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
