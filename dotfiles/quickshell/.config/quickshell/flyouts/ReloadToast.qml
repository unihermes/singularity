// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ReloadToast.qml
//
// Stands in for Quickshell's own reload popup: a notification card at the
// bar's left end, clear of the notification popups on the right. A
// good reload fades on its own; a failed one shows the error and stays
// until clicked or its longer timer runs out. Either can be closed.
//
// inhibitReloadPopup() only takes effect when called from inside the
// reloadCompleted/reloadFailed handlers. A failed reload leaves the old
// shell running, so its handlers are the ones that catch reloadFailed.

import Quickshell
import Quickshell.Wayland
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
