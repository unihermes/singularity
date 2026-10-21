// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChipLine.qml
//
// Chips sharing one line in equal widths: a flyout's tools, its windows,
// its way out. Each entry is { icon, text, act }; a click emits picked(act).

import QtQuick
import "../services"

Row {
    id: root

    property var chips: []
    signal picked(string act)

    width: parent ? parent.width : 0
    spacing: Theme.spaceS

    Repeater {
        model: root.chips

        FlyoutChip {
            required property var modelData
            width: (root.width - root.spacing * (root.chips.length - 1)) / root.chips.length
            icon: modelData.icon
            text: modelData.text
            onClicked: root.picked(modelData.act)
        }
    }
}
