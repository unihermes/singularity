// Singularity - Quickshell
// ~/.config/quickshell/flyouts/SectionRuns.qml
//
// A frame behind each run of a column's children (ending at a heading,
// divider or bare spacer), in Theme.frameStyle; none under Flat. Put it
// beside the column, under it, with the column's top as columnY.

import QtQuick
import "../services"

Item {
    id: root

    property Item column: null
    // the column's y = 0, in this item's coordinates
    property real columnY: 0
    // the gap kept between a run's first and last child and its channel
    property int padY: Theme.spaceS
    property real radius: Theme.sectionRadius
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
            visible: Theme.sectionFramed

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

                Rectangle {
                    visible: Theme.frameDouble
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Math.max(0, plain.radius - 2)
                    color: "transparent"
                    border.width: Theme.borderWidth
                    border.color: Theme.frameStroke
                }
            }
        }
    }
}
