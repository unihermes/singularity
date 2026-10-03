// Singularity - Quickshell
// ~/.config/quickshell/settings/DisplayLayout.qml
//
// The Display page's arrangement picture: every connected display drawn to
// scale where Hyprland has it, dragged into place with the mouse. A drop
// snaps against the nearest edge of another display -- touching it, never
// overlapping -- and to its start, centre or end when close, and the
// outline shows where it will land while dragging. `moved` hands the page
// the dropped display's new layout position; the page writes the rules.
//
// A display that's off is drawn dashed where the page puts it, and can't be
// dragged. A click on any display, without dragging, is `picked`: the page
// opens that display, and the one open has the lit groove.

import QtQuick
import QtQuick.Shapes
import "../services"

Item {
    id: root

    // [{ name, short, x, y, lw, lh, width, height, off, offText }],
    // x/y/lw/lh in layout px
    property var monitors: []
    property string primary: ""
    property string selected: ""

    signal moved(string name, real x, real y)
    signal picked(string name)

    implicitHeight: Theme.fit(220)

    readonly property real pad: Theme.spaceXxl * 2
    readonly property real gap: Theme.spaceS
    // the ones that can be dragged, and dropped against
    readonly property var placed: monitors.filter(m => !m.off)

    readonly property var bounds: {
        var b = { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity }
        monitors.forEach(m => {
            b.x0 = Math.min(b.x0, m.x); b.y0 = Math.min(b.y0, m.y)
            b.x1 = Math.max(b.x1, m.x + m.lw); b.y1 = Math.max(b.y1, m.y + m.lh)
        })
        return b
    }
    // layout px -> canvas px, with the whole arrangement centred
    readonly property real k: monitors.length === 0 ? 1
        : Math.min((width - 2 * pad) / (bounds.x1 - bounds.x0), (height - 2 * pad) / (bounds.y1 - bounds.y0))
    readonly property real ox: (width - (bounds.x1 - bounds.x0) * k) / 2
    readonly property real oy: (height - (bounds.y1 - bounds.y0) * k) / 2

    function toCanvasX(x) { return ox + (x - bounds.x0) * k }
    function toCanvasY(y) { return oy + (y - bounds.y0) * k }

    // Where display `name`, dropped with its corner at (x, y), ends up: the
    // nearest spot against a side of another display, or null if every
    // spot would overlap something.
    function snap(name, x, y) {
        var d = placed.find(m => m.name === name)
        var others = placed.filter(m => m.name !== name)
        var near = 12 / k

        // along the shared edge: keep some overlap, and pull to the ends
        // or the middle when within reach of them
        function along(v, o, olen, dlen) {
            var keep = Math.min(olen, dlen) * 0.1
            v = Math.max(o - dlen + keep, Math.min(o + olen - keep, v))
            var best = v, gap = near
            ;[o, o + olen - dlen, o + (olen - dlen) / 2].forEach(t => {
                if (Math.abs(t - v) < gap) { best = t; gap = Math.abs(t - v) }
            })
            return Math.round(best)
        }
        function overlaps(cx, cy) {
            return others.some(o => cx < o.x + o.lw && cx + d.lw > o.x && cy < o.y + o.lh && cy + d.lh > o.y)
        }

        var pick = null, dist = Infinity
        others.forEach(o => {
            var spots = [
                { x: o.x - d.lw, y: along(y, o.y, o.lh, d.lh) },
                { x: o.x + o.lw, y: along(y, o.y, o.lh, d.lh) },
                { x: along(x, o.x, o.lw, d.lw), y: o.y - d.lh },
                { x: along(x, o.x, o.lw, d.lw), y: o.y + o.lh }]
            spots.forEach(s => {
                var dd = (s.x - x) * (s.x - x) + (s.y - y) * (s.y - y)
                if (dd < dist && !overlaps(s.x, s.y)) { pick = s; dist = dd }
            })
        })
        return pick
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: Theme.stroke
    }

    Item {
        anchors.fill: parent
        clip: true

        // where the display being dragged will land
        Rectangle {
            id: ghost
            property var at: null
            property var mon: null
            visible: at !== null
            x: at ? root.toCanvasX(at.x) + root.gap / 2 : 0
            y: at ? root.toCanvasY(at.y) + root.gap / 2 : 0
            width: mon ? mon.lw * root.k - root.gap : 0
            height: mon ? mon.lh * root.k - root.gap : 0
            color: "transparent"
            radius: Theme.radiusSmall
            border.width: Math.max(1, Theme.borderWidth)
            border.color: Theme.accent
            opacity: 0.7
        }

        Repeater {
            model: root.monitors

            Rectangle {
                id: box
                required property var modelData
                readonly property bool off: modelData.off === true
                readonly property bool isPrimary: !off && modelData.name === root.primary
                readonly property bool lit: modelData.name === root.selected
                // drag offset in canvas px, and the snapped spot a drop
                // holds until Hyprland reports the new layout
                property real dx: 0
                property real dy: 0
                property var landed: null

                // inset by half a gap on each side, so displays that touch
                // still read as two
                x: (landed ? root.toCanvasX(landed.x) : root.toCanvasX(modelData.x)) + dx + root.gap / 2
                y: (landed ? root.toCanvasY(landed.y) : root.toCanvasY(modelData.y)) + dy + root.gap / 2
                width: modelData.lw * root.k - root.gap
                height: modelData.lh * root.k - root.gap
                z: drag.pressed ? 2 : 1
                radius: Theme.radiusSmall
                color: drag.pressed || drag.containsMouse ? Theme.hoverFill : off ? "transparent" : Theme.panel
                border.width: off ? 0 : Math.max(1, Theme.borderWidth)
                border.color: Theme.frameStroke

                // the open one: the channel's groove, lit
                Rectangle {
                    visible: box.lit
                    anchors.fill: parent
                    anchors.margins: box.off ? 0 : Theme.borderWidth
                    radius: Math.max(0, box.radius - anchors.margins)
                    color: "transparent"
                    border.width: Theme.channelGrooveWidth
                    border.color: Theme.accent
                }

                // an off display: a dashed outline
                Shape {
                    visible: box.off && !box.lit
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.frameStroke
                        strokeWidth: Math.max(1, Theme.borderWidth)
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 3]
                        fillColor: "transparent"
                        PathRectangle {
                            x: 0.5; y: 0.5
                            width: box.width - 1; height: box.height - 1
                            radius: box.radius
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceL * 2
                    spacing: Theme.spaceXs

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: box.modelData.icon
                        color: Theme.subtext
                        font.family: Theme.fontIcon
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontIconSize
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: box.modelData.short
                        color: box.off ? Theme.subtext : Theme.textStrong
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                        font.weight: Theme.weightStrong
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: box.off ? box.modelData.offText
                            : (box.isPrimary ? "Primary · " : "") + box.modelData.width + " × " + box.modelData.height
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }
                }

                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: box.off || root.placed.length < 2 ? Qt.PointingHandCursor
                        : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point from
                    // how far it has travelled: a press that barely moves is a click
                    property real travel: 0
                    readonly property bool draggable: !box.off && root.placed.length > 1

                    function dropped() {
                        var base = box.landed || box.modelData
                        return { x: base.x + box.dx / root.k, y: base.y + box.dy / root.k }
                    }

                    onPressed: mouse => {
                        from = mapToItem(root, mouse.x, mouse.y)
                        travel = 0
                        if (draggable) ghost.mon = box.modelData
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var p = mapToItem(root, mouse.x, mouse.y)
                        travel += Math.abs(p.x - from.x) + Math.abs(p.y - from.y)
                        if (!draggable || travel < 4) return
                        box.dx += p.x - from.x
                        box.dy += p.y - from.y
                        from = p
                        var at = dropped()
                        ghost.at = root.snap(box.modelData.name, at.x, at.y)
                    }
                    onReleased: {
                        var at = ghost.at
                        ghost.at = null
                        box.dx = 0
                        box.dy = 0
                        if (travel < 4) {
                            root.picked(box.modelData.name)
                            return
                        }
                        if (!at) return
                        var cur = box.landed || box.modelData
                        if (at.x === cur.x && at.y === cur.y) return
                        box.landed = at
                        root.moved(box.modelData.name, at.x, at.y)
                    }
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spaceL
        text: root.placed.length > 1 ? "Drag to arrange · click to open" : "Click a display to open it"
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontCaption
    }
}
