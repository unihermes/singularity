// Singularity - Quickshell
// ~/.config/quickshell/bar/ModuleSeparators.qml
//
// The marks between one bar module and the next in a section, as
// Theme.barSeparator says: a thin line or a dot.
// Each sits in the middle of the gap after a visible module that has a
// visible one after it, and follows the module as it slides.

import QtQuick
import "../services"

Repeater {
    id: root

    // the section's slots Item (shell.qml): its `order` and itemFor()
    required property Item slots

    model: Theme.barSeparator === "none" ? [] : slots.order

    Item {
        id: sep
        required property string modelData
        required property int index
        readonly property Item module: root.slots.itemFor(modelData)
        // a visible module comes after this one in the section
        readonly property bool between: {
            if (!module || !module.visible) return false
            var o = root.slots.order
            for (var i = index + 1; i < o.length; i++) {
                var it = root.slots.itemFor(o[i])
                if (it && it.visible) return true
            }
            return false
        }

        visible: between
        x: module ? Math.round(module.x + module.width + Theme.moduleSpacing / 2 - width / 2) : 0
        width: mark.width
        height: root.slots.height

        Item {
            id: mark
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, Theme.borderWidth) + (Theme.barSeparator === "dot" ? 2 : 0)
            height: parent.height

            Rectangle {
                visible: Theme.barSeparator === "line"
                anchors.centerIn: parent
                width: Math.max(1, Theme.borderWidth)
                height: Math.round(Theme.moduleHeight * 0.55)
                color: Theme.stroke
            }

            Rectangle {
                visible: Theme.barSeparator === "dot"
                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: Theme.muted
            }
        }
    }
}
