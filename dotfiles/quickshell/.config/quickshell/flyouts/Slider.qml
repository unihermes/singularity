// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Slider.qml
//
// Hand-rolled rather than QtQuick.Controls' Slider: Controls pulls in a
// style plugin and its own theming, which would fight the grayscale ramp
// for the sake of one widget. A track drawn the style's way, and a drag:
//   channel    a level chip, the fill in a dark groove, a bright marker
//   double     a stroked well with the fill inside
//   solid      a thick bar          capsule   a tall pill
//   glass      a thin frosted line with a round accent thumb
//   bevel      a sunken groove and a raised block thumb
//   terminal   a row of blocks      tabbed    ten notches
//   underline  a hairline and a dot
//   ledger     a ruler: an ink box with ticks under it and a pointer
//   corners    dashes and a diamond

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
        // the ruler's ticks and pointer hang below its box
        readonly property int boxH: kind === "ledger" ? Math.round(height * 0.6) : height

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
        // (a thick bar), capsule (a tall pill), ledger (a 2px ink box)
        Rectangle {
            id: well
            visible: ["double", "solid", "capsule", "ledger"].indexOf(track.kind) !== -1
            readonly property int pad: track.kind === "double" ? Theme.borderWidth + 2
                : track.kind === "ledger" ? Theme.borderWidth : 0
            y: track.kind === "ledger" ? 0 : Math.round((parent.height - height) / 2)
            width: parent.width
            height: track.kind === "double" ? Math.round(track.height * 0.75)
                : track.kind === "solid" ? Math.round(track.height * 0.6)
                : track.kind === "capsule" ? track.height
                : track.boxH
            radius: track.kind === "ledger" ? 0
                : track.kind === "double" ? Math.min(height / 2, Theme.radiusInner) : height / 2
            color: track.kind === "double" || track.kind === "ledger" ? "transparent"
                : track.kind === "capsule" ? Theme.overlay : Theme.meterTrack
            border.width: track.kind === "double" || track.kind === "ledger" ? Theme.borderWidth : 0
            border.color: track.kind === "ledger" ? Theme.stroke : track.hot ? Theme.strokeHover : Theme.stroke

            Rectangle {
                x: well.pad
                y: well.pad
                height: well.height - well.pad * 2
                width: track.frac <= 0 ? 0 : Math.max(height, (well.width - well.pad * 2) * track.frac)
                radius: track.kind === "ledger" ? 0 : Math.max(0, well.radius - well.pad)
                color: root.fillColor
            }
        }

        // Ledger's ruler: a tick every tenth under the box, and a pointer
        Repeater {
            model: track.kind === "ledger" ? 11 : 0
            Rectangle {
                required property int index
                x: Math.min(track.width - width, track.width * index / 10)
                y: track.boxH + 2
                width: 1
                height: index % 5 === 0 ? track.height - track.boxH - 2 : Math.round((track.height - track.boxH - 2) / 2)
                color: Theme.stroke
            }
        }

        // a thin line with a thumb: glass (frosted, a round accent thumb
        // that glows), underline (a hairline and a dot), corners (dashes
        // and a diamond), bevel (a sunken groove and a raised block)
        Rectangle {
            id: line
            visible: ["glass", "underline", "corners", "bevel"].indexOf(track.kind) !== -1
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: track.kind === "glass" || track.kind === "bevel" ? 4 : Math.max(2, Theme.borderWidth * 2)
            radius: track.kind === "glass" ? 2 : 0
            color: track.kind === "glass" ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.1))
                : track.kind === "bevel" ? Theme.base
                : track.kind === "corners" ? "transparent" : Theme.border

            Bevel {
                visible: track.kind === "bevel"
                anchors.fill: parent
                raised: false
                light: Theme.bevelLight
                dark: Theme.bevelDark
                thickness: 1
            }

            // Corners' dashes
            Row {
                visible: track.kind === "corners"
                anchors.fill: parent
                spacing: 3
                clip: true
                Repeater {
                    model: track.kind === "corners" ? Math.ceil(line.width / 6) : 0
                    Rectangle { width: 3; height: line.height; color: Theme.muted }
                }
            }

            // the part up to the value, in the level colour
            Rectangle {
                visible: track.kind !== "bevel"
                width: line.width * track.frac
                height: parent.height
                radius: parent.radius
                color: root.fillColor
            }
        }

        Item {
            id: thumb
            visible: line.visible
            readonly property int size: track.kind === "bevel" ? track.height
                : track.kind === "glass" ? Math.round(track.height * 0.85)
                : track.kind === "corners" ? Math.round(track.height * 0.55) : Math.round(track.height * 0.62)
            width: track.kind === "bevel" ? Math.round(size * 0.55) : size
            height: size
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width, track.width * track.frac - width / 2))

            RectangularShadow {
                visible: track.kind === "glass" && Theme.glow
                anchors.fill: parent
                radius: width / 2
                blur: Theme.sp(10)
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7)
            }
            Rectangle {
                anchors.fill: parent
                rotation: track.kind === "corners" ? 45 : 0
                scale: track.kind === "corners" ? 0.75 : 1
                radius: track.kind === "glass" || track.kind === "underline" ? width / 2 : 0
                color: track.kind === "bevel" ? Theme.panel : root.fillColor
                border.width: track.kind === "glass" ? 2 : 0
                border.color: Theme.isLight ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.3)
                Bevel {
                    visible: track.kind === "bevel"
                    anchors.fill: parent
                    raised: true
                    light: Theme.bevelLight
                    dark: Theme.bevelDark
                    thickness: Theme.borderWidth
                }
            }
        }

        // steps: terminal's blocks, tabbed's ten notches
        Row {
            visible: track.kind === "terminal" || track.kind === "tabbed"
            readonly property int count: track.kind === "tabbed" ? 10 : Math.max(8, Math.floor(track.width / 7))
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: track.kind === "tabbed" ? Math.round(track.height * 0.45) : Math.round(track.height * 0.75)
            spacing: 2
            Repeater {
                model: parent.visible ? parent.count : 0
                Rectangle {
                    required property int index
                    readonly property bool lit: track.frac > 0 && (index + 0.5) / parent.count <= track.frac
                    width: (parent.width - parent.spacing * (parent.count - 1)) / parent.count
                    height: parent.height
                    radius: track.kind === "tabbed" ? Math.min(2, Theme.radiusSmall) : 0
                    color: lit ? root.fillColor : track.kind === "tabbed" ? Theme.overlay : Qt.alpha(Theme.muted, 0.45)
                }
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
