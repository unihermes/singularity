// Singularity - Quickshell
// ~/.config/quickshell/LayoutToast.qml
//
// SUPER+M: a small "MONOCLE" / "DWINDLE" toast at the top centre of the
// screen, naming the layout just switched to. Self-dismissing rather than a
// flyout -- there's nothing to interact with, so it fades out on its own
// instead of waiting for a click or Escape. scope.layoutToastSeq (bumped in
// shell.qml on every SUPER+M on this monitor) is what restarts the timer,
// since scope.layoutToastMode alone wouldn't change on two quick toggles
// that land back on the same mode.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

PanelWindow {
    id: root

    required property var scope
    // Kept true and re-armed by the timer below rather than toggling window
    // `visible` on and off: an opacity fade needs the surface mapped for its
    // whole duration, and a click-through, always-transparent strip costs
    // nothing to leave mapped between toasts (same call the bar itself makes).
    property bool active: false

    screen: scope.modelData
    visible: true
    // Spans the full screen height, like WorkspaceOverlay: anchoring alone
    // leaves a PanelWindow at 100x100, and the box below is positioned
    // against whichever edge the bar sits on.
    anchors { top: true; left: true; right: true; bottom: true }
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    // Nothing here is interactive, so it should never steal input from
    // whatever's underneath.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "singularity-toast"
    // Clicks fall straight through to whatever's beneath the toast.
    mask: Region {}

    Connections {
        target: root.scope
        function onLayoutToastSeqChanged() {
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
            ? root.height - Theme.barHeight - height
            : Theme.barHeight
        width: label.implicitWidth + 36
        height: label.implicitHeight + 18

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.dur(150); easing.type: Easing.OutCubic }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.scope.layoutToastMode === "monocle" ? "MONOCLE" : "DWINDLE"
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 2
            font.bold: true
        }
    }
}
