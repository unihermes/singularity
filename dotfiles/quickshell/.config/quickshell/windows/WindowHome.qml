// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowHome.qml
//
// A window's Home: every page as a full-width tile (HomeRow) in framed
// groups under headings, in a centred column; `header` goes above.
//
// groups: [{ heading, items: [{ id, icon, label, blurb, status,
//            statusColor, history, historyCeiling }] }]

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    property var groups: []
    property Component header: null
    // the tile the arrow keys are on, by page id
    property string cursorId: ""

    signal activated(string id)
    signal hovered(string id)

    // back to the first group, for a fresh open
    function toTop() { flick.contentY = 0 }

    // keep a tile on screen, for the arrow keys
    function reveal(id) {
        var row = null
        for (var g = 0; g < groupRepeater.count && !row; g++) {
            var rows = groupRepeater.itemAt(g).rowRepeater
            for (var r = 0; r < rows.count; r++)
                if (rows.itemAt(r).pageId === id) { row = rows.itemAt(r); break }
        }
        if (!row) return
        var y = row.mapToItem(col, 0, 0).y + col.y
        if (y < flick.contentY) flick.contentY = y
        else if (y + row.height > flick.contentY + flick.height) flick.contentY = y + row.height - flick.height
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: Theme.scrollGutter
        contentHeight: col.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        SectionRuns {
            x: col.x - col.inset
            width: col.width + col.inset * 2
            column: col
            columnY: col.y
        }

        Column {
            id: col
            readonly property int inset: Theme.channelWidth + Theme.spaceL
            readonly property bool sectioned: true
            width: Math.min(Theme.fit(760), flick.width - (Theme.spaceS + inset) * 2)
            x: Math.round((flick.width - width) / 2)
            spacing: Theme.spaceL
            topPadding: Theme.channelWidth + Theme.spaceS
            bottomPadding: Theme.spaceXl

            Loader {
                // its own frames, so not a run of the groups' blocks
                readonly property bool isSectionBreak: true
                // as wide as the groups' frames, not their rows
                x: -col.inset
                width: col.width + col.inset * 2
                active: root.header !== null
                visible: active
                height: active && item ? item.implicitHeight : 0
                sourceComponent: root.header
            }

            Repeater {
                id: groupRepeater
                model: root.groups

                Column {
                    id: group
                    required property var modelData
                    property Item rowRepeater: rowRepeater
                    readonly property bool isSectionGroup: true
                    readonly property bool sectioned: true
                    width: col.width
                    spacing: Theme.spaceM

                    FlyoutHeading { text: group.modelData.heading }

                    // one block: rows touch, a hairline between them
                    Column {
                        width: parent.width

                        Repeater {
                            id: rowRepeater
                            model: group.modelData.items

                            HomeRow {
                                required property var modelData
                                required property int index
                                readonly property string pageId: modelData.id
                                first: index === 0
                                icon: modelData.icon
                                label: modelData.label
                                blurb: modelData.blurb || ""
                                status: modelData.status || ""
                                statusColor: modelData.statusColor || Theme.subtext
                                history: modelData.history || []
                                historyCeiling: modelData.historyCeiling || 1
                                current: root.cursorId === modelData.id
                                onClicked: root.activated(modelData.id)
                                onHovered: root.hovered(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    ScrollBar {
        anchors.right: parent.right
        flickable: flick
    }
}
