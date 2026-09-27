// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Swatches.qml
//
// A look's palette as a strip of colour blocks, beside its name in a
// dropdown. Empty, it takes no width.

import QtQuick
import "../services"

Row {
    property var colours: []
    spacing: 0

    Repeater {
        model: parent.colours

        Rectangle {
            required property var modelData
            width: Theme.fs(7)
            height: Theme.fs(12)
            color: modelData
        }
    }
}
