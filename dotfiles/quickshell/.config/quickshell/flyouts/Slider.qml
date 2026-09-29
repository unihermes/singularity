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
    // Named points along the slider, as [{ at: 0..100, label }]: each label
    // sits under its point, and clicking it jumps there. A drag that ends
    // near one lands on it.
    property var marks: []

    // Fired continuously while dragging, so the backend follows the
    // pointer instead of only catching up on release.
    signal moved(real value)
    // The drag let go (or a click ended), for callers that apply on release.
    signal released()
    readonly property bool dragging: drag.pressed

    // No handle: the fill's end is the grip, so the bar alone shows the
    // level. The hit area stays the switch's height so a thin bar is still
    // easy to grab.
    implicitHeight: track.height + (marks.length > 0 ? markRow.height : 0)

    function valueAt(px) {
        var v = Math.max(0, Math.min(1, px / Math.max(1, width))) * 100
        for (var i = 0; i < marks.length; i++)
            if (Math.abs(v - marks[i].at) < 3) return marks[i].at
        return Math.round(v)
    }

    Item {
        id: track
        width: parent.width
        height: Theme.switchHeight

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

    // the end labels line up with the ends rather than hanging past them
    Item {
        id: markRow
        visible: root.marks.length > 0
        anchors.top: track.bottom
        width: parent.width
        height: Theme.fontCaption + Theme.spaceS

        Repeater {
            model: root.marks

            Text {
                id: mark
                required property var modelData
                readonly property bool current: Math.round(root.value) === modelData.at
                x: Math.max(0, Math.min(markRow.width - width,
                    markRow.width * modelData.at / 100 - width / 2))
                text: modelData.label
                color: current || markHover.containsMouse ? Theme.text : Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontCaption

                MouseArea {
                    id: markHover
                    anchors.fill: parent
                    anchors.margins: -Theme.spaceS / 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.moved(mark.modelData.at)
                        root.released()
                    }
                }
            }
        }
    }
}
