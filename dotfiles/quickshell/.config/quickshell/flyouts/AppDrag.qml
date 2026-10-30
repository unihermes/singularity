// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AppDrag.qml
//
// Lays over an app's row (the volume flyout's, the Audio page's) so it can
// be dragged onto a channel (ChannelDrop): a chip with the app's icon and
// name follows the pointer while it's held. A click still reaches what's
// under it; only a drag past the threshold takes over.

import QtQuick
import "../services"

Item {
    id: root

    // every stream of the app, as Audio.playingApps has them
    property var nodes: []
    property string name: ""
    property string icon: ""

    DragHandler {
        id: handler
        target: chip
        onActiveChanged: if (!active) {
            chip.Drag.drop()
            chip.x = 0
            chip.y = 0
        }
    }

    Rectangle {
        id: chip
        visible: handler.active
        z: 100
        width: chipRow.implicitWidth + Theme.spaceM * 2
        height: Theme.rowHeight
        radius: Theme.radiusInner
        color: Theme.overlay
        border.width: Theme.borderWidth
        border.color: Theme.accent
        Drag.active: handler.active
        Drag.keys: ["singularity-app"]
        Drag.source: root
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spaceS
            Image {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fontBody
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                source: root.icon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.name
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }
}
