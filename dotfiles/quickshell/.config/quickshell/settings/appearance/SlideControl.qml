// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/SlideControl.qml
//
// A number as a slider with its value at the end, in `step`s from
// `minimum` to `maximum`. The value follows the drag; `committed` fires
// once, when it ends, so a write to a file happens once per drag.

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property int value: 0
    property int minimum: 0
    property int maximum: 100
    property int step: 1
    property string suffix: ""
    // shown in the value's place, when the number isn't the whole story
    property string displayValue: ""

    signal committed(int value)

    // the value under the pointer while dragging, else -1
    property int dragged: -1
    readonly property int shown: dragged >= 0 ? dragged : value

    function snap(pct) {
        var raw = minimum + pct / 100 * (maximum - minimum)
        return Math.max(minimum, Math.min(maximum, minimum + Math.round((raw - minimum) / step) * step))
    }

    implicitWidth: Theme.fit(300)
    implicitHeight: Math.max(slider.implicitHeight, label.implicitHeight)
    opacity: enabled ? 1 : 0.4

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: label.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        interactive: root.enabled && root.maximum > root.minimum
        value: root.maximum > root.minimum ? (root.shown - root.minimum) / (root.maximum - root.minimum) * 100 : 0
        onMoved: v => root.dragged = root.snap(v)
        onReleased: {
            if (root.dragged >= 0 && root.dragged !== root.value) root.committed(root.dragged)
            root.dragged = -1
        }
    }

    Text {
        id: label
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fit(56)
        horizontalAlignment: Text.AlignRight
        text: root.dragged < 0 && root.displayValue !== "" ? root.displayValue : root.shown + root.suffix
        color: Theme.textStrong
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
    }
}
