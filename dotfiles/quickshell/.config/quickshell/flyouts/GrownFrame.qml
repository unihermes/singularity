// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GrownFrame.qml
//
// A grown flyout's frame (Theme.flyoutGrown): one channel round the bar
// group it opened from and the flyout itself, so the group's lines run on
// into the panel. Drawn over the bar, with the group's interior left open
// so its modules still show.

import QtQuick
import QtQuick.Shapes
import "../services"
import "../services/ChannelPath.js" as ChannelPath

Shape {
    id: root

    // the stacked rects, top to bottom, in this item's coordinates
    property var rects: []
    // the group's interior, { x0, y0, x1, y1, r }, which isn't painted
    property var hole: null
    property color fill: Theme.surface

    preferredRendererType: Shape.CurveRenderer

    // the outline inset by d, with the hole cut out of it
    function band(d) {
        if (!rects || rects.length === 0 || rects.some(r => !r)) return ""
        var p = ChannelPath.outline(rects, Theme.channelFillet, d)
        // the fill band's hole is inset a hair at the sides only: the
        // CurveRenderer drops a hole lying exactly on the path
        var inset = d === Theme.channelWidth ? holeInset : 0
        if (hole) p += " " + ChannelPath.roundRect(hole.x0 + inset, hole.y0,
                                                   hole.x1 - inset, hole.y1,
                                                   Math.max(0, hole.r - inset))
        return p
    }

    readonly property int bw: Theme.borderWidth
    readonly property real holeInset: 0.25

    ShapePath {
        fillColor: Theme.channelOuter
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: root.band(0) }
    }
    ShapePath {
        fillColor: Theme.channelGroove
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: root.band(root.bw) }
    }
    ShapePath {
        fillColor: Theme.channelInner
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: root.band(root.bw + Theme.channelGrooveWidth) }
    }
    ShapePath {
        fillColor: root.fill
        strokeWidth: -1
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: root.band(Theme.channelWidth) }
    }
}
