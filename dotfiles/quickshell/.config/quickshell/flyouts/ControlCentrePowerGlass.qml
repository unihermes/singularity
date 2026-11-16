// Glass's Power page: a battery and profile card over the action tiles,
// which fill the height they are given. Log Out, Reboot and Shut Down arm
// on the first click.

import QtQuick
import "../services"

Column {
    id: root

    required property var cc
    property real fillHeight: 0

    width: parent.width
    spacing: Theme.spaceL

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

    // the boot targets, right under the status card so the tiles keep the bottom
    GlassCard {
        id: targetsCard
        visible: root.cc.expanded === "reboot" && Session.rebootTargets.length > 0
        width: parent.width
        height: visible ? targetsCol.height + Theme.spaceL * 2 : 0
        Column {
            id: targetsCol
            x: Theme.spaceL
            y: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            spacing: Theme.spaceM
            FlyoutChipLine {
                onPicked: act => root.cc.run(act)
                chips: Session.rebootTargets.map(t => ({ icon: t.icon, text: t.label, act: "into:" + t.act }))
            }
        }
    }

    GlassTileGrid {
        fillHeight: root.fillHeight - statusCard.height - root.spacing
            - (targetsCard.visible ? targetsCard.height + root.spacing : 0)
        model: root.cc.powerActions.map(a => ({
            id: a.act, icon: a.icon, title: a.label,
            caption: root.cc.shortDetail[a.act] || a.detail || "",
            confirm: root.cc.confirmed.indexOf(a.act) !== -1,
            expandable: a.act === "reboot" && Session.rebootTargets.length > 0,
            expanded: root.cc.expanded === "reboot"
        }))
        onActivated: item => root.cc.run(item.id)
        onExpandClicked: root.cc.expand("reboot")
    }
}
