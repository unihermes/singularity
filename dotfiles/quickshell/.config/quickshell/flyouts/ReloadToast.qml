// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ReloadToast.qml
//
// Stands in for Quickshell's own reload popup: a notification card at the
// bar's left end, clear of the notification popups on the right. A
// good reload fades on its own; a failed one shows the error and stays
// until clicked or its longer timer runs out.
//
// inhibitReloadPopup() only takes effect when called from inside the
// reloadCompleted/reloadFailed handlers. A failed reload leaves the old
// shell running, so its handlers are the ones that catch reloadFailed.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    // Kept true and re-armed by the timer rather than toggling window
    // `visible` -- see ModeToast for why an opacity fade needs the surface
    // mapped for its whole duration.
    property bool active: false
    property bool failed: false
    property string error: ""

    readonly property bool atBottom: Theme.barPosition === "bottom"

    visible: true
    layerNamespace: "singularity-toast"
    // click-through, except a failure's panel, which a click dismisses
    mask: Region { item: root.active && root.failed ? box : null }

    function show(err) {
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

    // Sized and spaced as a notification popup is, a summary over a body.
    // A failure takes the alert stroke, as a critical notification does
    // (NotificationCard).
    PanelFrame {
        id: box
        readonly property int gap: Theme.edgeMargin

        x: gap
        y: root.atBottom ? root.height - Theme.barExtent - gap - height : Theme.barExtent + gap
        width: Theme.fit(380)
        height: col.implicitHeight + Theme.panelPad * 2
        border.color: root.failed ? Theme.alert : Theme.stroke

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }

        Column {
            id: col
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            spacing: Theme.spaceS

            Text {
                text: root.failed ? "Quickshell reload failed" : "Quickshell reloaded"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
                font.bold: true
            }

            Text {
                width: col.width
                text: root.failed ? root.error : "Configuration loaded"
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
                wrapMode: Text.Wrap
                maximumLineCount: 8
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.failed
            cursorShape: Qt.PointingHandCursor
            onClicked: root.active = false
        }
    }
}
