// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowSidebar.qml
//
// The pages beside an open page (Settings, System): each group under its
// heading, a row per page (its icon and name over what it's set to or
// reading now), the open one with the fill and tick.
//
// groups: [{ heading, items: [{ id, icon, label, line, lineColor }] }]

import QtQuick
import "../services"
import "../flyouts"
import "../settings"

Item {
    id: root

    property var groups: []
    // the open page's id
    property string current: ""

    signal selected(string id)

    // keep a page's row on screen, for the arrow keys
    function reveal(id) {
        for (var g = 0; g < groupRep.count; g++) {
            var rows = groupRep.itemAt(g).rowRepeater
            for (var r = 0; r < rows.count; r++) {
                var row = rows.itemAt(r)
                if (row.pageId !== id) continue
                var y = row.mapToItem(col, 0, 0).y
                if (y < flick.contentY) flick.contentY = y
                else if (y + row.height > flick.contentY + flick.height) flick.contentY = y + row.height - flick.height
                return
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.rightMargin: Theme.scrollGutter
        contentHeight: col.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            spacing: Theme.spaceS

            Repeater {
                id: groupRep
                model: root.groups

                Column {
                    id: group
                    required property var modelData
                    property Item rowRepeater: rows
                    width: col.width
                    spacing: 0

                    FlyoutHeading { width: parent.width; text: group.modelData.heading.toUpperCase() }

                    Repeater {
                        id: rows
                        model: group.modelData.items

                        SettingsSectionRow {
                            required property var modelData
                            readonly property string pageId: modelData.id
                            icon: modelData.icon
                            label: modelData.label
                            blurb: modelData.line
                            blurbColor: modelData.lineColor
                            current: root.current === modelData.id
                            onClicked: root.selected(modelData.id)
                        }
                    }
                }
            }
        }
    }

    ScrollBar {
        anchors.right: parent.right
        visible: flick.interactive
        flickable: flick
    }
}
