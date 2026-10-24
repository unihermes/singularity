// Singularity - Quickshell
// ~/.config/quickshell/desktop/Ring.qml
//
// A three-quarter ring gauge with its value in the middle and its label
// under the gap, for the stats widget.

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real fraction: 0
    property string value: ""
    property string label: ""
    property color fill: "white"
    property color track: Qt.rgba(1, 1, 1, 0.16)
    property color ink: "white"
    property color inkDim: Qt.rgba(1, 1, 1, 0.62)
    property string font: ""
    property real thickness: Math.max(3, Math.round(width * 0.09))

    height: width

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2; radiusY: radiusX
                startAngle: 135; sweepAngle: 270
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.fill
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2; radiusY: radiusX
                startAngle: 135
                sweepAngle: 270 * Math.max(0.005, Math.min(1, root.fraction))
                Behavior on sweepAngle { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.value
        color: root.ink
        font.family: root.font
        font.weight: Font.DemiBold
        font.pixelSize: Math.round(root.width * 0.24)
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Math.round(root.width * 0.04)
        text: root.label
        color: root.inkDim
        font.family: root.font
        font.weight: Font.Medium
        font.pixelSize: Math.round(root.width * 0.15)
    }
}
