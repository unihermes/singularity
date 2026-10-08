// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Shadow.qml
//
// The shadow under a panel or chip, as Theme.shadow says:
//   soft  a blurred drop shadow
//   hard  a solid copy of the shape, offset down and right -- in the ink
//         colour on a light look, the stroke colour on a dark one, where
//         black wouldn't show against the ground
// Put it inside the shape it shadows; it fills its parent and draws behind
// it. `opaque` false hides it, since a shadow showing through a
// see-through ground reads as a smudge inside it.

import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: root

    property real radius: 0
    property bool opaque: true
    // how far a hard shadow sits down and right
    property int offset: Theme.shadowOffset

    anchors.fill: parent
    z: -1
    visible: Theme.shadow !== "none" && opaque

    RectangularShadow {
        visible: Theme.shadow === "soft"
        anchors.fill: parent
        radius: root.radius
        offset.y: Theme.sp(3)
        blur: Theme.sp(14)
        color: Qt.rgba(0, 0, 0, Theme.isLight ? 0.22 : 0.55)
    }

    Rectangle {
        visible: Theme.shadow === "hard"
        x: root.offset
        y: root.offset
        width: parent.width
        height: parent.height
        radius: root.radius
        color: Theme.isLight ? Theme.textStrong : Theme.stroke
    }
}
