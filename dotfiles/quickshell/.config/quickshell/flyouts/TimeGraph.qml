// Singularity - Quickshell
// ~/.config/quickshell/flyouts/TimeGraph.qml
//
// A line over clock time, from `from` to `to` (ms) across the full width,
// with hour labels along the foot. Optional faint bars under it (rain
// chance), shaded spans behind it (charging) and value labels over it.
// A gap of more than `breakAfter` between two points breaks the line.
// Used by the Battery and Weather flyouts and the weather widget.

import QtQuick
import "../services"

Item {
    id: tg

    property real from: 0
    property real to: 1
    // [{ t, v }], oldest first
    property var points: []
    property real floor: 0
    property real ceiling: 1
    property bool fill: true
    // [{ t, v }] with v 0..1, drawn up from the foot an hour wide
    property var bars: []
    // [{ t0, t1 }]
    property var spans: []
    // [{ t, v, text }]: a label just over the line at t
    property var labels: []
    // whole hours along the foot, at most about maxTicks of them, a step of
    // 1, 2, 3, 4, 6 or 12 hours
    property bool showTicks: true
    property int maxTicks: 6
    readonly property var ticks: {
        if (!showTicks || to <= from) return []
        var hours = (to - from) / 3600000
        var step = [1, 2, 3, 4, 6, 12].find(n => hours / n <= maxTicks) || 24
        var first = new Date(from)
        first.setMinutes(0, 0, 0)
        var t = first.getTime() + 3600000
        var out = []
        for (; t < to; t += 3600000)
            if (new Date(t).getHours() % step === 0) out.push(t)
        return out
    }
    property string tickFormat: Theme.hours("HH")
    property real breakAfter: 15 * 60000

    property color lineColor: Theme.accent
    property color barColor: Theme.subtext
    property color spanColor: Theme.good
    property color textColor: Theme.textStrong
    property color dimColor: Theme.subtext
    property string fontFamily: Theme.fontText
    property int labelSize: Theme.fontCaption
    // no box of its own, for a graph inside a card that already has one
    property bool bare: false

    width: parent ? parent.width : 0
    height: Theme.row(64)

    readonly property int footHeight: ticks.length > 0 ? labelSize + Theme.spaceXs : 0
    // room over the highest point for its label
    readonly property int headHeight: labels.length > 0 ? labelSize + Theme.spaceXs : 0

    function xOf(t) { return canvas.x + (t - from) / Math.max(1, to - from) * canvas.width }
    function yOf(v) {
        return canvas.y + canvas.height - Math.max(0, Math.min(1, (v - floor) / Math.max(1e-6, ceiling - floor))) * canvas.height
    }

    onPointsChanged: canvas.requestPaint()
    onBarsChanged: canvas.requestPaint()
    onSpansChanged: canvas.requestPaint()
    onFromChanged: canvas.requestPaint()
    onToChanged: canvas.requestPaint()
    onFloorChanged: canvas.requestPaint()
    onCeilingChanged: canvas.requestPaint()
    onLineColorChanged: canvas.requestPaint()

    Rectangle {
        visible: !tg.bare
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.meterTrack
        border.width: Theme.borderWidth
        border.color: Theme.meterStroke
    }

    Canvas {
        id: canvas
        readonly property int inset: tg.bare ? 0 : Theme.sp(3)
        x: inset
        y: inset + tg.headHeight
        width: tg.width - inset * 2
        height: tg.height - inset * 2 - tg.headHeight - tg.footHeight
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var span = Math.max(1, tg.to - tg.from)
            var xOf = t => (t - tg.from) / span * w
            var yOf = v => h - Math.max(0, Math.min(1, (v - tg.floor) / Math.max(1e-6, tg.ceiling - tg.floor))) * h

            ctx.globalAlpha = 0.12
            ctx.fillStyle = String(tg.spanColor)
            for (var s = 0; s < tg.spans.length; s++) {
                var a = Math.max(0, xOf(tg.spans[s].t0)), b = Math.min(w, xOf(tg.spans[s].t1))
                if (b > a) ctx.fillRect(a, 0, b - a, h)
            }
            ctx.globalAlpha = 0.25
            ctx.fillStyle = String(tg.barColor)
            var bw = Math.max(1, w * 3600000 / span - 2)
            for (var i = 0; i < tg.bars.length; i++) {
                var bh = Math.max(0, Math.min(1, tg.bars[i].v)) * h
                if (bh > 0) ctx.fillRect(xOf(tg.bars[i].t) - bw / 2, h - bh, bw, bh)
            }
            ctx.globalAlpha = 1

            // runs of points without a gap, each its own line
            var runs = [], run = []
            for (var k = 0; k < tg.points.length; k++) {
                var p = tg.points[k]
                if (run.length > 0 && p.t - run[run.length - 1].t > tg.breakAfter) { runs.push(run); run = [] }
                run.push(p)
            }
            if (run.length > 0) runs.push(run)

            ctx.strokeStyle = String(tg.lineColor)
            ctx.fillStyle = String(tg.lineColor)
            ctx.lineWidth = 1.5
            ctx.lineJoin = "round"
            for (var r = 0; r < runs.length; r++) {
                var pts = runs[r]
                if (pts.length < 2) continue
                ctx.beginPath()
                for (var j = 0; j < pts.length; j++) {
                    if (j === 0) ctx.moveTo(xOf(pts[j].t), yOf(pts[j].v))
                    else ctx.lineTo(xOf(pts[j].t), yOf(pts[j].v))
                }
                ctx.stroke()
                if (tg.fill) {
                    ctx.lineTo(xOf(pts[pts.length - 1].t), h)
                    ctx.lineTo(xOf(pts[0].t), h)
                    ctx.closePath()
                    ctx.globalAlpha = 0.14
                    ctx.fill()
                    ctx.globalAlpha = 1
                }
            }
        }
    }

    Repeater {
        model: tg.labels
        Text {
            required property var modelData
            x: Math.max(0, Math.min(tg.width - width, tg.xOf(modelData.t) - width / 2))
            y: tg.yOf(modelData.v) - height - 1
            text: modelData.text
            color: tg.textColor
            font.family: tg.fontFamily
            font.weight: Theme.weightBody
            font.pixelSize: tg.labelSize
        }
    }

    Repeater {
        model: tg.ticks
        Text {
            required property var modelData
            x: Math.max(0, Math.min(tg.width - width, tg.xOf(modelData) - width / 2))
            y: tg.height - height - (tg.bare ? 0 : canvas.inset)
            text: Qt.formatTime(new Date(modelData), tg.tickFormat)
            color: tg.dimColor
            font.family: tg.fontFamily
            font.weight: Theme.weightBody
            font.pixelSize: tg.labelSize
        }
    }
}
