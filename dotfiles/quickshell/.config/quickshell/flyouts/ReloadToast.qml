// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ReloadToast.qml
//
// Replaces Quickshell's reload popup with a card at the bar's left end: a
// good reload fades, a failure stays longer with the error. The inhibit
// only works from inside the reload handlers (the old shell's, on failure).

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../services"

OverlayWindow {
    id: root

    // Re-armed by the timer; the surface stays mapped through the fade --
    // see ModeToast.
    property bool active: false
    property bool failed: false
    property string error: ""

    readonly property bool atBottom: Theme.barPosition === "bottom"

    visible: active || box.opacity > 0
    layerNamespace: "singularity-toast"
    // click-through, except the card, which a click dismisses
    mask: Region { item: root.active ? box : null }

    property real shownAt: 0

    function show(err) {
        root.shownAt = Date.now()
        root.failed = err !== undefined
        root.error = root.failed ? String(err).trim() : ""
        root.active = true
        hideTimer.interval = root.failed ? 8000 : 1500
        hideTimer.restart()
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            root.show()
        }
        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup()
            root.show(errorString)
        }
    }

    Timer {
        id: hideTimer
        onTriggered: root.active = false
    }

    // A notification card, so it looks as the popups do. A failure is
    // critical: the alert colour, and the error in full.
    NotificationCard {
        id: box
        readonly property int gap: Theme.edgeMargin

        x: gap
        y: root.atBottom ? root.height - Theme.barExtent - gap - height : Theme.barExtent + gap
        width: Theme.fit(380)
        height: implicitHeight
        standalone: true
        bodyLines: 8
        entry: ({
            key: "quickshell-reload",
            appName: "Quickshell",
            icon: "",
            summary: root.failed ? "Reload failed" : "Reloaded",
            // the body is styled text; an error's < and & are literal
            body: root.failed ? root.error.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                : "Configuration loaded",
            urgency: root.failed ? NotificationUrgency.Critical : NotificationUrgency.Normal,
            time: root.shownAt,
            live: null,
            picture: "",
        })
        onDismissed: root.active = false
        // held while the pointer is on it, as a popup is
        onHoveredChanged: if (hovered) hideTimer.stop()
            else if (root.active) hideTimer.restart()

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }
    }
}
