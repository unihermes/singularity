// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutSliderRow.qml
//
// A number setting as a slider: the label and the value with its unit on
// one line, the slider under it. Drags straight to any value where a
// stepper takes a click per unit -- for the ranges with twenty-odd steps
// (bar height, opacity, font size) that's the difference.
//
// `step` snaps the value (opacity moves in fives); the slider itself is
// Slider.qml's 0..100, mapped onto minimum..maximum here.

import QtQuick
import "../services"

Column {
    id: root

    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 100
    property real step: 1
    property string suffix: ""
    property bool enabled: true

    // fired while dragging, already snapped and clamped
    signal moved(real value)

    width: parent ? parent.width : 0
    spacing: 0
    opacity: enabled ? 1 : 0.5

    Item {
        width: parent.width
        height: Theme.rowHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.value + root.suffix
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
    }

    Slider {
        width: parent.width
        enabled: root.enabled
        value: (root.value - root.minimum) / Math.max(1, root.maximum - root.minimum) * 100
        onMoved: pct => {
            var v = root.minimum + (root.maximum - root.minimum) * pct / 100
            v = Math.round(v / root.step) * root.step
            v = Math.max(root.minimum, Math.min(root.maximum, v))
            if (v !== root.value) root.moved(v)
        }
    }
}
