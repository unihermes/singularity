// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Switch.qml
//
// The one on/off control (named choices are FlyoutSegmented).
//
// Each style draws its own (Theme.style):
//   channel    no knob: a dark well, filled with the accent inside its
//              groove when on
//   double     a stroked box with a square knob that turns accent
//   solid      a fat pill with a white knob
//   glass      a frosted track, the knob glowing when on
//   flat       a pill outlined in the text colour, round knob; on, the
//              accent with a white knob
//
// `interactive: false` for a switch inside a row that takes the click
// itself (FlyoutAction), so the whole row is the target.

import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool interactive: true
    signal toggled()

    readonly property string kind: Theme.style
    readonly property bool hovered: mouse.containsMouse
    readonly property int h: Theme.switchHeight
    // the fill a lit switch takes
    readonly property color onFill: Theme.meterFill

    implicitWidth: kind === "solid" ? Theme.row(34)
        : kind === "flat" ? Theme.row(32)
        : Theme.switchWidth
    implicitHeight: kind === "solid" ? Theme.row(20) : h
    opacity: enabled ? 1 : 0.5

    // --- tracks with a knob: every style but channel
    readonly property bool knobbed: kind !== "channel"

    Rectangle {
        visible: root.knobbed
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: parent.height
        radius: root.kind === "double" ? Math.min(height / 2, Theme.radiusInner) : Theme.pill(height)
        color: {
            switch (root.kind) {
            case "double": return "transparent"
            case "glass": return root.checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                : Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
            case "flat": return root.checked ? root.onFill : "transparent"
            default: return root.checked ? root.onFill : Theme.overlay
            }
        }
        border.width: root.kind === "double" || root.kind === "glass" ? Theme.borderWidth
            : root.kind === "flat" && !root.checked ? root.flatLine : 0
        border.color: root.kind === "glass" ? Theme.stroke
            : root.kind === "flat" ? (root.hovered ? Theme.textStrong : Theme.text)
            : root.checked ? Theme.accent : root.hovered ? Theme.strokeHover : Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

        RectangularShadow {
            visible: root.kind === "glass" && root.checked && Theme.glow
            anchors.fill: parent
            z: -1
            radius: parent.radius
            blur: Theme.sp(10)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
        }
    }

    // Flat's outline, the knob's gap inside it
    readonly property int flatLine: Math.max(2, Theme.borderWidth * 2)

    Rectangle {
        visible: root.knobbed
        readonly property int inset: root.kind === "solid" ? 2
            : root.kind === "flat" ? root.flatLine + 2 : Math.max(2, Math.round(root.h / 5))
        width: root.height - inset * 2
        height: width
        radius: root.kind === "double" ? Math.min(width / 2, Theme.radiusSmall) : Theme.pill(width)
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - inset : inset
        color: {
            switch (root.kind) {
            case "double": return root.checked ? Theme.accent : Theme.muted
            case "solid": return "#ffffff"
            case "flat": return root.checked ? "#ffffff" : root.hovered ? Theme.textStrong : Theme.text
            default: return root.checked ? "#ffffff" : Theme.muted
            }
        }
        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

        RectangularShadow {
            visible: root.kind === "solid"
            anchors.fill: parent
            z: -1
            radius: parent.radius
            offset.y: 1
            blur: 3
            color: Qt.rgba(0, 0, 0, 0.35)
        }
    }

    // --- channel: no knob, the whole switch fills with the accent when on
    Rectangle {
        visible: root.kind === "channel"
        anchors.fill: parent
        radius: Math.min(height / 2, Theme.radius)
        color: root.checked ? Theme.accent : Theme.channelGroove
        border.width: Theme.borderWidth
        border.color: root.hovered ? Theme.subtext : Theme.channelOuter
        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

        // the inner line when off, a dark groove round the fill when on
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            radius: Math.max(0, parent.radius - Theme.borderWidth)
            color: "transparent"
            border.width: root.checked ? Theme.channelGrooveWidth : Theme.borderWidth
            border.color: root.checked ? Theme.channelGroove : Theme.channelInner
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        visible: root.interactive
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
