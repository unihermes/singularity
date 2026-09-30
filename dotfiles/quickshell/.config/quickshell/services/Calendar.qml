// Singularity - Quickshell
// ~/.config/quickshell/services/Calendar.qml
//
// Events from the iCalendar feeds in ~/.local/state/singularity/calendars.conf
// ("Name = URL" per line), for the calendar flyout. scripts/calendar-events.py
// downloads and expands them into a cache file this watches, so events show
// straight away at login and stay up while offline.
//
// Refreshed every hour, every 2 minutes while a download is failing, and a few
// seconds after waking from sleep, once the network is back. Every run is
// capped by `timeout`, whose clock keeps counting through a suspend, so a
// download cut off by sleep can't leave the service stuck on a dead process.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string confPath: Settings.stateDir + "/calendars.conf"
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/singularity/calendar/events.json"
    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/calendar-events.py"

    // at least one feed in calendars.conf
    readonly property bool configured: {
        var lines = confFile.text().split("\n")
        for (var i = 0; i < lines.length; i++)
            if (/https?:\/\/|webcal:\/\//.test(lines[i]) && !/^\s*#/.test(lines[i])) return true
        return false
    }

    // [{ cal, title, location, start: Date, end: Date, allDay }], by start
    property var events: []
    // [{ name, ok, fetched }], ok false when the last download failed
    property var feeds: []
    readonly property bool offline: feeds.some(f => !f.ok)
    // newest good download across the feeds, as a Date, or null
    readonly property var fetched: {
        var t = Math.max.apply(null, [0].concat(feeds.map(f => f.fetched || 0)))
        return t > 0 ? new Date(t) : null
    }
    readonly property bool refreshing: run.running
    property bool failed: false

    // "yyyy-MM-dd" -> true for every day an event touches
    readonly property var busyDays: {
        var out = {}
        for (var i = 0; i < events.length; i++) {
            var e = events[i]
            var d = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate())
            // all-day ends are exclusive; a timed event ending at midnight
            // doesn't touch the next day either
            for (var n = 0; n < 62 && d < e.end; n++) {
                out[dayKey(d)] = true
                d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)
            }
            if (n === 0) out[dayKey(e.start)] = true
        }
        return out
    }

    function dayKey(d) { return Qt.formatDate(d, "yyyy-MM-dd") }

    // the events touching a day, all-day ones first
    function eventsOn(day) {
        var s = new Date(day.getFullYear(), day.getMonth(), day.getDate())
        var e = new Date(s.getFullYear(), s.getMonth(), s.getDate() + 1)
        return events.filter(x => x.start < e && (x.end > s || x.start >= s))
            .sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start))
    }

    // "2026-09-30" or "2026-09-30T14:05", read as local time
    function parse(s) {
        var m = /^(\d+)-(\d+)-(\d+)(?:T(\d+):(\d+))?/.exec(s)
        if (!m) return new Date(NaN)
        return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0))
    }

    function refresh(offline) {
        if (!configured) return
        if (run.running) {
            run.pending = true
            run.pendingFetch = run.pendingFetch || !offline
            return
        }
        run.offline = !!offline
        run.running = true
    }

    FileView {
        id: confFile
        path: root.confPath
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refresh(false)
    }

    FileView {
        id: cacheFile
        path: root.cachePath
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var d
            try { d = JSON.parse(text()) } catch (e) { return }
            root.feeds = d.feeds || []
            root.events = (d.events || []).map(e => ({
                cal: String(e.cal || ""), title: String(e.title || ""),
                location: String(e.location || ""), allDay: !!e.allDay,
                start: root.parse(e.start), end: root.parse(e.end),
            })).filter(e => !isNaN(e.start.getTime()))
        }
    }

    Process {
        id: run
        property bool offline: false
        // asked for again while running, and whether that wants the network
        property bool pending: false
        property bool pendingFetch: false
        command: ["timeout", "90", "python3", root.script].concat(offline ? ["--offline"] : [])
        stderr: SplitParser { onRead: line => console.warn("calendar:", line) }
        onExited: code => {
            if (!run.offline) root.failed = code !== 0
            if (!run.pending) return
            var fetch = run.pendingFetch
            run.pending = run.pendingFetch = false
            Qt.callLater(() => root.refresh(!fetch))
        }
    }

    Timer {
        interval: root.failed ? 120000 : 3600000
        repeat: true
        running: root.configured
        onTriggered: root.refresh(false)
    }

    // At wake: re-read what's cached at once, then download once Wi-Fi has
    // had a moment to come back
    Connections {
        target: Session
        function onResumed() {
            root.refresh(true)
            wakeFetch.restart()
        }
    }

    Timer {
        id: wakeFetch
        interval: 8000
        onTriggered: root.refresh(false)
    }
}
