// Singularity - Quickshell
// ~/.config/quickshell/LevelToast.qml
//
// Volume/brightness OSD: a thin level bar flush under the bar, naming
// whichever one last changed and fading out on its own -- same shape as
// LayoutToast, but two triggers instead of one and a fill bar instead of a
// label. Not gated to the focused screen like LayoutToast/WorkspaceOverlay:
// volume and brightness are both system-wide, not per-monitor state, so a
// hardware key press should show the OSD wherever it's looked at, not only
// on whichever screen last had focus.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    required property var bar
    // Kept true and re-armed by the timer rather than toggling window
    // `visible` -- see LayoutToast for why an opacity fade needs the surface
    // mapped for its whole duration.
    property bool active: false
    // "volume" or "brightness"; decides the icon and which of bar's two
    // readouts the fill bar tracks.
    property string mode: "volume"

    readonly property int level: mode === "volume" ? bar.volumeLevel : bar.brightness
    readonly property string icon: mode === "volume"
        ? (bar.volumeIsMuted ? "󰖁" : "󰕾")
        : "󰃠"

    visible: true
    layerNamespace: "singularity-toast"
    // Nothing here is interactive: no keyboard (the base's default), and
    // clicks fall straight through to whatever's beneath the toast.
    mask: Region {}

    // Brightness loads asynchronously from sysfs and volume settles once the
    // Pipewire sink reports ready, so both fire an initial "change" shortly
    // after startup that isn't a user action -- ignored until this settles.
    property bool ready: false
    Timer { interval: 1500; running: true; onTriggered: root.ready = true }

    function show(which) {
        if (!root.ready) return
        root.mode = which
        root.active = true
        hideTimer.restart()
    }

    Connections {
        target: root.bar
        function onVolumeLevelChanged() { root.show("volume") }
        function onVolumeIsMutedChanged() { root.show("volume") }
        function onBrightnessChanged() { root.show("brightness") }
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.active = false
    }

    PanelFrame {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        // Flush against the bar, whichever edge it's on -- no gap.
        y: Theme.barPosition === "bottom"
            ? root.height - Theme.barHeight - height
            : Theme.barHeight
        width: 220
        height: row.implicitHeight + 18

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.dur(150); easing.type: Easing.OutCubic }
        }

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: parent.width - 24
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - row.spacing - 24
                height: 6
                radius: height / 2
                color: Theme.base
                border.width: 1
                border.color: Theme.border

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.level <= 0
                        ? 0
                        : Math.max(height, parent.width * Math.min(1, root.level / 100))
                    radius: parent.radius
                    color: root.mode === "volume" && root.bar.volumeIsMuted ? Theme.muted : Theme.text

                    Behavior on width {
                        NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.dur(110) } }
                }
            }
        }
    }
}
