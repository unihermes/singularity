// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Spectrum.qml
//
// The audio spectrum (Visualizer) in the meter colour, drawn per `style`
// (Theme.vizStyle): mirror, rise, dots or one line through every band. At
// rest in the same look while nothing sounds. No easing, so it redraws
// only on cava's 20 frames a second.

import QtQuick
import QtQuick.Shapes
import "../services"

Row {
    id: root

    property string style: Theme.vizStyle
    property real bandW: Theme.barFs(3)
    property real bandH: Theme.moduleHeight - 10

    function level(i) {
        return Visualizer.playing ? Math.max(0, Math.min(1, (Visualizer.bars[i] || 0) / 100)) : 0
    }

    Repeater {
        model: root.style === "line" ? 0 : Visualizer.barCount

        Item {
            id: band
            required property int index
            readonly property real v: root.level(index)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.bandW
            implicitHeight: root.bandH

            Rectangle {
                visible: root.style !== "dots"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: root.style === "mirror" ? parent.verticalCenter : undefined
                anchors.bottom: root.style === "rise" ? parent.bottom : undefined
                width: root.bandW
                radius: root.style === "rise" ? Math.min(1, Theme.radiusSmall) : Theme.pill(root.bandW)
                height: Math.max(3, parent.height * band.v)
                color: Theme.meterFill
            }

            // four dots from the bottom, lit up to the band's level
            Column {
                visible: root.style === "dots"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.max(1, (root.bandH - root.bandW * 4) / 3)
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: root.bandW
                        height: root.bandW
                        radius: Theme.pill(width)
                        color: Theme.meterFill
                        // index 0 is the top dot; the bottom one is always lit
                        opacity: band.v * 4 >= 3 - index || index === 3 ? 1 : 0.18
                    }
                }
            }
        }
    }

    // the line style: one stroke through every band's level
    Shape {
        visible: root.style === "line"
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Visualizer.barCount * (root.bandW + root.spacing) - root.spacing
        implicitHeight: root.bandH
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.meterFill
            strokeWidth: Math.max(1.5, Theme.borderWidth * 1.5)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: {
                    var pts = [], n = Visualizer.barCount
                    var w = root.style === "line" ? n * (root.bandW + root.spacing) - root.spacing : 0
                    var h = root.bandH
                    for (var i = 0; i < n; i++)
                        pts.push(Qt.point(n > 1 ? i * w / (n - 1) : 0, h - 1 - root.level(i) * (h - 2)))
                    return pts
                }
            }
        }
    }
}
