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
//
// `live: false` holds the value back until the drag lets go, with the
// fill and readout following the pointer meanwhile. For Font Size: every
// step rescales the whole panel, which moved the slider out from under the
// pointer mid-drag, so each step landed somewhere other than where you
// were aiming.

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
    property bool live: true
    // named points under the slider (Slider.qml's `marks`), in this row's units
    property var marks: []

    // fired while dragging (on release when !live), already snapped and clamped
    signal moved(real value)

    // the value mid-drag when !live; NaN otherwise
    property real pending: NaN
    readonly property real shown: isNaN(pending) ? value : pending

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
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // a named point reads as its name
            text: {
                var m = root.marks.find(m => m.at === root.shown)
                return m ? m.label : root.shown + root.suffix
            }
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
    }

    Slider {
        width: parent.width
        enabled: root.enabled
        marks: root.marks.map(m => ({
            at: (m.at - root.minimum) / Math.max(1, root.maximum - root.minimum) * 100,
            label: m.label,
        }))
        value: (root.shown - root.minimum) / Math.max(1, root.maximum - root.minimum) * 100
        onMoved: pct => {
            var v = root.minimum + (root.maximum - root.minimum) * pct / 100
            v = Math.round(v / root.step) * root.step
            v = Math.max(root.minimum, Math.min(root.maximum, v))
            if (!root.live) root.pending = v
            else if (v !== root.value) root.moved(v)
        }
        onReleased: {
            var v = root.pending
            root.pending = NaN
            if (!isNaN(v) && v !== root.value) root.moved(v)
        }
    }
}
