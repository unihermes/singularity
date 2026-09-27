// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FrameCorners.qml
//
// The "corners" frame: an L-shaped mark at each corner and nothing along
// the edges between them, like a viewfinder's brackets. The caller
// positions it, as with Bevel.

import QtQuick
import "../services"

Item {
    id: root

    property color color: Theme.stroke
    property int thickness: Theme.borderWidth
    // how far each arm runs along its edge
    property int length: Theme.sp(12)

    Repeater {
        model: 4

        Item {
            required property int index
            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index >= 2
            x: atRight ? root.width - width : 0
            y: atBottom ? root.height - height : 0
            width: Math.min(root.length, root.width / 2)
            height: Math.min(root.length, root.height / 2)

            Rectangle {
                y: parent.atBottom ? parent.height - height : 0
                width: parent.width
                height: root.thickness
                color: root.color
            }
            Rectangle {
                x: parent.atRight ? parent.width - width : 0
                width: root.thickness
                height: parent.height
                color: root.color
            }
        }
    }
}
