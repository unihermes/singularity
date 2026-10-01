// Singularity - Quickshell
// ~/.config/quickshell/flyouts/LevelToast.qml
//
// Volume/brightness OSD: a thin level bar flush under the bar, naming
// whichever one last changed and fading out on its own -- same shape as
// ModeToast, but two triggers instead of one and a fill bar instead of a
// label. Not gated to the focused screen like ModeToast/WorkspaceOverlay:
// volume and brightness are both system-wide, not per-monitor state, so a
// hardware key press should show the OSD wherever it's looked at, not only
// on whichever screen last had focus.
//
// Drawn as Theme.levelStyle says: the level bar under the bar, a vertical
// bar at the screen's right edge, or the number itself under the bar.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    // Re-armed by the timer; the surface stays mapped through the fade --
    // see ModeToast.
    property bool active: false
    // "volume" or "brightness"; decides the icon and which level the
    // fill bar tracks.
    property string mode: "volume"

    readonly property int level: mode === "volume" ? Audio.percent : Brightness.level
    readonly property string icon: mode === "volume"
        ? (Audio.muted ? "󰖁" : "󰕾")
        : "󰃠"

    visible: active || box.opacity > 0
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

    readonly property bool edge: Theme.levelStyle === "edge"
    readonly property bool number: Theme.levelStyle === "number"

    PanelFrame {
        id: box
        // Flush against the bar, whichever edge it's on -- no gap; or
        // halfway down the screen's right edge
        x: root.edge ? root.width - width - Theme.edgeMargin * 2 : Math.round((root.width - width) / 2)
        y: root.edge ? Math.round((root.height - height) / 2)
            : Theme.barPosition === "bottom" ? root.height - Theme.barExtent - height
            : Theme.barExtent

        width: root.edge ? Theme.fs(44) : root.number ? Theme.fit(140) : Theme.fit(220)
        height: root.edge ? Theme.fs(220) : root.number ? numberRow.implicitHeight + Theme.sp(18)
            : row.implicitHeight + Theme.sp(18)

        // the edge: the icon over a level that fills upward
        Column {
            visible: root.edge
            anchors.fill: parent
            anchors.margins: Theme.spaceM
            spacing: Theme.spaceM

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.icon
                color: Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.fs(8)
                height: parent.height - Theme.fontIconSize - parent.spacing
                radius: Math.min(width / 2, Theme.radiusSmall)
                color: Theme.meterTrack
                border.width: Theme.borderWidth
                border.color: Theme.stroke

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * Math.max(0, Math.min(1, root.level / 100))
                    radius: parent.radius
                    color: root.mode === "volume" && Audio.muted ? Theme.textDisabled : Theme.meterFill
                    Behavior on height { NumberAnimation { duration: Theme.dur(90) } }
                }
            }
        }

        // the number: the icon and the level as a figure
        Row {
            id: numberRow
            visible: root.number
            anchors.centerIn: parent
            spacing: Theme.spaceL

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontHero
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "volume" && Audio.muted ? "Muted" : root.level + "%"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontHero
                font.bold: true
            }
        }

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }

        Row {
            id: row
            visible: !root.edge && !root.number
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
