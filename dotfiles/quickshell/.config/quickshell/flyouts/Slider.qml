// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Slider.qml
//
// Hand-rolled rather than QtQuick.Controls' Slider: Controls pulls in a
// style plugin and its own theming, which would fight the grayscale ramp
// for the sake of one widget. A track drawn the style's way, and a drag:
//   channel    a level chip, the fill in a dark groove, a bright marker
//   double     a stroked well with the fill inside
//   solid      a thick bar
//   glass      a thin frosted line with a round accent thumb
//   flat       a thin line, an upright rounded thumb

import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: root

    property real value: 0          // 0..100
    // Named points along the slider, as [{ at: 0..100, label }]: each label
    // sits under its point, and clicking it jumps there. A drag that ends
    // near one lands on it.
    property var marks: []
    // false for a read-only level (a battery): no hover, no drag
    property bool interactive: true
    property color fillColor: Theme.meterFill

    // Fired continuously while dragging, so the backend follows the
    // pointer instead of only catching up on release.
    signal moved(real value)
    // The drag let go (or a click ended), for callers that apply on release.
    signal released()
    readonly property bool dragging: drag.pressed

    // The hit area stays the switch's height, so a thin line is still
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

        readonly property string kind: Theme.style
        readonly property real frac: Math.max(0, Math.min(1, root.value / 100))
        readonly property bool hot: drag.pressed || drag.containsMouse

        // channel: a level chip, filled inside a dark groove, with a bright
        // marker at the level
        Rectangle {
            id: level
            visible: track.kind === "channel"
            readonly property int pad: Theme.borderWidth + Theme.channelGrooveWidth
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.switchHeight
            radius: Math.min(height / 2, Theme.radius)
            color: Theme.channelGroove
            border.width: Theme.borderWidth
            border.color: track.hot ? Theme.subtext : Theme.channelOuter
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            Rectangle {
                id: levelFill
                x: level.pad
                y: level.pad
                height: level.height - level.pad * 2
                width: (level.width - level.pad * 2) * track.frac
                radius: Math.max(0, level.radius - level.pad)
                color: root.fillColor
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

        // a well with the fill inside it: double (a stroked well), solid
        // (a thick bar)
        Rectangle {
            id: well
            visible: track.kind === "double" || track.kind === "solid"
            readonly property int pad: track.kind === "double" ? Theme.borderWidth + 2 : 0
            y: Math.round((parent.height - height) / 2)
            width: parent.width
            height: Math.round(track.height * (track.kind === "double" ? 0.75 : 0.6))
            radius: track.kind === "double" ? Math.min(height / 2, Theme.radiusInner) : Theme.pill(height)
            color: track.kind === "double" ? "transparent" : Theme.meterTrack
            border.width: track.kind === "double" ? Theme.borderWidth : 0
            border.color: track.hot ? Theme.strokeHover : Theme.stroke

            Rectangle {
                x: well.pad
                y: well.pad
                height: well.height - well.pad * 2
                width: track.frac <= 0 ? 0 : Math.max(height, (well.width - well.pad * 2) * track.frac)
                radius: Math.max(0, well.radius - well.pad)
                color: root.fillColor
            }
        }

        // a thin line with a thumb: glass (frosted, a round accent thumb
        // that glows), flat (an upright rounded thumb)
        Rectangle {
            id: line
            visible: track.kind === "glass" || track.kind === "flat"
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: track.kind === "glass" ? 4 : Math.max(2, Theme.borderWidth * 2)
            radius: track.kind === "glass" ? 2 : 0
            color: track.kind === "glass" ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.1))
                : track.hot ? Theme.subtext : Theme.muted

            // the part up to the value, in the level colour
            Rectangle {
                width: line.width * track.frac
                height: parent.height
                radius: parent.radius
                color: root.fillColor
            }
        }

        Item {
            id: thumb
            visible: line.visible
            readonly property int size: track.kind === "flat" ? track.height : Math.round(track.height * 0.85)
            width: track.kind === "flat" ? Math.max(6, Math.round(size * 0.4)) : size
            height: size
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, track.width * track.frac - width / 2))

            RectangularShadow {
                visible: track.kind === "glass" && Theme.glow
                anchors.fill: parent
                radius: Theme.pill(width)
                blur: Theme.sp(10)
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7)
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.pill(width)
                color: track.kind === "flat" && track.hot ? Theme.textStrong : root.fillColor
                border.width: track.kind === "glass" ? 2 : 0
                border.color: Theme.isLight ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.3)
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            enabled: root.interactive
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
