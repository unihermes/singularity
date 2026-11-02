import QtQuick
import QtQuick.Shapes

// Slot fills share the enclosing frame's cut corners as well as its radii.
Item {
    id: root
    property real leftCut: 0
    property real rightCut: 0
    property alias color: rounded.color
    property alias radius: rounded.radius
    property alias topLeftRadius: rounded.topLeftRadius
    property alias topRightRadius: rounded.topRightRadius
    property alias bottomLeftRadius: rounded.bottomLeftRadius
    property alias bottomRightRadius: rounded.bottomRightRadius
    property alias border: rounded.border
    readonly property bool cut: leftCut > 0 || rightCut > 0

    Rectangle {
        id: rounded
        anchors.fill: parent
        visible: !root.cut
    }
    Shape {
        anchors.fill: parent
        visible: root.cut
        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            PathSvg {
                path: "M 0 0 H " + (root.width - root.rightCut)
                    + " L " + root.width + " " + root.rightCut
                    + " V " + root.height + " H " + root.leftCut
                    + " L 0 " + (root.height - root.leftCut) + " Z"
            }
        }
    }
}
