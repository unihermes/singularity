// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspaceOverlay.qml
//
// SUPER+W: a card per workspace listing its windows. Click a card to jump,
// a window to focus it, drag a window onto a card to move it. Specials with
// windows get cards; the empty numbers share one. Centred, not a
// FlyoutPanel; Theme.overviewLayout and overviewBackdrop style it.

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

    // the cards: numbered workspaces with windows, specials with windows,
    // one for the empty numbers. `target`: a number or "special:name"
    readonly property var cards: {
        const wss = Hyprland.workspaces.values
        const out = [], empty = []
        for (let id = 1; id <= workspaceCount; id++) {
            const wins = windowsOf(wss.find(w => w.id === id))
            if (wins.length > 0) out.push({ kind: "ws", target: id, title: String(id), windows: wins })
            else empty.push(id)
        }
        for (const ws of wss) {
            if (ws.id >= 0) continue
            const wins = windowsOf(ws)
            const name = String(ws.name).replace(/^special:/, "")
            if (wins.length > 0)
                out.push({ kind: "special", target: ws.name, title: name.charAt(0).toUpperCase() + name.slice(1), windows: wins })
        }
        if (empty.length > 0) out.push({ kind: "empty", target: null, title: "Empty", windows: [], ids: empty })
        return out
    }

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
        color: Theme.overviewBackdrop === "solid" ? Theme.base
            : Theme.overviewBackdrop === "clear" ? "transparent" : Theme.scrim

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
        id: box
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
                hints: ["1-" + Math.min(9, root.workspaceCount) + " jump", "Drag an app to move it", "Esc close"]
            }

            Grid {
                id: grid
                columns: Theme.overviewLayout === "strip" ? root.cards.length : Math.min(3, root.cards.length)
                spacing: Theme.spaceL

                // The drop target under a point in the grid: a card's, or
                // one of the empty card's numbers.
                function targetAt(p) {
                    const c = childAt(p.x, p.y)
                    if (!c || c.card === undefined) return null
                    if (c.card.kind !== "empty") return c.card.target
                    const q = c.mapFromItem(grid, p.x, p.y)
                    const chip = c.chipAt(q)
                    return chip ? chip.wsId : null
                }

                Repeater {
                    model: root.cards

                    Rectangle {
                        id: cell
                        required property var modelData
                        readonly property var card: modelData
                        readonly property bool isFocused: card.kind === "ws"
                            && Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === card.target
                        readonly property bool isDropTarget: card.kind !== "empty" && root.dropTarget === card.target

                        function chipAt(q) {
                            const c = chips.childAt(q.x - chips.x, q.y - chips.y)
                            return c && c.wsId !== undefined ? c : null
                        }

                        // a row of every card has to fit the screen
                        readonly property real shrink: Theme.overviewLayout === "strip"
                            ? Math.min(1, (root.width * 0.9 / root.cards.length - grid.spacing) / Theme.fs(240)) : 1
                        // the empty card as wide as its numbers in one line
                        width: card.kind === "empty"
                            ? Theme.spaceL * 2 + card.ids.length * (Theme.rowHeightTall + Theme.spaceS) - Theme.spaceS
                            : Math.round(Theme.fs(240) * shrink)
                        height: Math.max(Theme.fs(150), list.y + list.implicitHeight + Theme.spaceM)
                        radius: Theme.radiusInner
                        // the current workspace is lit as the power menu's
                        // current row is; a drop target takes the accent
                        color: isDropTarget || isFocused ? Theme.selectedFill : Theme.surface
                        border.width: Theme.borderWidth
                        border.color: isDropTarget ? Theme.accent
                            : isFocused ? Theme.selectedStroke
                            : wsMouse.containsMouse ? Theme.strokeHover
                            : Theme.border
                        opacity: card.kind === "empty" ? 0.75 : 1

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.durFast }
                        }

                        // Jump to this workspace. Sits behind the window rows, so a
                        // click that lands on a row focuses that window instead.
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            enabled: cell.card.kind !== "empty"
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.jump(cell.card.target)
                        }

                        Text {
                            x: Theme.spaceL
                            y: Theme.spaceM
                            text: cell.card.title
                            color: cell.isFocused ? Theme.textStrong : Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontBody
                            font.weight: cell.isFocused ? Theme.weightStrong : Theme.weightBody
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceL
                            y: Theme.spaceM
                            visible: cell.card.kind !== "empty"
                            text: cell.card.windows.length + (cell.card.windows.length === 1 ? " window" : " windows")
                            color: Theme.muted
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontSmall
                        }

                        // the empty card: its numbers, each a jump and a drop
                        Flow {
                            id: chips
                            visible: cell.card.kind === "empty"
                            x: Theme.spaceL
                            y: Theme.spaceM + Theme.rowHeight + Theme.spaceS
                            width: parent.width - Theme.spaceL * 2
                            spacing: Theme.spaceS

                            Repeater {
                                model: cell.card.ids || []

                                Rectangle {
                                    required property int modelData
                                    readonly property int wsId: modelData
                                    width: Theme.rowHeightTall
                                    height: Theme.rowHeightTall
                                    radius: Theme.radiusInner
                                    color: root.dropTarget === wsId ? Theme.selectedFill
                                        : chipMouse.containsMouse ? Theme.hoverFill : "transparent"
                                    border.width: Theme.borderWidth
                                    border.color: root.dropTarget === wsId ? Theme.accent : Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.wsId
                                        color: Theme.textStrong
                                        font.family: Theme.fontText
                                        font.weight: Theme.weightStrong
                                        font.pixelSize: Theme.fontTitle
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.jump(parent.wsId)
                                    }
                                }
                            }
                        }

                        Column {
                            id: list
                            x: Theme.spaceM
                            y: Theme.spaceM + Theme.rowHeight + Theme.spaceS
                            width: parent.width - Theme.spaceM * 2
                            spacing: Theme.spaceXs

                            Repeater {
                                model: cell.card.windows

                                Rectangle {
                                    id: winRow
                                    required property var modelData
                                    readonly property string cls:
                                        (modelData.lastIpcObject && modelData.lastIpcObject.class) || ""

                                    width: parent.width
                                    height: Theme.rowHeightTall
                                    radius: Theme.radiusSmall
                                    color: winDrag.dragging ? Theme.selectedFill
                                        : winDrag.containsMouse ? Theme.hoverFill
                                        : Theme.panel

                                    Item {
                                        id: winIco
                                        x: Theme.spaceM
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Theme.fontIconSize
                                        height: Theme.fontIconSize

                                        readonly property string iconPath: Apps.iconForClass(winRow.cls)

                                        IconImage {
                                            anchors.fill: parent
                                            visible: winIco.iconPath !== ""
                                            source: winIco.iconPath
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: winIco.iconPath === ""
                                            text: Apps.glyphForWindow(winRow.cls, winRow.modelData.title)
                                            color: Theme.subtext
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontIconSize
                                        }
                                    }

                                    // the app's name, then the window's title quieter
                                    Text {
                                        id: appName
                                        anchors.left: winIco.right
                                        anchors.leftMargin: Theme.spaceM
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, parent.width - x - Theme.spaceM)
                                        elide: Text.ElideRight
                                        text: Apps.nameForWindow(winRow.cls, winRow.modelData.title)
                                        color: winDrag.containsMouse ? Theme.textStrong : Theme.text
                                        font.family: Theme.fontText
                                        font.weight: Theme.weightBody
                                        font.pixelSize: Theme.fontBody
                                    }

                                    Text {
                                        anchors.left: appName.right
                                        anchors.leftMargin: Theme.spaceM
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spaceM
                                        anchors.baseline: appName.baseline
                                        elide: Text.ElideRight
                                        text: winRow.modelData.title !== appName.text ? winRow.modelData.title || "" : ""
                                        color: Theme.subtext
                                        font.family: Theme.fontText
                                        font.weight: Theme.weightBody
                                        font.pixelSize: Theme.fontCaption
                                    }

                                    // click focuses; drag onto a card moves
                                    // (hand-rolled, like BarWidgetList's grip)
                                    MouseArea {
                                        id: winDrag
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                        property bool dragging: false
                                        property real pressX: 0
                                        property real pressY: 0

                                        function targetAt(mouse) {
                                            return grid.targetAt(mapToItem(grid, mouse.x, mouse.y))
                                        }

                                        onPressed: mouse => {
                                            pressX = mouse.x
                                            pressY = mouse.y
                                            dragging = false
                                        }

                                        onPositionChanged: mouse => {
                                            if (!pressed) return
                                            // A few pixels of slop so a click with a
                                            // shaky hand stays a click.
                                            if (!dragging
                                                && Math.abs(mouse.x - pressX) < 6
                                                && Math.abs(mouse.y - pressY) < 6) return
                                            dragging = true
                                            const target = targetAt(mouse)
                                            root.dropTarget = target === cell.card.target ? null : target
                                        }

                                        onReleased: mouse => {
                                            const target = dragging ? targetAt(mouse) : null
                                            const addr = "address:0x" + winRow.modelData.address
                                            root.dropTarget = null

                                            if (!dragging) {
                                                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                                                root.requestClose()
                                            } else if (target !== null && target !== cell.card.target) {
                                                // Move the dragged window, not
                                                // whatever happens to be focused.
                                                Hyprland.dispatch("hl.dsp.window.move({window=\"" + addr + "\", workspace="
                                                    + (typeof target === "number" ? target : "\"" + target + "\", follow=false") + "})")
                                                Hyprland.refreshToplevels()
                                            }
                                            dragging = false
                                        }

                                        onCanceled: {
                                            dragging = false
                                            root.dropTarget = null
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
