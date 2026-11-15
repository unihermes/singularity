// Glass's Power page: a battery and profile card over a grid of action
// tiles that fills the height it is given. Destructive actions arm on the
// first click and run on the second.

import QtQuick
import "../services"

Column {
    id: root

    required property var cc
    // the tiles stretch to fill this; the page is never shorter than its content
    property real fillHeight: 0

    width: parent.width
    spacing: Theme.spaceL

    readonly property var actions: cc.powerActions
    readonly property int rows: Math.ceil(actions.length / 2)
    readonly property real cell: (width - spacing) / 2
    readonly property real tileH: Math.max(Theme.fs(56), (fillHeight - statusCard.height - spacing * rows) / rows)
    // the action waiting for its second click
    property string armed: ""

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }
    onVisibleChanged: if (!visible) armed = ""

    GlassCard {
        id: statusCard
        width: parent.width
        height: statusCol.height + Theme.spaceL * 2
        Column {
            id: statusCol
            x: Theme.spaceL
            y: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            spacing: Theme.spaceM
            Item {
                visible: Battery.present
                width: parent.width
                height: Theme.fs(20)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Battery"
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.percent + "%"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }
            }
            FlyoutSegmented {
                visible: PpdProfile.profile !== ""
                model: PpdProfile.choices
                current: PpdProfile.profile
                onPicked: v => PpdProfile.set(v)
            }
        }
    }

    Item {
        width: parent.width
        height: root.rows * root.tileH + (root.rows - 1) * root.spacing
        Repeater {
            model: root.actions

            Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool destructive: root.cc.confirmed.indexOf(modelData.act) !== -1
                readonly property bool isArmed: root.armed === modelData.act
                readonly property bool hasTargets: modelData.act === "reboot" && Session.rebootTargets.length > 0
                // an odd last tile takes the whole row
                width: index === root.actions.length - 1 && root.actions.length % 2 === 1
                    ? root.width : root.cell
                height: root.tileH
                x: index % 2 * (root.cell + root.spacing)
                y: Math.floor(index / 2) * (root.tileH + root.spacing)

                GlassCard { anchors.fill: parent }
                GlassDot {
                    id: dot
                    x: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    icon: tile.modelData.icon
                    lit: tile.isArmed
                }
                Column {
                    anchors.left: dot.right
                    anchors.leftMargin: Theme.spaceL
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceL + (tile.hasTargets ? Theme.fs(24) : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: tile.modelData.label
                        elide: Text.ElideRight
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightStrong
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        width: parent.width
                        text: tile.isArmed ? "Click again" : root.cc.shortDetail[tile.modelData.act] || tile.modelData.detail || ""
                        elide: Text.ElideRight
                        color: tile.isArmed ? Theme.accent : Theme.subtext
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontCaption
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tile.destructive && !tile.isArmed) {
                            root.armed = tile.modelData.act
                            disarm.restart()
                            return
                        }
                        root.armed = ""
                        root.cc.run(tile.modelData.act)
                    }
                }
                IconButton {
                    visible: tile.hasTargets
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.cc.expanded === "reboot" ? "󰅀" : "󰅂"
                    onClicked: root.cc.expand("reboot")
                }
            }
        }
    }
}
