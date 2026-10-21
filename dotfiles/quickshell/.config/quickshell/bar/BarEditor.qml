// Singularity - Quickshell
// ~/.config/quickshell/bar/BarEditor.qml
//
// Edit mode on the bar itself, while the edit shelf (BarEditFlyout) is open:
// takes the bar's presses, outlines every module, and drags them. A dragged
// module is written to Settings at every step, so the bar slides round it,
// with a live copy under the pointer; dragged off the bar it's hidden, and
// the shelf draws it. A click on a centre module pins it to the middle.
//
// The shelf feeds its own chips' drags in through press/move/release, in
// the bar window's coordinates, so one drag can cross both surfaces.

import QtQuick
import "../services"

Item {
    id: root

    required property var bar
    // the bar's drawn strip, in the window's coordinates
    required property Item body

    anchors.fill: parent
    visible: bar.editing

    // the module being dragged ("" for none), and where the pointer is
    property string dragKey: ""
    property real dragX: 0
    property real dragY: 0
    // the pointer is over the bar's strip, not out over the shelf
    readonly property bool overBar: dragY >= 0 && dragY <= bar.height

    // the press not yet a drag: its key, where, and whether from the shelf
    property string pressKey: ""
    property point pressAt: Qt.point(0, 0)
    property bool fromShelf: false
    // the pointer's offset into the module it picked up
    property real grabDX: 0
    // where the sections divide, fixed for the drag so a module crossing
    // one doesn't move the line it crossed
    property real cutA: 0
    property real cutB: 0
    // the last place written, to write only changes
    property string placed: ""

    onVisibleChanged: if (!visible) reset()

    function reset() {
        dragKey = ""
        pressKey = ""
        placed = ""
    }

    function movable(key) {
        return Settings.pinnedWidgets.indexOf(key) === -1
    }

    // the module whose slot holds a point, "" for none
    function keyAt(x, y) {
        for (const key of bar.widgetKeys) {
            const it = bar.slotItem(key)
            if (!it || !it.visible) continue
            const p = it.mapToItem(root, 0, 0)
            if (x >= p.x && x < p.x + it.width && y >= p.y && y < p.y + it.height) return key
        }
        return ""
    }

    function press(key, x, y, shelf) {
        pressKey = key
        pressAt = Qt.point(x, y)
        fromShelf = shelf
    }

    function move(x, y) {
        if (pressKey === "") return
        if (dragKey === "") {
            if (Math.hypot(x - pressAt.x, y - pressAt.y) < Theme.sp(6)) return
            begin()
        }
        dragX = x
        dragY = y
        place(overBar ? landingAt(x) : "hidden")
    }

    function release() {
        if (dragKey === "" && pressKey !== "" && !fromShelf
                && Settings.widgetSection(pressKey) === "centre")
            Settings.setCentreAnchor(Settings.centreAnchor === pressKey ? "" : pressKey)
        reset()
    }

    function begin() {
        dragKey = pressKey
        const it = bar.slotItem(dragKey)
        grabDX = it && it.visible ? pressAt.x - it.mapToItem(root, 0, 0).x : 0
        const l = bar.islandSpan("left"), c = bar.islandSpan("centre"), r = bar.islandSpan("right")
        const mid = bar.width / 2, reach = Theme.barHeight * 2
        const c0 = c.w > 0 ? c.x : mid - reach, c1 = c.w > 0 ? c.x + c.w : mid + reach
        cutA = (l.x + l.w + c0) / 2
        cutB = (c1 + r.x) / 2
    }

    // the section under x, and the shown module the dragged one goes before
    // there ("" for the end)
    function landingAt(x) {
        const section = x < cutA ? "left" : x > cutB ? "right" : "centre"
        const shown = Settings.widgetOrder(section).filter(k => {
            if (k === dragKey) return false
            const it = bar.slotItem(k)
            return it && it.visible
        })
        for (const k of shown) {
            const it = bar.slotItem(k)
            if (x < it.mapToItem(root, it.width / 2, 0).x) return { section: section, before: k }
        }
        return { section: section, before: "" }
    }

    // writes the dragged module's new place: hidden, or in a section
    function place(to) {
        const sig = JSON.stringify(to)
        if (sig === placed) return
        placed = sig
        if (to === "hidden") {
            if (Settings.lockedWidgets.indexOf(dragKey) === -1) Settings.setWidgetVisible(dragKey, false)
            return
        }
        const was = Settings.widgetLayout()
        const l = {}
        for (const s of Settings.widgetSections) l[s] = was[s].filter(k => k !== dragKey)
        const at = to.before !== "" ? l[to.section].indexOf(to.before) : -1
        l[to.section].splice(at < 0 ? l[to.section].length : at, 0, dragKey)
        Settings.setWidgetLayout(l)
        Settings.setWidgetVisible(dragKey, true)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.bar.editing
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        preventStealing: true
        property string hoverKey: ""
        cursorShape: root.dragKey !== "" ? Qt.ClosedHandCursor
            : hoverKey !== "" && root.movable(hoverKey) ? Qt.OpenHandCursor : Qt.ArrowCursor

        onPressed: mouse => {
            if (mouse.button !== Qt.LeftButton) return
            const key = root.keyAt(mouse.x, mouse.y)
            if (key !== "" && root.movable(key)) root.press(key, mouse.x, mouse.y, false)
        }
        onPositionChanged: mouse => {
            if (pressed) root.move(mouse.x, mouse.y)
            else hoverKey = root.keyAt(mouse.x, mouse.y)
        }
        onExited: hoverKey = ""
        onReleased: root.release()
        onCanceled: root.reset()
        // the modules under it would take it (a volume change mid-edit)
        onWheel: wheel => wheel.accepted = true
    }

    // every module's outline; the dragged one's is the gap it will land in
    Repeater {
        model: root.bar.widgetKeys

        Rectangle {
            id: outline
            required property string modelData
            readonly property Item module: root.bar.editing ? root.bar.slotItem(modelData) : null
            readonly property bool held: root.dragKey === modelData
            readonly property bool anchor: Settings.centreAnchor === modelData
                && Settings.widgetSection(modelData) === "centre"
            visible: !!module && module.visible && (root.movable(modelData) || held)
            // follows the module as it slides: its slots' x plus its own
            x: module ? module.parent.x + module.x : 0
            y: root.body.y + Math.round((Theme.barHeight - height) / 2)
            width: module ? module.width : 0
            height: Theme.moduleHeight
            radius: Theme.radiusInner
            color: held ? Theme.selectedFill : "transparent"
            border.width: Theme.borderWidth
            border.color: held || area.hoverKey === modelData && root.dragKey === "" ? Theme.accent : Theme.stroke

            // the centre anchor's pin
            Text {
                visible: outline.anchor
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1
                text: "󰐃"
                color: Theme.accent
                font.family: Theme.fontIcon
                font.pixelSize: Theme.barFs(9)
            }
        }
    }

    // the dragged module, live, under the pointer
    ShaderEffectSource {
        readonly property Item module: root.dragKey !== "" ? root.bar.slotItem(root.dragKey) : null
        visible: !!module && module.visible && root.overBar
        sourceItem: module
        hideSource: true
        live: true
        width: module ? module.width : 0
        height: module ? module.height : 0
        x: Math.round(root.dragX - root.grabDX)
        y: module ? module.mapToItem(root, 0, 0).y : 0
        z: 1

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.moduleHeight
            radius: Theme.radiusInner
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.accent
        }
    }
}
