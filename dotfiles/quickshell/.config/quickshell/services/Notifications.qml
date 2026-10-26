// Singularity - Quickshell
// ~/.config/quickshell/services/Notifications.qml
//
// The notification daemon, for the popups, the history sidebar, the bar
// module and Settings. The history ($XDG_RUNTIME_DIR, gone at logout) keeps
// each entry until cleared by hand, except transient ones; `live` holds the
// sender's object while it exists (actions, image). New since the history
// was opened is unread. DND and silenced apps hold back popups only.
// A click opens what it's about (activate); Claude's make ChatGPT's sound.

pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import "TimeWindow.js" as TimeWindow

Singleton {
    id: root

    // newest first, replaced (never changed in place) so bindings update:
    // [{ key, id, appName, desktopEntry, phone, phonePackage, summary,
    //    body, icon, picture, urgency, expireTimeout, transient, time, live }]
    // phone: from the phone link (scripts/phone-link.py), phonePackage its
    // Android app
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

    // the history sidebar: on which screen, and whether it's out
    property bool shown: false
    property var screen: null
    // built on first open, then kept
    property bool used: false

    // Entries showing as popups, newest first
    property var popups: []

    // Advanced once a minute while there's anything to date, so relative
    // times ("5m") move on
    property double now: Date.now()

    readonly property int maxEntries: 200

    // The sidebar on this screen, or put away if it's out there; the
    // Claude sidebar, on the same edge, goes. Opening it clears the popups,
    // since what arrives shows in it.
    function toggle(screen) {
        if (shown && root.screen === screen) { shown = false; return }
        root.screen = screen
        used = true
        shown = true
        popups = []
        Ai.shown = false
    }

    // IPC or Settings: on the focused screen
    function togglePanel() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        toggle(Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0])
    }
    function toggleDnd() { Settings.setNotifDnd(!dnd) }

    // The history sidebar coming out or going
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

    // --- what a card offers beyond the sender's own actions ------------------

    // shell.qml opens Settings' Notifications page on the focused screen
    signal settingsRequested()

    // the summary and body as plain text
    function plainText(entry) {
        return [entry.summary, String(entry.body || "").replace(/<[^>]*>/g, " ")]
            .join("\n").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/[ \t]+/g, " ").trim()
    }

    // A one-time code in a notification about one (verification, sign-in,
    // 2FA), its digits run together: "123 456" and "G-123456" give the
    // digits; "" for none
    function codeIn(entry) {
        const t = plainText(entry)
        if (!/\b(code|verif|otp|passcode|pin|2fa|one[- ]time|log ?in|sign[- ]?in|security|authenticat)/i.test(t)) return ""
        const m = t.match(/(?:^|[^\d])(\d{3}[ -]\d{3}|\d{4,8})(?![\d])/)
        return m ? m[1].replace(/[ -]/g, "") : ""
    }

    // the first web link in the body (a link's target, else one written
    // out), "" for none
    function linkIn(entry) {
        const body = String(entry.body || "")
        const a = body.match(/href=["'](https?:\/\/[^"']+)["']/i)
        if (a) return a[1]
        const m = body.match(/https?:\/\/[^\s<>"']+/i)
        return m ? m[0].replace(/[.,;:!?)\]]+$/, "") : ""
    }

    function copy(entry, text) {
        hidePopup(entry)
        Quickshell.execDetached(["wl-copy", "--", text])
    }

    function openLink(entry, url) {
        hidePopup(entry)
        Qt.openUrlExternally(url)
    }

    function silenced(entry) { return Settings.notifSilent.indexOf(entry.appName) >= 0 }

    // the app's popups held (or let through again); the popup goes
    function toggleSilent(entry) {
        Settings.setNotifSilent(entry.appName, !silenced(entry))
        hidePopup(entry)
    }

    function openSettings(entry) {
        hidePopup(entry)
        shown = false
        settingsRequested()
    }

    // --- a click: open what it's about ----------------------------------------

    // The sender's default action if it has one, then the app's window
    // brought to the front (on whatever workspace, the scratchpad too), else
    // the app started. A phone's notification opens its app here when it's
    // installed, else on the phone's mirror.
    function activate(entry) {
        hidePopup(entry)
        shown = false
        const def = entry.live && entry.live.tracked
            ? entry.live.actions.find(a => a.identifier === "default") : null
        if (def) def.invoke()
        raiser.entry = entry
        raiser.invoked = !!def
        raiser.tries = 0
        raiser.restart()
    }

    // lowercase letters and digits, to match names and classes either way
    function norm(s) { return String(s || "").toLowerCase().replace(/[^a-z0-9]/g, "") }

    // what an entry's app goes by: its desktop entry (the last part of a
    // reverse-DNS one too) and its name
    function appKeys(entry) {
        const de = entry.desktopEntry || ""
        return [de, de.split(".").pop(), entry.appName].map(norm).filter(k => k.length >= 3)
    }

    // The app's most recently focused window: its class exactly, else (not
    // for a phone's app, whose short names would catch anything) a class
    // holding its name
    function windowFor(entry) {
        const keys = appKeys(entry)
        if (keys.length === 0) return null
        const ipc = t => t.lastIpcObject
        const wins = Hyprland.toplevels.values.filter(t => ipc(t) && ipc(t).class !== undefined && !Apps.isShellWindow(t))
            .sort((a, b) => (ipc(a).focusHistoryID ?? 999) - (ipc(b).focusHistoryID ?? 999))
        const names = t => [norm(ipc(t).class), norm(ipc(t).initialClass)].filter(c => c.length >= 3)
        return wins.find(t => names(t).some(c => keys.indexOf(c) >= 0))
            || (entry.phone ? null : wins.find(t => names(t).some(c => keys.some(k => c.indexOf(k) >= 0))))
            || null
    }

    // the installed app it's from, by id, name or window class
    function desktopFor(entry) {
        const keys = appKeys(entry)
        if (keys.length === 0) return null
        return DesktopEntries.applications.values.find(e => !e.noDisplay
            && [e.id.replace(/\.desktop$/, ""), e.name, e.startupClass].some(s => keys.indexOf(norm(s)) >= 0)) || null
    }

    function raise(win) {
        const addr = "address:0x" + win.address
        Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
        Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
    }

    // A moment after the click, so an app that raises its own window (the
    // right one of several) has; asked again while a default action may
    // still be mapping one
    Timer {
        id: raiser
        property var entry: null
        property bool invoked: false
        property int tries: 0
        interval: 250
        onTriggered: {
            const e = entry
            const win = root.windowFor(e)
            const active = Hyprland.activeToplevel
            if (win) {
                if (!active || active.address !== win.address
                        || (ipcWorkspace(win) || "").startsWith("special:")) root.raise(win)
                return
            }
            if (invoked) {
                if (++tries < 8) restart()
                return
            }
            const app = root.desktopFor(e)
            if (app) Apps.launch(app)
            else if (e.phone && e.phonePackage) Phone.openApp(e.phonePackage)
        }
        function ipcWorkspace(t) { return t.lastIpcObject.workspace ? t.lastIpcObject.workspace.name : "" }
    }

    // --- sound ---------------------------------------------------------------

    // Claude's own, its desktop app's or Claude Code's through the terminal
    function isClaude(n) {
        return /claude/i.test(n.appName) || /claude/i.test(n.desktopEntry)
            || (n.appName === "" && n.summary === "Claude Code")
    }

    // ChatGPT's notification sound, else freedesktop's
    function playClaudeSound() {
        Quickshell.execDetached(["sh", "-c",
            "for f in /usr/lib/chatgpt/resources/codex-notification.wav "
            + "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga; do "
            + "[ -r \"$f\" ] && exec pw-play \"$f\"; done"])
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

    // The icon a row or card shows: the app's, else the phone's picture for
    // its app, else an installed app's going by its name, else Claude's for
    // Claude Code's through the terminal; "" for none
    function iconOf(entry) {
        if (entry.icon) return entry.icon
        if (entry.phone && entry.picture) return entry.picture
        const app = desktopFor(entry)
        if (app && app.icon) return Quickshell.iconPath(app.icon, true)
        if (isClaude(entry)) return Quickshell.iconPath("claude-desktop", true)
        return ""
    }

    // The attached picture: the live notification's while there is one (image
    // data is only served while it lasts), else a file it named. Not the
    // phone's, which is its icon (iconOf)
    function pictureOf(entry) {
        if (entry.phone && !entry.icon) return ""
        return entry.live && entry.live.tracked ? pictureFor(entry.live) : entry.picture
    }

    // the app's icon for an Image: a path or URL, a theme icon (an
    // image-path hint naming one counts), or ""
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
            desktopEntry: n.desktopEntry,
            phone: n.hints["x-singularity-phone"] !== undefined,
            phonePackage: String(n.hints["x-singularity-phone"] || ""),
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
            // none while the sidebar's out, where it shows; the sound still plays
            const pops = !hold && !n.lastGeneration && !root.shown
            root.popups = pops ? [entry].concat(others) : others
            if (!hold && !n.lastGeneration && root.isClaude(n)) root.playClaudeSound()
            root.now = time
            if (root.viewing) root.lastSeen = time
            root.attach(n)
            saveTimer.restart()
        }
    }

    // --- persistence --------------------------------------------------------

    function save() {
        const entries = history.filter(e => !e.transient).map(e => ({
            id: e.id, appName: e.appName, desktopEntry: e.desktopEntry,
            phone: e.phone, phonePackage: e.phonePackage,
            summary: e.summary, body: e.body,
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
                    appName: String(x.appName || ""), desktopEntry: String(x.desktopEntry || ""),
                    phone: !!x.phone, phonePackage: String(x.phonePackage || ""),
                    summary: String(x.summary || ""),
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
    // acts only as the window opens or closes (the close undoes only its own
    // DND); checked by the wall clock and on waking

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
