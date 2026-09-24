// Singularity - Quickshell
// ~/.config/quickshell/flyouts/LevelToast.qml
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

    // Kept true and re-armed by the timer rather than toggling window
    // `visible` -- see LayoutToast for why an opacity fade needs the surface
    // mapped for its whole duration.
    property bool active: false
    // "volume" or "brightness"; decides the icon and which level the
    // fill bar tracks.
    property string mode: "volume"

    readonly property int level: mode === "volume" ? Audio.percent : Brightness.level
    readonly property string icon: mode === "volume"
        ? (Audio.muted ? "󰖁" : "󰕾")
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
        // the clock island shows these itself
        if (!root.ready || Settings.islandActive) return
        root.mode = which
        root.active = true
        hideTimer.restart()
    }

    Connections {
        target: Audio
        function onPercentChanged() { root.show("volume") }
        function onMutedChanged() { root.show("volume") }
    }

    Connections {
        target: Brightness
        function onLevelChanged() { root.show("brightness") }
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
            ? root.height - Theme.barExtent - height
            : Theme.barExtent

        width: Theme.fit(220)
        height: row.implicitHeight + Theme.sp(18)

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.spaceXl
            width: parent.width - Theme.spaceXl * 2
            spacing: Theme.sp(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }

            Meter {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: row.width - row.spacing - Theme.fs(24)
                border.color: Theme.stroke
                fraction: root.level / 100
                fillColor: root.mode === "volume" && Audio.muted ? Theme.textDisabled : Theme.meterFill
            }
        }
    }
}
