// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Spark.qml
//
// A history line graph. Newest sample at the right edge; while history is
// still filling, the line starts partway across rather than stretching a
// few seconds over the whole width. Used by the System window.

import QtQuick
import "../services"

Item {
    id: sp
    // [{ values, color, fill }] drawn in order, so put the one that
    // should sit on top last
    property var series: []
    property real ceiling: 1
    property string caption: ""
    // samples the full width stands for; one per second in the System window
    property int historyLength: 60

    width: parent ? parent.width : 0
    height: Theme.row(44)

    onSeriesChanged: canvas.requestPaint()
    onCeilingChanged: canvas.requestPaint()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.meterTrack
        border.width: Theme.borderWidth
        border.color: Theme.meterStroke
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: Theme.sp(3)
        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var step = w / (sp.historyLength - 1)
            for (var s = 0; s < sp.series.length; s++) {
                var vals = sp.series[s].values
                if (!vals || vals.length < 2) continue
                var x0 = w - (vals.length - 1) * step
                ctx.beginPath()
                for (var i = 0; i < vals.length; i++) {
                    var y = h - Math.min(1, vals[i] / sp.ceiling) * h
                    if (i === 0) ctx.moveTo(x0, y)
                    else ctx.lineTo(x0 + i * step, y)
                }
                ctx.strokeStyle = sp.series[s].color
                ctx.lineWidth = 1.5
                ctx.lineJoin = "round"
                ctx.stroke()
                if (sp.series[s].fill) {
                    ctx.lineTo(w, h)
                    ctx.lineTo(x0, h)
                    ctx.closePath()
                    ctx.globalAlpha = 0.14
                    ctx.fillStyle = sp.series[s].color
                    ctx.fill()
                    ctx.globalAlpha = 1
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceS
        text: sp.caption

        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }
}
