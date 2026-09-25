// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ReloadToast.qml
//
// Stands in for Quickshell's own reload popup: a notification card at the
// bar's left end, mirroring where swaync puts its popups on the right. A
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
    // `visible` -- see LayoutToast for why an opacity fade needs the surface
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

    // Sized and placed like a swaync popup (dotfiles/swaync): the same
    // 380px window less its 6px padding, 6px off the bar and the screen
    // edge, and the text inset and sizes its card gives a summary and body.
    // A failure takes the alert stroke, as a critical notification does.
    PanelFrame {
        id: box
        readonly property int gap: 6

        x: gap
        y: root.atBottom ? root.height - Theme.barExtent - gap - height : Theme.barExtent + gap
        width: 368
        height: col.implicitHeight + 26
        border.color: root.failed ? Theme.alert : Theme.stroke

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }

        Column {
            id: col
            x: 14
            y: 11
            width: parent.width - 28
            spacing: 2

            Text {
                text: root.failed ? "Quickshell reload failed" : "Quickshell reloaded"
                color: Theme.bright
                font.family: Theme.fontText
                font.pixelSize: Theme.fs(13)
                font.bold: true
            }

            Text {
                width: col.width
                text: root.failed ? root.error : "Configuration loaded"
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fs(13)
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
