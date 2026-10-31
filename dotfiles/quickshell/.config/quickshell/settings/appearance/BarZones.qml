// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/BarZones.qml
//
// The Bar tab's arrangement: Left, Centre and Right zones of module chips
// and Hidden under them. A dragged chip is a ghost with a landing marker;
// the drop writes the whole layout and visibility. Control Centre and Show
// Desktop stay pinned (Control Centre can't be hidden).

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

Item {
    id: root

    readonly property var layout: Settings.widgetLayout()
    readonly property var hiddenKeys: Settings.widgetSections.reduce(
        (a, s) => a.concat(layout[s].filter(k => !Settings.widgetVisible(k))), [])
    function shownIn(sec) { return layout[sec].filter(k => Settings.widgetVisible(k)) }

    // the drag in progress: the chip's key, where the pointer is (in this
    // item), and where it would land ({ zone, index }, or null)
    property string dragKey: ""
    property point dragAt: Qt.point(0, 0)
    property var target: null

    width: parent ? parent.width : 0
    implicitHeight: zones.height + Theme.spaceM + hiddenZone.height

    readonly property var zoneItems: [zoneLeft, zoneCentre, zoneRight, hiddenZone]

    // the zone under a point and the slot among its chips
    function findTarget(p) {
        for (var z = 0; z < zoneItems.length; z++) {
            var zone = zoneItems[z]
            var q = zone.mapFromItem(root, p.x, p.y)
            if (q.x < 0 || q.y < 0 || q.x > zone.width || q.y > zone.height) continue
            var chips = zone.chipItems()
            var i = 0
            for (; i < chips.length; i++) {
                var c = chips[i].mapToItem(root, chips[i].width / 2, chips[i].height / 2)
                var h = chips[i].height / 2
                if (c.y - h > p.y) break
                if (Math.abs(c.y - p.y) <= h && c.x > p.x) break
            }
            return { zone: zone.name, index: i }
        }
        return null
    }

    function drop() {
        var key = dragKey, t = target
        dragKey = ""
        target = null
        if (!t) return
        if (t.zone === "hidden") {
            if (Settings.lockedWidgets.indexOf(key) === -1) Settings.setWidgetVisible(key, false)
            return
        }
        // the full layout, hidden modules in their places, with the key
        // taken out and put back before the shown chip it was dropped on
        var l = { left: layout.left.slice(), centre: layout.centre.slice(), right: layout.right.slice() }
        var shown = shownIn(t.zone).filter(k => k !== key)
        for (var s in l) l[s] = l[s].filter(k => k !== key)
        var before = t.index < shown.length ? shown[t.index] : ""
        var at = before !== "" ? l[t.zone].indexOf(before) : l[t.zone].length
        l[t.zone].splice(at, 0, key)
        Settings.setWidgetVisible(key, true)
        Settings.setWidgetLayout(l)
    }

    component Chip: Rectangle {
        id: chip
        required property string key
        readonly property var info: Settings.widgetMeta[key] || { label: key, icon: "" }
        readonly property bool pinned: Settings.pinnedWidgets.indexOf(key) !== -1
        property bool ghost: false
        readonly property bool held: !ghost && root.dragKey === key
        width: chipRow.implicitWidth + Theme.spaceM * 2
        height: Theme.chipHeight + Theme.spaceXs
        radius: Theme.radiusInner
        color: ghost ? Theme.overlay : chipMouse.containsMouse && !pinned ? Theme.hoverFillSoft : Theme.surface
        border.width: Theme.borderWidth
        border.color: ghost ? Theme.accent : Theme.stroke
        opacity: held ? 0.35 : 1

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spaceS
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.info.icon
                color: Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.info.label
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
                font.weight: Theme.weightBody
            }
            Text {
                visible: chip.pinned || Settings.centreAnchor === chip.key
                anchors.verticalCenter: parent.verticalCenter
                text: "󰐃"
                color: Theme.muted
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontCaption
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: !chip.ghost && !chip.pinned
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => {
                root.dragKey = chip.key
                root.dragAt = mapToItem(root, mouse.x, mouse.y)
                root.target = null
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                root.dragAt = mapToItem(root, mouse.x, mouse.y)
                root.target = root.findTarget(root.dragAt)
            }
            onReleased: root.drop()
            onCanceled: { root.dragKey = ""; root.target = null }
        }
    }

    component Zone: Rectangle {
        id: zone
        required property string name
        property string title: ""
        property var keys: []
        readonly property bool lit: root.target !== null && root.target.zone === zone.name
        function chipItems() {
            var out = []
            for (var i = 0; i < rep.count; i++) out.push(rep.itemAt(i))
            return out
        }
        radius: Theme.radiusInner
        color: lit ? Theme.selectedFill : "transparent"
        border.width: Theme.borderWidth
        border.color: lit ? Theme.accent : Theme.stroke
        readonly property real contentHeight: Math.max(Theme.fs(72), flow.y + flow.implicitHeight + Theme.spaceM)
        height: contentHeight

        Text {
            id: zoneTitle
            x: Theme.spaceM
            y: Theme.spaceS
            text: zone.title + (zone.keys.length === 0 ? "  ·  empty" : "")
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
            font.weight: Theme.weightStrong
            font.letterSpacing: 1
        }

        Flow {
            id: flow
            x: Theme.spaceM
            y: zoneTitle.y + zoneTitle.height + Theme.spaceS
            width: zone.width - Theme.spaceM * 2
            spacing: Theme.spaceS
            Repeater {
                id: rep
                model: zone.keys
                Chip { required property string modelData; key: modelData }
            }
        }

        // where the dragged chip would land
        Rectangle {
            visible: zone.lit && zone.name !== "hidden"
            readonly property var chips: zone.chipItems()
            readonly property int at: root.target ? root.target.index : 0
            readonly property Item ref: at < chips.length ? chips[at] : chips.length > 0 ? chips[chips.length - 1] : null
            x: !ref ? flow.x : flow.x + ref.x + (at < chips.length ? -Theme.spaceS / 2 - 1 : ref.width + Theme.spaceS / 2 - 1)
            y: ref ? flow.y + ref.y : flow.y
            width: 2
            height: Theme.chipHeight + Theme.spaceXs
            color: Theme.accent
        }
    }

    Row {
        id: zones
        width: parent.width
        spacing: Theme.spaceS
        readonly property real zoneWidth: (width - spacing * 2) / 3

        Zone { id: zoneLeft; name: "left"; title: "LEFT"; keys: root.shownIn("left"); width: zones.zoneWidth; height: zones.tallest }
        Zone { id: zoneCentre; name: "centre"; title: "CENTRE"; keys: root.shownIn("centre"); width: zones.zoneWidth; height: zones.tallest }
        Zone { id: zoneRight; name: "right"; title: "RIGHT"; keys: root.shownIn("right"); width: zones.zoneWidth; height: zones.tallest }

        // the three zones share the tallest one's height
        readonly property real tallest: Math.max(zoneLeft.contentHeight, zoneCentre.contentHeight, zoneRight.contentHeight)
    }

    Zone {
        id: hiddenZone
        anchors.top: zones.bottom
        anchors.topMargin: Theme.spaceM
        width: parent.width
        name: "hidden"
        title: "HIDDEN"
        keys: root.hiddenKeys
    }

    // the chip being dragged
    Chip {
        visible: root.dragKey !== ""
        ghost: true
        key: root.dragKey
        z: 10
        x: root.dragAt.x - width / 2
        y: root.dragAt.y - height / 2
    }
}
