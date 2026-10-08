// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Switch.qml
//
// The one on/off control: Quick Actions' toggles and every boolean on the
// Settings pages. A choice between two values that reads as a state (on,
// off) is this; a choice between named options is a FlyoutSegmented.
//
// Each style draws its own (Theme.style):
//   channel    no knob: a dark well, filled with the accent inside its
//              groove when on
//   double     a stroked box with a square knob that turns accent
//   solid      a fat pill with a white knob
//   capsule    a pill; with the style's labels option it says On or Off
//   glass      a frosted track, the knob glowing when on
//   bevel      a sunken checkbox with a tick
//   terminal   [x] and [ ] in the text face
//   underline  a thin rail with a round knob
//   tabbed     a two-way Off | On
//   ledger     an ink box stamped ON or OFF
//   corners    a bracketed square knob
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

    implicitWidth: kind === "bevel" ? h
        : kind === "terminal" ? termText.implicitWidth
        : kind === "tabbed" ? twoWay.implicitWidth
        : kind === "ledger" ? Math.max(Theme.row(34), stamp.implicitWidth + Theme.spaceL)
        : kind === "capsule" && Theme.opt("labels") ? Theme.row(46)
        : kind === "solid" ? Theme.row(34)
        : Theme.switchWidth
    implicitHeight: kind === "solid" ? Theme.row(20) : h
    opacity: enabled ? 1 : 0.5

    // --- tracks with a knob: double, solid, capsule, glass, underline, corners
    readonly property bool knobbed: ["double", "solid", "capsule", "glass", "underline", "corners"].indexOf(kind) !== -1
        && !(kind === "capsule" && Theme.opt("labels"))

    Rectangle {
        id: track
        visible: root.knobbed
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.kind === "underline" ? Math.max(4, Theme.borderWidth * 3) : parent.height
        radius: root.kind === "double" ? Math.min(height / 2, Theme.radiusInner)
            : root.kind === "corners" ? 0 : height / 2
        color: {
            switch (root.kind) {
            case "double": return "transparent"
            case "corners": return root.checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : "transparent"
            case "glass": return root.checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                : Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
            case "underline": return root.checked ? Qt.rgba(root.onFill.r, root.onFill.g, root.onFill.b, 0.45) : Theme.border
            default: return root.checked ? root.onFill : Theme.overlay
            }
        }
        border.width: root.kind === "double" || root.kind === "glass" ? Theme.borderWidth : 0
        border.color: root.kind === "glass" ? Theme.stroke
            : root.checked ? Theme.accent : root.hovered ? Theme.strokeHover : Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        RectangularShadow {
            visible: root.kind === "glass" && root.checked && Theme.glow
            anchors.fill: parent
            z: -1
            radius: parent.radius
            blur: Theme.sp(10)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
        }

        CornerMarks {
            visible: root.kind === "corners"
            color: root.checked ? Theme.accent : root.hovered ? Theme.textStrong : Theme.muted
        }
    }

    Rectangle {
        id: knob
        visible: root.knobbed
        readonly property int inset: root.kind === "underline" ? 0
            : root.kind === "solid" ? 2 : Math.max(2, Math.round(root.h / 5))
        width: root.kind === "underline" ? Math.round(root.h * 0.85) : root.height - inset * 2
        height: width
        radius: root.kind === "double" ? Math.min(width / 2, Theme.radiusSmall)
            : root.kind === "corners" ? 0 : width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - inset : inset
        color: {
            switch (root.kind) {
            case "double": case "corners": return root.checked ? Theme.accent : Theme.muted
            case "underline": return root.checked ? root.onFill : Theme.subtext
            case "solid": return "#ffffff"
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
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

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

    // --- capsule with labels: a pill that says what it is
    Rectangle {
        visible: root.kind === "capsule" && Theme.opt("labels")
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.onFill : Theme.overlay
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceS
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(root.h * 0.4); height: width; radius: width / 2
                color: root.checked ? Theme.textOnMeter : Theme.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.checked ? "On" : "Off"
                color: root.checked ? Theme.textOnMeter : Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }
    }

    // --- bevel: a sunken checkbox
    Item {
        visible: root.kind === "bevel"
        anchors.fill: parent

        Rectangle { anchors.fill: parent; color: Theme.base }
        Bevel {
            anchors.fill: parent
            raised: false
            light: Theme.bevelLight
            dark: Theme.bevelDark
            thickness: Theme.borderWidth
        }
        Text {
            visible: root.checked
            anchors.centerIn: parent
            text: "󰄬"
            color: Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Math.round(root.h * 0.85)
        }
    }

    // --- terminal: [x] / [ ]
    Text {
        id: termText
        visible: root.kind === "terminal"
        anchors.verticalCenter: parent.verticalCenter
        text: root.checked ? "[x]" : "[ ]"
        color: root.checked ? Theme.accent : root.hovered ? Theme.textStrong : Theme.muted
        font.family: Theme.fontText
        font.weight: Theme.weightStrong
        font.pixelSize: Theme.fontBody
    }

    // --- tabbed: Off | On, the state's half lit
    Rectangle {
        id: twoWay
        visible: root.kind === "tabbed"
        anchors.fill: parent
        implicitWidth: halves.implicitWidth + Theme.borderWidth * 2
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: root.hovered ? Theme.strokeHover : Theme.stroke
        clip: true

        Row {
            id: halves
            anchors.fill: parent
            anchors.margins: Theme.borderWidth
            Repeater {
                model: [false, true]
                Rectangle {
                    required property bool modelData
                    readonly property bool lit: modelData === root.checked
                    width: halfText.implicitWidth + Theme.spaceM * 2
                    height: parent.height
                    color: lit ? (modelData ? root.onFill : Theme.overlay) : "transparent"
                    Text {
                        id: halfText
                        anchors.centerIn: parent
                        text: parent.modelData ? "On" : "Off"
                        color: parent.lit ? (parent.modelData ? Theme.textOnMeter : Theme.textStrong) : Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }
                }
            }
        }
    }

    // --- ledger: an ink box stamped with the state
    Rectangle {
        visible: root.kind === "ledger"
        anchors.fill: parent
        color: root.checked ? Theme.accent : "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.stroke
        Text {
            id: stamp
            anchors.centerIn: parent
            text: root.checked ? "ON" : "OFF"
            color: root.checked ? Theme.textOnAccent : Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontCaption
            font.letterSpacing: 1
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
