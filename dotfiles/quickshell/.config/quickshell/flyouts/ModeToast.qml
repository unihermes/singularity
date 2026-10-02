// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ModeToast.qml
//
// A small toast at the top centre of the screen naming the mode a key just
// switched: "MONOCLE" / "DWINDLE" for SUPER+M, "CAPS LOCK ON" and the like
// for the lock keys. Self-dismissing rather than a flyout -- there's nothing
// to interact with, so it fades out on its own instead of waiting for a click
// or Escape. scope.modeToastSeq (bumped in shell.qml on every such key on
// this monitor) is what restarts the timer, since scope.modeToastText alone
// wouldn't change on two quick toggles that land on the same mode.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    // Re-armed by the timer below. The surface is mapped only while the
    // toast shows or fades: an opacity fade needs it for its whole duration,
    // but left up between toasts it's a full-screen transparent layer the
    // compositor blends into every frame.
    property bool active: false

    visible: active || box.opacity > 0
    layerNamespace: "singularity-toast"
    // Nothing here is interactive: no keyboard (the base's default), and
    // clicks fall straight through to whatever's beneath the toast.
    mask: Region {}

    Connections {
        target: root.scope
        function onModeToastSeqChanged() {
            // the clock island shows this itself
            if (Settings.islandActive) return
            root.active = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1100
        onTriggered: root.active = false
    }

    PanelFrame {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        // Flush against the bar, whichever edge it's on -- no gap.
        y: Theme.barPosition === "bottom"
            ? root.height - Theme.barExtent - height
            : Theme.barExtent

        width: label.implicitWidth + Theme.sp(36)
        height: label.implicitHeight + Theme.sp(18)

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: Theme.heading(root.scope.modeToastText)

            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: Theme.headingSpacing * 2
            font.weight: Theme.headingBold ? Theme.weightStrong : Theme.weightBody
        }
    }
}
