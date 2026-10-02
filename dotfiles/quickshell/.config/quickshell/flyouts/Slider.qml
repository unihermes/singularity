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
            visible: !Theme.frameChannel
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.meterHeight + 2
            fraction: root.value / 100
            // the fill follows the pointer; easing it would make it lag
            animated: false
            // the plain stroke at rest, so an empty slider still shows its track
            border.color: drag.pressed || drag.containsMouse ? Theme.strokeHover : Theme.stroke
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
        }

        // channel: a level chip, filled inside a dark groove, with a bright
        // marker at the level
        Rectangle {
            id: level
            visible: Theme.frameChannel
            readonly property int pad: Theme.borderWidth + Theme.channelGrooveWidth
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.switchHeight
            radius: Math.min(height / 2, Theme.radius)
            color: Theme.channelGroove
            border.width: Theme.borderWidth
            border.color: drag.pressed || drag.containsMouse ? Theme.subtext : Theme.channelOuter
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            Rectangle {
                id: levelFill
                x: level.pad
                y: level.pad
                height: level.height - level.pad * 2
                width: (level.width - level.pad * 2) * Math.max(0, Math.min(1, root.value / 100))
                radius: Math.max(0, level.radius - level.pad)
                color: Theme.meterFill
            }

            Rectangle {
                width: Math.max(2, Theme.borderWidth * 3)
                height: level.height - level.pad * 2 - 2
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(level.pad, Math.min(level.width - level.pad - width,
                    levelFill.x + levelFill.width - width / 2))
                radius: 1
                color: Theme.bright
            }
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
                font.weight: Theme.weightBody
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
