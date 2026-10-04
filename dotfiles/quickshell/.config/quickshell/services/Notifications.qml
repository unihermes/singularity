// Singularity - Quickshell
// ~/.config/quickshell/services/Notifications.qml
//
// The session's notification daemon (org.freedesktop.Notifications), for the
// popups (flyouts/NotificationPopups.qml), the history flyout
// (flyouts/NotificationsFlyout.qml), the bar module and Settings.
//
// The history is the shell's own record of what arrived this session, kept
// in $XDG_RUNTIME_DIR/singularity-notifications.json, which goes at logout.
// An entry stays until it's cleared from the history by hand -- not when its
// popup goes, the sender withdraws it, or the shell restarts. Transient
// notifications are the exception: by the spec they aren't kept, so they go
// with their popup.
// While the sender still holds a notification its entry carries it as
// `live`, which is what its actions and attached image need.
//
// Anything that arrived since the history was last opened is unread, which
// is the number the bar module shows. Do Not Disturb holds the popups back;
// notifications still land in the history, unread. An app silenced in
// Settings is held the same way, on its own.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "TimeWindow.js" as TimeWindow

Singleton {
    id: root

    // Newest first:
    // [{ key, id, appName, summary, body, icon, picture, urgency,
    //    expireTimeout, transient, time, live }]
    // Entries are replaced, never changed in place, so bindings see the change.
    property var history: []
    readonly property int count: history.length
    readonly property bool dnd: Settings.notifDnd

    // Date.now() when the history was last looked at; newer entries are unread
    property double lastSeen: 0
    readonly property int unread: history.filter(e => e.time > lastSeen).length
    // lastSeen as it was when the open history was opened, so what was new
    // then stays marked while it's on screen
    property double seenBefore: 0
    property bool viewing: false

    // Entries showing as popups, newest first
    property var popups: []

    // Advanced once a minute while there's anything to date, so relative
    // times ("5m") move on
    property double now: Date.now()

    readonly property int maxEntries: 200

    // A bar module's click, IPC or Settings: shell.qml opens the flyout on
    // the focused screen
    signal panelToggled()

    function togglePanel() { panelToggled() }
    function toggleDnd() { Settings.setNotifDnd(!dnd) }

    // The history flyout opening or closing
    function setViewing(on) {
        if (on === viewing) return
        viewing = on
        if (!on) return
        seenBefore = lastSeen
        markSeen()
    }

    function markSeen() {
        lastSeen = Date.now()
        saveTimer.restart()
    }

    function isNew(entry) { return entry.time > (viewing ? seenBefore : lastSeen) }

    // Out of the history for good, withdrawing it from the sender too
    function remove(entry) {
        hidePopup(entry)
        history = history.filter(e => e.key !== entry.key)
        closeLive(entry)
        saveTimer.restart()
    }

    function clearAll() {
        const all = history
        popups = []
        history = []
        all.forEach(closeLive)
        saveTimer.restart()
    }

    // A notification whose action was just invoked may be gone already
    function closeLive(entry) {
        if (entry.live && entry.live.tracked) entry.live.dismiss()
    }

    // The popup only; the entry stays in the history
    function hidePopup(entry) {
        if (!popups.some(p => p.key === entry.key)) return
        popups = popups.filter(p => p.key !== entry.key)
        if (entry.transient) {
            history = history.filter(e => e.key !== entry.key)
            if (entry.live && entry.live.tracked) entry.live.expire()
        }
    }

    // Runs one of the sender's actions; the popup goes, the entry stays
    function invoke(entry, action) {
        hidePopup(entry)
        action.invoke()
    }

    // Seconds a popup stays: what the sender asked for, else Settings'
    // time for its urgency; 0 is until dismissed
    function timeoutFor(entry) {
        if (entry.expireTimeout > 0) return entry.expireTimeout
        return entry.urgency === NotificationUrgency.Critical ? Settings.notifTimeoutCritical
            : entry.urgency === NotificationUrgency.Low ? Settings.notifTimeoutLow
            : Settings.notifTimeout
    }

    function ago(entry) {
        var m = Math.floor((now - entry.time) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + "m"
        if (m < 1440) return Math.floor(m / 60) + "h"
        return Qt.formatDate(new Date(entry.time), "MMM d")
    }

    // The attached picture: the live notification's while there is one (image
    // data is only served while it lasts), else a file it named
    function pictureOf(entry) {
        return entry.live && entry.live.tracked ? pictureFor(entry.live) : entry.picture
    }

    // The app's icon as a source for an Image: a path or URL as given, a
    // theme icon name looked up, "" when there's nothing to show. An
    // image-path hint that names a theme icon (notify-send -i sends one)
    // counts as the icon.
    function iconFor(n) {
        var i = n.appIcon || n.desktopEntry
        if (!i && n.image.startsWith("image://icon/") && !n.image.startsWith("image://icon//"))
            return n.image
        if (!i) return ""
        if (i.startsWith("/")) return "file://" + i
        if (i.indexOf("://") > 0) return i
        return Quickshell.iconPath(i, true)
    }

    // The attached picture: image data as Quickshell serves it, or a file
    // from the image-path hint, which Quickshell hands over as an icon URL
    function pictureFor(n) {
        var i = n.image
        if (i.startsWith("image://icon//")) return "file://" + i.slice("image://icon/".length)
        if (i.startsWith("image://icon/")) return ""
        return i
    }

    function entryFor(n, time) {
        return {
            key: time + "-" + n.id,
            id: n.id,
            appName: n.appName,
            summary: n.summary,
            body: n.body,
            icon: iconFor(n),
            picture: pictureFor(n),
            urgency: n.urgency,
            expireTimeout: n.expireTimeout,
            transient: n.transient,
            time: time,
            live: n
        }
    }

    // The entry with `live` swapped, in the history and the popups
    function replaceLive(entry, live) {
        const next = Object.assign({}, entry, { live: live })
        history = history.map(e => e.key === entry.key ? next : e)
        popups = popups.map(p => p.key === entry.key ? next : p)
    }

    function attach(n) {
        n.closed.connect(() => {
            const e = root.history.find(x => x.live === n)
            // the sender withdrew it: gone from the screen, kept in the history
            if (e) {
                root.popups = root.popups.filter(p => p.key !== e.key)
                if (e.transient) root.history = root.history.filter(x => x.key !== e.key)
                else root.replaceLive(e, null)
            }
        })
    }

    // Notifications the server still holds with no entry (a reload before
    // they were saved), added as they are; their arrival time is lost
    function adoptLive() {
        const time = Date.now()
        const added = server.trackedNotifications.values
            .filter(n => !history.some(e => e.live === n))
            .map(n => { attach(n); return entryFor(n, time) })
        if (added.length === 0) return
        history = added.concat(history).slice(0, maxEntries)
        saveTimer.restart()
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            n.tracked = true
            // Held over a reload (keepOnReload) and announced again: link it
            // back to its entry rather than showing it as new
            if (n.lastGeneration) {
                const had = root.history.find(e => e.live === n)
                    || root.history.find(e => !e.live && e.id === n.id && e.summary === n.summary)
                if (had) {
                    if (had.live !== n) {
                        root.replaceLive(had, n)
                        root.attach(n)
                    }
                    return
                }
            }
            const time = Date.now()
            const entry = root.entryFor(n, time)
            // a replacement (same id, still held by its sender) takes over
            // the old entry and its popup rather than stacking a second one
            const old = root.history.find(e => e.id === n.id && e.live)
            const rest = root.history.filter(e => e !== old)
            root.history = [entry].concat(rest).slice(0, root.maxEntries)
            const others = root.popups.filter(p => !old || p.key !== old.key)
            // critical ones (a battery about to die) still come through DND
            // and an app's silencing
            const hold = (root.dnd || Settings.notifSilent.indexOf(n.appName) >= 0)
                && n.urgency !== NotificationUrgency.Critical
            root.popups = hold || n.lastGeneration ? others : [entry].concat(others)
            root.now = time
            if (root.viewing) root.lastSeen = time
            root.attach(n)
            saveTimer.restart()
        }
    }

    // --- persistence --------------------------------------------------------

    function save() {
        const entries = history.filter(e => !e.transient).map(e => ({
            id: e.id, appName: e.appName, summary: e.summary, body: e.body,
            icon: e.icon,
            // image data doesn't outlive the notification; a file does
            picture: e.picture.startsWith("file://") ? e.picture : "",
            urgency: e.urgency, time: e.time
        }))
        view.setText(JSON.stringify({ lastSeen: lastSeen, entries: entries }, null, 1) + "\n")
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root.save()
    }

    FileView {
        id: view
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/singularity-notifications.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        // no file until the first notification
        printErrors: false

        onLoaded: {
            let d
            try { d = JSON.parse(text()) } catch (e) { return }
            const live = server.trackedNotifications.values
            const entries = (d.entries || []).filter(x => x && typeof x.time === "number").map(x => {
                const e = {
                    key: x.time + "-" + x.id, id: x.id | 0,
                    appName: String(x.appName || ""), summary: String(x.summary || ""),
                    body: String(x.body || ""), icon: String(x.icon || ""),
                    picture: String(x.picture || ""), urgency: x.urgency | 0,
                    expireTimeout: 0, transient: false, time: x.time, live: null
                }
                // After a reload the server still holds what hasn't closed
                // (keepOnReload), so its entry gets its actions back
                const n = live.find(l => l.id === e.id && l.summary === e.summary)
                if (n) {
                    e.live = n
                    root.attach(n)
                }
                return e
            })
            root.history = entries.slice(0, root.maxEntries)
            root.lastSeen = typeof d.lastSeen === "number" ? d.lastSeen : 0
            root.adoptLive()
        }
        onLoadFailed: root.adoptLive()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.count > 0
        onTriggered: root.now = Date.now()
    }

    // Turning DND on also clears what's already up; turning it off by hand
    // takes it back from the schedule until the next quiet hours
    Connections {
        target: Settings
        function onNotifDndChanged() {
            if (Settings.notifDnd) root.popups = []
            else if (Settings.notifDndBySchedule) Settings.setNotifDndBySchedule(false)
        }
        function onNotifQuietChanged() { root.quietState = undefined; root.checkQuiet() }
        function onNotifQuietFromChanged() { root.quietState = undefined; root.checkQuiet() }
        function onNotifQuietToChanged() { root.quietState = undefined; root.checkQuiet() }
    }

    // --- quiet hours ----------------------------------------------------------
    // DND on a daily window. Acts only as the window opens or closes, and the
    // close only undoes DND the window itself turned on. Checked by the wall
    // clock and on waking, so a window that passed during sleep still ends.

    property var quietState: undefined

    function checkQuiet() {
        const want = Settings.notifQuiet
            && TimeWindow.contains(Settings.notifQuietFrom, Settings.notifQuietTo, new Date())
        if (want === quietState) return
        quietState = want
        if (want) {
            if (!Settings.notifDnd) {
                Settings.setNotifDnd(true)
                Settings.setNotifDndBySchedule(true)
            }
        } else if (Settings.notifDndBySchedule) {
            Settings.setNotifDndBySchedule(false)
            Settings.setNotifDnd(false)
        }
    }

    Connections {
        target: Session
        function onResumed() { root.checkQuiet() }
    }

    Timer {
        interval: 20000
        repeat: true
        running: Settings.notifQuiet || Settings.notifDndBySchedule
        triggeredOnStart: true
        onTriggered: root.checkQuiet()
    }
}
