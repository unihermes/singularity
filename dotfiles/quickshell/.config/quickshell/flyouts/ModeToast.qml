// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ModeToast.qml
//
// A self-dismissing toast at the top centre naming a mode just switched
// (SUPER+M, lock keys, lid). scope.modeToastSeq restarts it, even when the
// text repeats.

import Quickshell
import QtQuick
import "../services"

OverlayWindow {
    id: root

    // mapped only while showing or fading (an idle full-screen layer would
    // be blended every frame)
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
