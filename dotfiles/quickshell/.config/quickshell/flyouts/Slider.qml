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

    implicitHeight: Theme.meterHeight + 10

    function valueAt(px) {
        return Math.round(Math.max(0, Math.min(1, px / width)) * 100)
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


    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (pressed) root.moved(root.valueAt(mouse.x))
        }
    }
}
