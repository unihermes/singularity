// Singularity - Quickshell
// ~/.config/quickshell/flyouts/SectionRuns.qml
//
// The sectioned treatment: a frame behind each run of a column's children,
// a run ending at a heading, a divider or a page's bare spacer Item. The
// frame is the style's own (Theme.frameStyle):
//   channel  the channel's three bands
//   double   an outer stroke and an inner one inset
//   single   one stroke
//   bevel    a sunken chisel, a well in the raised panel
//   ledger   one 2px ink stroke
//   corners  short marks at the corners
//   none     the ground alone
// Put it beside the column, under it, and say where the column's top sits
// in this item.

import QtQuick
import "../services"

Item {
    id: root

    property Item column: null
    // the column's y = 0, in this item's coordinates
    property real columnY: 0
    // the gap kept between a run's first and last child and its channel
    property int padY: Theme.spaceS
    property real radius: Theme.radius > 0 ? Theme.radius + 3 : 0
    property color fill: Theme.panelFill

    // [{ y0, y1 }] in the column's coordinates. A child marked
    // isSectionGroup (a Repeater's Column of heading and rows) is walked
    // as if its children sat in the column itself.
    readonly property var runs: {
        if (!column) return []
        var out = [], cur = null
        function walk(kids, dy) {
            for (var i = 0; i < kids.length; i++) {
                var c = kids[i]
                if (!c.visible || c.height <= 0) continue
                if (c.isSectionGroup === true) {
                    walk(c.children, dy + c.y)
                    continue
                }
                if (c.isFlyoutHeading === true || c.isSectionBreak === true
                        || (/^QQuickItem\(/.test(String(c)) && c.children.length === 0)) {
                    cur = null
                    continue
                }
                if (!cur) { cur = { y0: dy + c.y, y1: dy + c.y + c.height }; out.push(cur) }
                else cur.y1 = dy + c.y + c.height
            }
        }
        walk(column.children, 0)
        return out
    }

    Repeater {
        model: root.runs

        Item {
            required property var modelData
            readonly property int out: Theme.channelWidth + root.padY
            width: root.width
            y: root.columnY + modelData.y0 - out
            height: modelData.y1 - modelData.y0 + out * 2

            Channel {
                visible: Theme.frameChannel
                radius: root.radius
                fill: root.fill
            }

            Rectangle {
                id: plain
                visible: !Theme.frameChannel
                anchors.fill: parent
                radius: root.radius
                color: root.fill
                border.width: Theme.frameStroked ? Theme.borderWidth : 0
                border.color: Theme.stroke

                CornerMarks { visible: Theme.frameCorners }

                Rectangle {
                    visible: Theme.frameDouble
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Math.max(0, plain.radius - 2)
                    color: "transparent"
                    border.width: Theme.borderWidth
                    border.color: Theme.frameStroke
                }

                Bevel {
                    visible: Theme.frameBevel
                    anchors.fill: parent
                    raised: false
                    light: Theme.bevelLight
                    dark: Theme.bevelDark
                    thickness: Theme.borderWidth
                }
            }
        }
    }
}
