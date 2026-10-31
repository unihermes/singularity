// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspaceOverlay.qml
//
// SUPER+W: a miniature of every workspace, its windows drawn where they sit
// on its monitor with the app's icon in each. Click a miniature to jump, a
// window to focus it, drag a window onto another miniature to move it.
// Specials with windows get one too. Centred, not a FlyoutPanel;
// Theme.overviewLayout and Theme.backdrop style it.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import "../services"

OverlayWindow {
    id: root

    readonly property bool open: scope.openFlyout === "workspaceoverlay"

    function requestClose() { scope.openFlyout = "" }

    // the fixed workspaces the binds use, existing or not
    readonly property int workspaceCount: Settings.workspaceCount

    function windowsOf(ws) {
        if (!ws || !ws.toplevels) return []
        return ws.toplevels.values.filter(tl => !Apps.isShellWindow(tl) && !Apps.isBackTabToplevel(tl))
    }

    // the miniatures: every numbered workspace, then the specials with
    // windows. `target`: a number or "special:name"
    readonly property var cards: {
        const wss = Hyprland.workspaces.values
        const out = []
        for (let id = 1; id <= workspaceCount; id++) {
            const ws = wss.find(w => w.id === id) || null
            out.push({ target: id, title: String(id), ws: ws, windows: windowsOf(ws) })
        }
        for (const ws of wss) {
            if (ws.id >= 0) continue
            const wins = windowsOf(ws)
            const name = String(ws.name).replace(/^special:/, "")
            if (wins.length > 0)
                out.push({ target: ws.name, title: name.charAt(0).toUpperCase() + name.slice(1), ws: ws, windows: wins })
        }
        return out
    }

    // a monitor's logical box, which window positions are in; a workspace
    // that isn't on one (empty, or a hidden special) takes the focused one's
    function monitorBox(ws) {
        const m = (ws && ws.monitor) || Hyprland.focusedMonitor
        const o = m && m.lastIpcObject
        if (!o || !o.width) return { x: 0, y: 0, w: 16, h: 9 }
        const turned = (o.transform || 0) % 2 === 1
        const w = (turned ? o.height : o.width) / (o.scale || 1)
        const h = (turned ? o.width : o.height) / (o.scale || 1)
        return { x: o.x, y: o.y, w: w, h: h }
    }

    // fresh positions each time it opens
    onOpenChanged: if (open) {
        Hyprland.refreshMonitors()
        Hyprland.refreshToplevels()
    }

    // the window being dragged, for the ghost under the pointer
    property var dragging: null
    property point dragPoint: Qt.point(0, 0)

    function jump(target) {
        if (typeof target === "number") Hyprland.dispatch("hl.dsp.focus({workspace=" + target + "})")
        else Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + String(target).replace(/^special:/, "") + "\")")
        requestClose()
    }

    // The drop target a drag is over, so it can light; null for none.
    property var dropTarget: null

    visible: open
    // Exclusive, not OnDemand: Escape has to work without clicking into the
    // overlay first, and it is transient, so focus returns when it closes.
    focusMode: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    layerNamespace: "singularity-overlay"

    // Dim, and close on a click that misses every cell.
    Rectangle {
        anchors.fill: parent
        color: Theme.backdrop

        Backdrop {
            onDismissed: root.requestClose()
        }
    }

    // a press on the other monitor too
    DismissGrab { panel: root }

    // Keys only attach to Items, so they live on a focused Item
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.requestClose()
        // Number keys jump straight to a workspace, matching SUPER+<n>.
        Keys.onPressed: event => {
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const id = event.key - Qt.Key_0
                if (id <= root.workspaceCount) {
                    Hyprland.dispatch("hl.dsp.focus({workspace=" + id + "})")
                    root.requestClose()
                    event.accepted = true
                }
            }
        }
    }

    // laid out as the launcher is: a heading with the key hints, then the body
    PanelFrame {
        anchors.centerIn: parent
        width: body.implicitWidth + Theme.panelPad * 4
        height: body.implicitHeight + Theme.panelPad * 4

        Absorber {}

        Column {
            id: body
            x: Theme.panelPad * 2
            y: Theme.panelPad * 2
            spacing: Theme.spaceL

            FlyoutHeading {
                width: grid.width
                text: "WORKSPACES"
                hints: ["1-" + Math.min(9, root.workspaceCount) + " jump", "Drag a window to move it", "Esc close"]
            }

            Grid {
                id: grid
                columns: Theme.overviewLayout === "strip" ? root.cards.length : Math.min(3, root.cards.length)
                spacing: Theme.spaceL

                // the miniature under a point in the grid, as its target
                function targetAt(p) {
                    const c = childAt(p.x, p.y)
                    return c && c.card !== undefined ? c.card.target : null
                }

                Repeater {
                    model: root.cards

                    Column {
                        id: cell
                        required property var modelData
                        readonly property var card: modelData
                        readonly property var mon: root.monitorBox(card.ws)
                        readonly property bool isFocused: Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === (card.ws ? card.ws.id : card.target)
                        readonly property bool isDropTarget: root.dropTarget !== null && root.dropTarget === card.target
                        // a row of every miniature has to fit the screen
                        readonly property real shrink: Theme.overviewLayout === "strip"
                            ? Math.min(1, (root.width * 0.9 / root.cards.length - grid.spacing) / Theme.fs(260)) : 1
                        spacing: Theme.spaceS

                        ClippingRectangle {
                            id: shot
                            width: Math.round(Theme.fs(260) * cell.shrink)
                            height: Math.round(width * cell.mon.h / cell.mon.w)
                            radius: Theme.radiusInner
                            color: Theme.base
                            readonly property real k: width / cell.mon.w

                            // the wallpaper, quietened, so the windows read over it
                            Image {
                                anchors.fill: parent
                                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 320
                                opacity: 0.35
                            }

                            // jump here; behind the windows, so a click on
                            // one focuses it instead
                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.jump(cell.card.target)
                            }

                            Repeater {
                                model: cell.card.windows

                                Rectangle {
                                    id: win
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject || {}
                                    readonly property string cls: ipc.class || ""
                                    readonly property string iconPath: Apps.iconForClass(cls)
                                    readonly property var at: ipc.at || [cell.mon.x, cell.mon.y]
                                    readonly property var size: ipc.size || [cell.mon.w, cell.mon.h]
                                    x: Math.round((at[0] - cell.mon.x) * shot.k)
                                    y: Math.round((at[1] - cell.mon.y) * shot.k)
                                    width: Math.max(Theme.fs(18), Math.round(size[0] * shot.k))
                                    height: Math.max(Theme.fs(18), Math.round(size[1] * shot.k))
                                    z: ipc.floating ? 1 : 0
                                    radius: Theme.radiusSmall
                                    opacity: root.dragging === modelData ? 0.4 : 1
                                    color: winDrag.containsMouse ? Theme.overlay : Theme.surface
                                    border.width: Theme.borderWidth
                                    border.color: winDrag.containsMouse ? Theme.strokeHover : Theme.stroke

                                    Item {
                                        anchors.centerIn: parent
                                        width: Theme.fontTitle
                                        height: Theme.fontTitle

                                        IconImage {
                                            anchors.fill: parent
                                            visible: win.iconPath !== ""
                                            source: win.iconPath
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: win.iconPath === ""
                                            text: Apps.glyphForWindow(win.cls, win.modelData.title)
                                            color: Theme.subtext
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontIconSize
                                        }
                                    }

                                    // click focuses; drag onto a miniature moves
                                    // (hand-rolled, like BarWidgetList's grip)
                                    MouseArea {
                                        id: winDrag
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: root.dragging === win.modelData ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                        property real pressX: 0
                                        property real pressY: 0

                                        function targetAt(mouse) {
                                            return grid.targetAt(mapToItem(grid, mouse.x, mouse.y))
                                        }

                                        onPressed: mouse => {
                                            pressX = mouse.x
                                            pressY = mouse.y
                                        }

                                        onPositionChanged: mouse => {
                                            if (!pressed) return
                                            // A few pixels of slop so a click with a
                                            // shaky hand stays a click.
                                            if (root.dragging === null
                                                && Math.abs(mouse.x - pressX) < 6
                                                && Math.abs(mouse.y - pressY) < 6) return
                                            root.dragging = win.modelData
                                            root.dragPoint = mapToItem(null, mouse.x, mouse.y)
                                            const target = targetAt(mouse)
                                            root.dropTarget = target === cell.card.target ? null : target
                                        }

                                        onReleased: mouse => {
                                            const dragged = root.dragging === win.modelData
                                            const target = dragged ? targetAt(mouse) : null
                                            const addr = "address:0x" + win.modelData.address
                                            root.dropTarget = null
                                            root.dragging = null

                                            if (!dragged) {
                                                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                                                root.requestClose()
                                            } else if (target !== null && target !== cell.card.target) {
                                                // Move the dragged window, not
                                                // whatever happens to be focused.
                                                Hyprland.dispatch("hl.dsp.window.move({window=\"" + addr + "\", workspace="
                                                    + (typeof target === "number" ? target : "\"" + target + "\", follow=false") + "})")
                                                Hyprland.refreshToplevels()
                                            }
                                        }

                                        onCanceled: {
                                            root.dragging = null
                                            root.dropTarget = null
                                        }
                                    }
                                }
                            }

                            // the current one and a drop target light; hover outlines
                            Rectangle {
                                anchors.fill: parent
                                radius: shot.radius
                                color: "transparent"
                                border.width: cell.isDropTarget || cell.isFocused ? 2 : Theme.borderWidth
                                border.color: cell.isDropTarget ? Theme.accent
                                    : cell.isFocused ? Theme.selectedStroke
                                    : wsMouse.containsMouse ? Theme.strokeHover : Theme.border
                            }
                        }

                        // the name and how many windows, under it
                        Text {
                            width: shot.width
                            elide: Text.ElideRight
                            text: cell.card.title + (cell.card.windows.length > 0
                                ? " · " + cell.card.windows.length + (cell.card.windows.length === 1 ? " window" : " windows") : "")
                            color: cell.isFocused ? Theme.textStrong : cell.card.windows.length > 0 ? Theme.text : Theme.muted
                            font.family: Theme.fontText
                            font.weight: cell.isFocused ? Theme.weightStrong : Theme.weightBody
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
            }
        }
    }

    // the dragged window's icon under the pointer
    Rectangle {
        visible: root.dragging !== null
        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
        width: Theme.fontTitle * 2
        height: width
        radius: Theme.radiusInner
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.accent
        readonly property string cls: root.dragging && root.dragging.lastIpcObject ? root.dragging.lastIpcObject.class || "" : ""

        IconImage {
            anchors.centerIn: parent
            width: Theme.fontTitle
            height: width
            source: Apps.iconForClass(parent.cls)
        }
    }
}
