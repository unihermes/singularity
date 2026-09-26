// Singularity - Quickshell
// ~/.config/quickshell/settings/DisplayLayout.qml
//
// The Display page's arrangement picture: every active display drawn to
// scale where Hyprland has it, dragged into place with the mouse. A drop
// snaps against the nearest edge of another display -- touching it, never
// overlapping -- and to its start, centre or end when close, and the dashed
// outline shows where it will land while dragging. `moved` hands the page
// the dropped display's new layout position; the page writes the rules.

import QtQuick
import "../services"

Item {
    id: root

    // [{ name, x, y, lw, lh, width, height }], x/y/lw/lh in layout px
    property var monitors: []
    property string primary: ""

    signal moved(string name, real x, real y)

    implicitHeight: Theme.fit(220)

    readonly property real pad: Theme.spaceXxl * 2
    readonly property real gap: Theme.spaceS
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
        var d = monitors.find(m => m.name === name)
        var others = monitors.filter(m => m.name !== name)
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
                readonly property bool isPrimary: modelData.name === root.primary
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
                color: drag.pressed || drag.containsMouse ? Theme.hoverFill : Theme.surface
                border.width: Math.max(1, Theme.borderWidth) * (isPrimary ? 2 : 1)
                border.color: isPrimary ? Theme.accent : Theme.frameStroke

                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceL * 2
                    spacing: Theme.spaceXs

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: box.modelData.name
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: box.isPrimary ? "Primary" : box.modelData.width + "×" + box.modelData.height
                        color: box.isPrimary ? Theme.accent : Theme.subtext
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontCaption
                    }
                }

                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    // nothing to arrange against with only one display
                    enabled: root.monitors.length > 1
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point from

                    function dropped() {
                        var base = box.landed || box.modelData
                        return { x: base.x + box.dx / root.k, y: base.y + box.dy / root.k }
                    }

                    onPressed: mouse => {
                        from = mapToItem(root, mouse.x, mouse.y)
                        ghost.mon = box.modelData
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        var p = mapToItem(root, mouse.x, mouse.y)
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
        text: "Drag a display to where it sits"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
    }
}
