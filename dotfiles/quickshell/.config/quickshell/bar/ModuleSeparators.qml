// Singularity - Quickshell
// ~/.config/quickshell/bar/ModuleSeparators.qml
//
// The marks between one bar module and the next in a section, as
// Theme.barSeparator says: a thin line, two lines, a dot, a column of three
// dots, or a line capped with a dot at each end.
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
            readonly property string kind: Theme.barSeparator
            readonly property int bw: Math.max(1, Theme.borderWidth)
            // a dot: a little wider than the stroke, so it reads as round
            readonly property int dot: bw + 2
            readonly property int ruleHeight: Math.round(Theme.moduleHeight * 0.55)
            anchors.verticalCenter: parent.verticalCenter
            width: kind === "double" ? bw * 2 + 2 : kind === "dot" ? dot
                : kind === "dots" || kind === "capped" ? bw + 1 : bw
            height: parent.height

            // line, and the two rules of double
            Repeater {
                model: mark.kind === "line" ? 1 : mark.kind === "double" ? 2 : 0
                Rectangle {
                    required property int index
                    x: index * (mark.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: mark.bw
                    height: mark.ruleHeight
                    color: Theme.stroke
                }
            }

            Rectangle {
                visible: mark.kind === "dot"
                anchors.centerIn: parent
                width: mark.dot
                height: width
                radius: width / 2
                color: Theme.muted
            }

            Column {
                visible: mark.kind === "dots"
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 3
                    Rectangle { width: mark.width; height: width; radius: width / 2; color: Theme.muted }
                }
            }

            // capped: a short rule with a dot clear of each end
            Column {
                visible: mark.kind === "capped"
                anchors.centerIn: parent
                spacing: 2
                Rectangle { width: mark.width; height: width; radius: width / 2; color: Theme.muted }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: mark.bw
                    height: Math.round(mark.ruleHeight * 0.75)
                    color: Theme.stroke
                }
                Rectangle { width: mark.width; height: width; radius: width / 2; color: Theme.muted }
            }
        }
    }
}
