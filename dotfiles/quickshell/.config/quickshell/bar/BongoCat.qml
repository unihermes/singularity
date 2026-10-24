// Singularity - Quickshell
// ~/.config/quickshell/bar/BongoCat.qml
//
// The Bongo Cat for its bar module: a cat's head over a desk line, its
// paws raised, one coming down on the desk with each key press (Bongo),
// left and right in turn. Drawn in the icon colour at the icon's scale.

import QtQuick
import QtQuick.Shapes
import "../services"

Item {
    id: root

    property color color: Theme.text
    // drawn on a 32 by 22 grid, scaled to the bar's icons
    readonly property real s: Theme.iconSize / 16

    width: 32 * s
    height: 22 * s

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.5 * root.s
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            // the head, ears and all, from the desk round to the desk
            startX: 5 * root.s; startY: 21 * root.s
            PathLine { x: 6.5 * root.s; y: 12 * root.s }
            PathLine { x: 8.5 * root.s; y: 4 * root.s }
            PathLine { x: 13 * root.s; y: 8.5 * root.s }
            PathQuad { x: 19 * root.s; y: 8.5 * root.s; controlX: 16 * root.s; controlY: 7.5 * root.s }
            PathLine { x: 23.5 * root.s; y: 4 * root.s }
            PathLine { x: 25.5 * root.s; y: 12 * root.s }
            PathLine { x: 27 * root.s; y: 21 * root.s }
        }
        ShapePath {
            // the desk
            strokeColor: root.color
            strokeWidth: 1.5 * root.s
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1 * root.s; startY: 21 * root.s
            PathLine { x: 31 * root.s; y: 21 * root.s }
        }
    }

    // eyes
    Repeater {
        model: [12, 20]
        Rectangle {
            required property real modelData
            x: (modelData - 1) * root.s
            y: 13 * root.s
            width: 2 * root.s
            height: 2 * root.s
            radius: width / 2
            color: root.color
        }
    }

    // paws: up, or down on the desk
    Repeater {
        model: [true, false]
        Rectangle {
            required property bool modelData
            readonly property bool isDown: Bongo.down && Bongo.leftPaw === modelData
            x: (modelData ? 6 : 21) * root.s
            y: (isDown ? 17 : 13) * root.s
            width: 5 * root.s
            height: 4 * root.s
            radius: 2 * root.s
            color: root.color
        }
    }
}
