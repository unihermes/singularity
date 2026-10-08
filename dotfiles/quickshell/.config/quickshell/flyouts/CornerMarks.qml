// Singularity - Quickshell
// ~/.config/quickshell/flyouts/CornerMarks.qml
//
// The Corners style's frame: an L at each corner of its parent and nothing
// between them. Chips and controls take short thin marks, panels the
// longer ones (Theme.cornerLarge), lit marks the accent.

import QtQuick
import "../services"

Item {
    id: root

    property int length: Theme.cornerSmall
    property int thickness: Theme.borderWidth
    property color color: Theme.muted

    anchors.fill: parent

    Repeater {
        // [right?, bottom?] for each corner
        model: [[0, 0], [1, 0], [0, 1], [1, 1]]

        Item {
            id: corner
            required property var modelData
            anchors.fill: parent

            Rectangle {
                x: corner.modelData[0] ? root.width - width : 0
                y: corner.modelData[1] ? root.height - height : 0
                width: root.length
                height: root.thickness
                color: root.color
            }
            Rectangle {
                x: corner.modelData[0] ? root.width - width : 0
                y: corner.modelData[1] ? root.height - height : 0
                width: root.thickness
                height: root.length
                color: root.color
            }
        }
    }
}
