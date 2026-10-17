// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Shadow.qml
//
// The shadow under a panel or chip, when Theme.shadow asks for one: a
// blurred drop shadow. Put it inside the shape it shadows; it fills its parent and draws behind
// it. `opaque` false hides it, since a shadow showing through a
// see-through ground reads as a smudge inside it.

import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: root

    property real radius: 0
    property bool opaque: true

    anchors.fill: parent
    z: -1
    visible: Theme.shadow !== "none" && opaque

    RectangularShadow {
        anchors.fill: parent
        radius: root.radius
        offset.y: Theme.sp(3)
        blur: Theme.sp(14)
        color: Qt.rgba(0, 0, 0, Theme.isLight ? 0.22 : 0.55)
    }
}
