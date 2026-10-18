// Singularity - Quickshell
// ~/.config/quickshell/bar/TrayModule.qml
//
// system tray: one frame around every app's icon, like the
// open-windows strip. Left raises the app's window (or activates
// the app if it has none open), right opens the app's menu in a
// flyout, middle is the app's secondary action, and a double-click
// brings the app's window up whatever the app does with clicks
// (showApp below). Each icon lights on
// its own, as the strip's do: a hover fill under it, outlined while its
// menu is open.
//
// Dragging an icon sideways moves it; the order is saved by app id
// (Settings.trayOrder), so it survives restarts and an app that quits
// gets its old place back when it returns. Apps never placed go after
// the placed ones, in the order they registered. The neighbours slide
// aside while the icon is dragged, and the order is written once it's
// dropped: writing it mid-drag would rebuild the delegates, the dragged
// one included, and drop the pointer's grab.
//
// With the tray drawer on, only the pinned icons show until the chevron
// opens the drawer.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import "../services"

ModuleFrame {
    id: trayFrame
    required property var host
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    hoverWhole: false
    // each icon carries half the gap on either side as its own hit and
    // hover area, so the chip's padding gives that half back
    padH: Theme.modulePadH - Theme.spaceM / 2
    visible: trayRepeater.count > 0 && Settings.widgetVisible("tray")

    property bool drawerOpen: false

    readonly property int slotW: Theme.barFs(16) + Theme.spaceM

    // the tray's items in the saved order
    readonly property var ordered: {
        var saved = Settings.trayOrder
        var l = Array.from(SystemTray.items.values)
        var rank = l.map((it, i) => {
            var r = saved.indexOf(it.id)
            return r === -1 ? saved.length + i : r
        })
        var idx = l.map((it, i) => i)
        idx.sort((x, y) => rank[x] - rank[y])
        return idx.map(i => l[i])
    }
    function shown(it) {
        return !Settings.trayDrawer || drawerOpen || Settings.trayPinned.indexOf(it.id) !== -1
    }
    // each item's place among the icons showing, -1 for one hidden in
    // the drawer
    readonly property var slots: {
        var n = 0
        return ordered.map(it => shown(it) ? n++ : -1)
    }

    // the drag in progress: the dragged icon's slot, the slot it would
    // drop into, and how far the pointer has carried it
    property int dragFrom: -1
    property int dragTo: -1
    property real dragDx: 0

    // moves the dragged icon among the showing ones, leaves the hidden
    // ones where they are, and saves the result into the stored order
    // without disturbing the places of apps that aren't running
    function drop() {
        var from = dragFrom, to = dragTo
        dragFrom = -1; dragTo = -1; dragDx = 0
        if (from === -1 || to === -1 || from === to) return
        var ids = ordered.map(it => it.id)
        var shownIds = ids.filter((id, i) => slots[i] !== -1)
        var moved = shownIds.splice(from, 1)[0]
        shownIds.splice(to, 0, moved)
        var present = ids.map((id, i) => slots[i] === -1 ? id : shownIds.shift())
        var queue = present.slice()
        var out = Settings.trayOrder.map(id => present.indexOf(id) === -1 ? id : queue.shift())
        Settings.setTrayOrder(out.concat(queue))
    }

    // raise one of the app's windows, on whatever workspace it's on
    function raise(win) {
        var addr = "address:0x" + win.address
        Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
        Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
    }

    // Double-click: bring the app's window up, whatever the app makes of
    // a click. The double-click's first click has already raised the
    // window or called activate(), but plenty of apps ignore activate()
    // (Ayatana ones, like Spotify and Steam, don't have it at all) or
    // answer it by toggling the window, so once that's had a moment to
    // show a window the double-click goes further: the menu's own
    // "Show ..."/"Restore"/"Open" entry, and failing that the app's
    // desktop entry run again, which a running app takes as "show your
    // window" (and a closed one as "start"). Then the window is raised
    // as soon as it's mapped, wherever it opened.
    property var showItem: null
    property int showTries: 0
    property int showWaits: 0
    property int showRaises: 0
    function showApp(item) {
        showItem = item
        showTries = -1
        showWaits = 0
        showRaises = 0
        trayFrame.showTimer.interval = 400
        trayFrame.showTimer.restart()
    }
    function showEntry() {
        var entries = trayFrame.showOpener.children.values
        var title = (showItem.title || "").toLowerCase()
        var best = null, bestRank = 9
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e.isSeparator || e.hasChildren || !e.enabled) continue
            var t = e.text.replace(/_/g, "").replace(/\.+$|…$/, "").trim().toLowerCase()
            var rank = /^(show|restore|unhide)\b/.test(t) ? 0
                : t === "open" || t === "open " + title || /^open (app|window|main window)$/.test(t) ? 1
                : 9
            if (rank < bestRank) { best = e; bestRank = rank }
        }
        return best
    }
    function desktopEntry(item) {
        var tries = [item.id, item.title,
            (item.id || "").replace(/(_status_icon_\d+|[-_]client|[-_]tray)$/i, "")]
        for (var i = 0; i < tries.length; i++) {
            if (!tries[i]) continue
            var e = DesktopEntries.heuristicLookup(tries[i])
            if (e) return e
        }
        return null
    }
    // (as properties: the frame's children all go into its row of items)
    readonly property QsMenuOpener showOpener: QsMenuOpener {
        menu: trayFrame.showItem && trayFrame.showItem.hasMenu ? trayFrame.showItem.menu : null
    }
    readonly property Timer showTimer: Timer {
        onTriggered: {
            var item = trayFrame.showItem
            if (!item) return
            var win = host.bar.trayItemWindow(item)
            var active = Hyprland.activeToplevel
            // done once the window has focus; a window only just mapped
            // can let a focus request go by, so it's asked again until
            // one takes
            if (win && active && active.address === win.address) {
                trayFrame.showItem = null
                return
            }
            if (win) {
                // ...though not without end, for a window that's kept
                // from taking focus
                if (trayFrame.showRaises++ >= 8) { trayFrame.showItem = null; return }
                trayFrame.raise(win)
                if (trayFrame.showTries === -1) trayFrame.showTries = 0
                interval = 250
            }
            if (win || trayFrame.showTries !== -1) {
                if (++trayFrame.showTries < 48) restart()
                else trayFrame.showItem = null
            } else {
                // a menu not read yet gets a little longer to arrive
                // before it's taken as having no entry to use
                if (item.hasMenu && trayFrame.showOpener.children.values.length === 0
                        && trayFrame.showWaits++ < 4) {
                    restart()
                    return
                }
                var entry = trayFrame.showEntry()
                if (entry) {
                    entry.triggered()
                } else {
                    var app = trayFrame.desktopEntry(item)
                    if (app) app.execute()
                    else item.activate()
                }
                trayFrame.showTries = 0
                interval = 250
                restart()
            }
        }
    }

    Repeater {
        id: trayRepeater
        model: trayFrame.ordered

        Item {
            id: trayIcon
            required property var modelData
            required property int index
            readonly property int slot: trayFrame.slots[index] === undefined ? -1 : trayFrame.slots[index]
            readonly property bool dragged: trayFrame.dragFrom !== -1 && trayFrame.dragFrom === slot
            // the icon whose menu is open is lit as if hovered
            readonly property bool opened: host.screenScope.openFlyout === "traymenu"
                && !!host.trayMenu.item && host.trayMenu.item.item === modelData
            readonly property bool hovered: trayMouse.containsMouse || opened
            // how far a neighbour steps aside for the dragged icon
            readonly property real shift: {
                var f = trayFrame.dragFrom, t = trayFrame.dragTo
                if (f === -1 || dragged || slot === -1) return 0
                if (f < t && slot > f && slot <= t) return -trayFrame.slotW
                if (t < f && slot >= t && slot < f) return trayFrame.slotW
                return 0
            }

            visible: slot !== -1
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: trayFrame.slotW
            implicitHeight: Theme.moduleHeight
            z: dragged ? 1 : 0

            transform: Translate {
                x: trayIcon.dragged ? trayFrame.dragDx : trayIcon.shift
                Behavior on x {
                    enabled: !trayIcon.dragged
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
                }
            }

            // the hover fill under just this icon, sized as a whole
            // module's hover is
            Rectangle {
                readonly property bool grouped: Theme.moduleStyle === "grouped"
                visible: trayIcon.hovered || trayIcon.dragged
                anchors.centerIn: parent
                width: parent.width
                height: grouped ? Theme.groupHeight - Theme.channelWidth * 2
                    : Theme.moduleTaskbar ? Theme.moduleHeight : Theme.moduleHeight - 6
                radius: grouped ? Theme.radius : Theme.radiusSmall
                color: Theme.overlay
                border.width: trayIcon.opened || trayIcon.dragged ? Theme.borderWidth : 0
                border.color: Theme.strokeFocus
            }

            TintedIcon {
                anchors.centerIn: parent
                source: trayIcon.modelData.icon
                implicitSize: Theme.barFs(16)
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                preventStealing: true
                cursorShape: trayIcon.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                // where the press landed, in the frame's coordinates
                // (the icon itself moves under the pointer once dragged)
                property real pressX: 0
                property bool moved: false
                // when the last left click landed, so a double-click's
                // second click isn't also taken as a click of its own
                property real lastClick: 0

                onPressed: mouse => {
                    pressX = mapToItem(trayFrame, mouse.x, 0).x
                    moved = false
                }
                onPositionChanged: mouse => {
                    if (!(pressedButtons & Qt.LeftButton)) return
                    var dx = mapToItem(trayFrame, mouse.x, 0).x - pressX
                    if (!moved && Math.abs(dx) < Theme.barFs(6)) return
                    if (!moved) {
                        moved = true
                        trayFrame.dragFrom = trayIcon.slot
                    }
                    var last = trayFrame.slots.filter(s => s !== -1).length - 1
                    trayFrame.dragDx = Math.max(-trayIcon.slot * trayFrame.slotW,
                        Math.min((last - trayIcon.slot) * trayFrame.slotW, dx))
                    trayFrame.dragTo = Math.max(0, Math.min(last,
                        trayIcon.slot + Math.round(dx / trayFrame.slotW)))
                }
                onReleased: if (moved) trayFrame.drop()
                onCanceled: { moved = false; trayFrame.dragFrom = -1; trayFrame.dragTo = -1; trayFrame.dragDx = 0 }
                onDoubleClicked: mouse => {
                    if (moved || mouse.button !== Qt.LeftButton) return
                    if (trayIcon.opened) host.screenScope.openFlyout = ""
                    trayFrame.showApp(trayIcon.modelData)
                }
                onClicked: mouse => {
                    if (moved) return
                    if (mouse.button === Qt.LeftButton) {
                        var now = Date.now()
                        var second = now - lastClick < Qt.styleHints.mouseDoubleClickInterval
                        lastClick = second ? 0 : now
                        if (second) return
                    }
                    var item = trayIcon.modelData
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate()
                    } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                        if (!item.hasMenu) return
                        var menu = host.trayMenu.ensure()
                        menu.item = item
                        menu.stack = []
                        host.screenScope.toggleFlyout("traymenu", trayIcon)
                    } else {
                        // raise the app's own window when it has one
                        // open (on any workspace); only fall back to the
                        // app's activate() -- usually "show/hide main
                        // window" -- when there's nothing to raise
                        var win = host.bar.trayItemWindow(item)
                        if (win) trayFrame.raise(win)
                        else item.activate()
                    }
                }
            }
        }
    }

    // the drawer's handle, padded by the half gap the icons carry
    Text {
        visible: Settings.trayDrawer
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: Theme.spaceM / 2
        rightPadding: Theme.spaceM / 2
        text: trayFrame.drawerOpen ? "󰅂" : "󰅁"
        color: drawerMouse.containsMouse ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.barFs(14)

        MouseArea {
            id: drawerMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trayFrame.drawerOpen = !trayFrame.drawerOpen
        }
    }
}
