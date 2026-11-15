// Glass's grid of action tiles: two columns of frosted cards, each with a
// round icon, a title and a caption, stretching to fill `fillHeight`. An
// odd last tile takes the whole row. A tile with `confirm` arms on the first
// click and fires on the second; one with `expandable` has a chevron.
//
//   GlassTileGrid {
//       fillHeight: 300
//       model: [{ id: "lock", icon: "󰌾", title: "Lock", caption: "Screen only" }]
//       onActivated: item => run(item.id)
//   }

import QtQuick
import "../services"

Item {
    id: root

    // [{ id, icon, title, caption, lit, usable, confirm, expandable, expanded }]
    property var model: []
    property real fillHeight: 0
    property real spacing: Theme.spaceL
    signal activated(var item)
    signal expandClicked(var item)

    readonly property int rows: Math.ceil(model.length / 2)
    readonly property real cell: (width - spacing) / 2
    readonly property real tileH: Math.max(Theme.fs(60), rows > 0 ? (fillHeight - spacing * (rows - 1)) / rows : 0)
    // the tile waiting for its second click
    property string armed: ""

    width: parent ? parent.width : 0
    height: rows * tileH + Math.max(0, rows - 1) * spacing

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }
    onVisibleChanged: if (!visible) armed = ""

    Repeater {
        model: root.model

        Item {
            id: tile
            required property var modelData
            required property int index
            readonly property bool isArmed: root.armed === modelData.id
            readonly property bool expandable: modelData.expandable === true
            readonly property bool usable: modelData.usable !== false
            width: index === root.model.length - 1 && root.model.length % 2 === 1 ? root.width : root.cell
            height: root.tileH
            x: index % 2 * (root.cell + root.spacing)
            y: Math.floor(index / 2) * (root.tileH + root.spacing)
            opacity: usable ? 1 : 0.5

            GlassCard { anchors.fill: parent }
            GlassDot {
                id: dot
                x: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                icon: tile.modelData.icon
                lit: tile.isArmed || tile.modelData.lit === true
            }
            Column {
                anchors.left: dot.right
                anchors.leftMargin: Theme.spaceL
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceL + (tile.expandable ? Theme.fs(24) : 0)
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: tile.modelData.title
                    elide: Text.ElideRight
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    width: parent.width
                    text: tile.isArmed ? "Click again" : tile.modelData.caption || ""
                    elide: Text.ElideRight
                    color: tile.isArmed ? Theme.accent : Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: tile.usable
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (tile.modelData.confirm === true && !tile.isArmed) {
                        root.armed = tile.modelData.id
                        disarm.restart()
                        return
                    }
                    root.armed = ""
                    root.activated(tile.modelData)
                }
            }
            IconButton {
                visible: tile.expandable
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                icon: tile.modelData.expanded === true ? "󰅀" : "󰅂"
                onClicked: root.expandClicked(tile.modelData)
            }
        }
    }
}
