// Singularity - Quickshell
// ~/.config/quickshell/services/Notifications.qml
//
// The session's notification daemon (org.freedesktop.Notifications), for the
// popups (flyouts/NotificationPopups.qml), the history flyout
// (flyouts/NotificationsFlyout.qml), the bar module and Settings.
//
// Every notification is kept until dismissed, except transient ones, which
// go when their popup does. Do Not Disturb holds the popups back; the
// notifications still land in the history.

pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // newest first
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length
    readonly property bool dnd: Settings.notifDnd

    // Notifications showing as popups, newest first
    property var popups: []

    // Date.now() when each notification arrived, by id; the spec carries no
    // timestamp of its own
    property var arrived: ({})
    // Advanced once a minute while there's anything to date, so relative
    // times ("5m") move on
    property double now: Date.now()

    // A bar module's click, IPC or Settings: shell.qml opens the flyout on
    // the focused screen
    signal panelToggled()

    function togglePanel() { panelToggled() }
    function toggleDnd() { Settings.setNotifDnd(!dnd) }
    function dismiss(n) { hidePopup(n); n.dismiss() }
    function clearAll() {
        popups = []
        list.forEach(n => n.dismiss())
    }

    function hidePopup(n) {
        if (popups.indexOf(n) < 0) return
        popups = popups.filter(p => p !== n)
        if (n.transient) n.expire()
    }

    // Seconds a popup stays: what the sender asked for, else Settings'
    // time for its urgency; 0 is until dismissed
    function timeoutFor(n) {
        if (n.expireTimeout > 0) return n.expireTimeout
        return n.urgency === NotificationUrgency.Critical ? Settings.notifTimeoutCritical
            : n.urgency === NotificationUrgency.Low ? Settings.notifTimeoutLow
            : Settings.notifTimeout
    }

    function ago(n) {
        var t = arrived[n.id]
        if (!t) return ""
        var m = Math.floor((now - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + "m"
        if (m < 1440) return Math.floor(m / 60) + "h"
        return Qt.formatDate(new Date(t), "MMM d")
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
            var a = Object.assign({}, root.arrived)
            a[n.id] = Date.now()
            root.arrived = a
            root.now = Date.now()
            // a replacement (same id) takes over its popup rather than
            // stacking a second one
            var rest = root.popups.filter(p => p.id !== n.id)
            root.popups = root.dnd ? rest : [n].concat(rest)
            n.closed.connect(() => {
                root.popups = root.popups.filter(p => p !== n)
                var left = Object.assign({}, root.arrived)
                delete left[n.id]
                root.arrived = left
            })
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.count > 0
        onTriggered: root.now = Date.now()
    }

    // Turning DND on also clears what's already up
    Connections {
        target: Settings
        function onNotifDndChanged() { if (Settings.notifDnd) root.popups = [] }
    }
}
