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
    // pointer instead of only catching up on release.
    signal moved(real value)
    // The drag let go (or a click ended), for callers that apply on release.
    signal released()
    readonly property bool dragging: drag.pressed

    // No handle: the fill's end is the grip, so the bar alone shows the
    // level. The hit area stays the switch's height so a thin bar is still
    // easy to grab.
    implicitHeight: Theme.switchHeight

    function valueAt(px) {
        return Math.round(Math.max(0, Math.min(1, px / Math.max(1, width))) * 100)
    }

    // a touch taller than a read-only meter, since this one is grabbed
    Meter {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.meterHeight + 2
        fraction: root.value / 100
        // the fill follows the pointer; easing it would make it lag
        animated: false
        border.color: drag.pressed || drag.containsMouse ? Theme.strokeHover : Theme.meterStroke
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
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
