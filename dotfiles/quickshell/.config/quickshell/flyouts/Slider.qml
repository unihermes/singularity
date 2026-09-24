// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Slider.qml
//
// Hand-rolled rather than QtQuick.Controls' Slider: Controls pulls in a
// style plugin and its own theming, which would fight the grayscale ramp
// for the sake of one widget. This is a Meter, and a drag.

import QtQuick
import "../services"

Item {
    id: root

    property real value: 0          // 0..100

    // Fired continuously while dragging, so the backend follows the
    // handle instead of only catching up on release.
    signal moved(real value)
    // The drag let go (or a click ended), for callers that apply on release.
    signal released()
    readonly property bool dragging: drag.pressed

    // The handle: the switch's knob, so the two controls you grab read as
    // one family. The track runs between the handle's centres at either
    // end, so 0 and 100 put it flush with the track's ends, not over them.
    readonly property int knobSize: Theme.switchHeight
    implicitHeight: knobSize

    function valueAt(px) {
        return Math.round(Math.max(0, Math.min(1, (px - knobSize / 2) / Math.max(1, width - knobSize))) * 100)
    }

    // a touch taller than a read-only meter, since this one is grabbed
    Meter {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.meterHeight + 4
        fraction: root.value / 100
        // the fill follows the pointer; easing it would make it lag
        animated: false
        border.color: Theme.strokeHover
    }

    Rectangle {
        x: Math.round((root.width - width) * Math.max(0, Math.min(1, root.value / 100)))
        anchors.verticalCenter: parent.verticalCenter
        width: root.knobSize
        height: width
        radius: Math.min(width / 2, Theme.radiusSmall + 2)
        color: drag.pressed || drag.containsMouse ? Theme.textStrong : Theme.text
        border.width: Theme.borderWidth
        border.color: Theme.base
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed) root.moved(root.valueAt(mouse.x))
        }
        onReleased: root.released()
        onCanceled: root.released()
    }
}
