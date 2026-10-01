// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspaceOverlay.qml
//
// SUPER+W: every workspace at once, as a grid of cells. Click a cell to jump
// to that workspace, click a window inside one to focus just that window, or
// drag a window from one cell to another to move it there.
//
// Not a FlyoutPanel: those hang off the bar under the module that opened them
// and lay their content out in a Column. This is centred on the screen and
// grid-shaped, so it only borrows the pattern (full-screen transparent layer
// with a backdrop that closes on click), not the component.
//
// Three across or one row (Theme.overviewLayout), over the desktop dimmed,
// clear, or hidden behind the look's ground (Theme.overviewBackdrop).

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

    // Hyprland reports workspace ids, but the grid should show the fixed
    // workspaces the binds use whether or not they currently exist -- an empty
    // workspace has no id to enumerate, and jumping to one is still valid.
    readonly property int workspaceCount: Settings.workspaceCount

    // Which cell a drag is currently hovering, so it can highlight. -1 for none.
    property int dropTarget: -1

    // The shell's own standalone windows are part of the bar, not apps you're
    // running, so they're left out of the cells and the counts -- same rule the
    // bar's window strip and WINDOWS flyout follow.
    function isShellWindow(tl) {
        return !!(tl.lastIpcObject && tl.lastIpcObject.class === "org.quickshell")
    }

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

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    // Keys attaches to Items, not to the window itself -- putting these
    // directly on the PanelWindow silently does nothing ("Could not attach
    // Keys property ... is not an Item"), so they live on a focused Item.
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

        // absorbs clicks so they don't reach the backdrop and close the overlay
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

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
                columns: Theme.overviewLayout === "strip" ? root.workspaceCount : Math.min(3, root.workspaceCount)
                spacing: Theme.spaceL

                Repeater {
                    model: root.workspaceCount

                    // One workspace. `index` is 0-based, Hyprland ids are 1-based.
                    Rectangle {
                        id: cell
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool isFocused:
                            Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool isDropTarget: root.dropTarget === wsId
                        // Hyprland only creates a workspace object once something is
                        // on it, so an empty workspace legitimately has none.
                        readonly property var windows: {
                            const ws = Hyprland.workspaces.values.find(w => w.id === cell.wsId)
                            if (!ws || !ws.toplevels) return []
                            return ws.toplevels.values.filter(tl => !root.isShellWindow(tl) && !Apps.isBackTabToplevel(tl))
                        }

                        // a row of every workspace has to fit the screen
                        readonly property real shrink: Theme.overviewLayout === "strip"
                            ? Math.min(1, (root.width * 0.9 / root.workspaceCount - grid.spacing) / Theme.fs(200)) : 1
                        width: Math.round(Theme.fs(200) * shrink)
                        height: Math.round(Theme.fs(132) * shrink)
                        radius: Theme.radiusInner
                        // the current workspace is lit as the power menu's
                        // current tile is; a drop target takes the accent
                        color: isDropTarget || cell.isFocused ? Theme.selectedFill : Theme.surface
                        border.width: Theme.borderWidth
                        border.color: isDropTarget ? Theme.accent
                            : cell.isFocused ? Theme.selectedStroke
                            : wsMouse.containsMouse ? Theme.strokeHover
                            : Theme.border

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.durFast }
                        }

                        // Jump to this workspace. Sits behind the window rows, so a
                        // click that lands on a row focuses that window instead.
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Hyprland.dispatch("hl.dsp.focus({workspace=" + cell.wsId + "})")
                                root.requestClose()
                            }
                        }

                        Text {
                            x: Theme.spaceL
                            y: Theme.spaceM
                            text: cell.wsId
                            color: cell.isFocused ? Theme.textStrong : Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontBody
                            font.bold: cell.isFocused
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceL
                            y: Theme.spaceM
                            text: cell.windows.length === 0 ? "empty"
                                : cell.windows.length + (cell.windows.length === 1 ? " window" : " windows")
                            color: Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: Theme.fontSmall
                        }

                        Column {
                            x: Theme.spaceL
                            y: Theme.spaceM + Theme.rowHeight
                            width: parent.width - Theme.spaceL * 2
                            spacing: Theme.spaceXs

                            Repeater {
                                model: cell.windows

                                Rectangle {
                                    id: winRow
                                    required property var modelData
                                    readonly property string cls:
                                        (modelData.lastIpcObject && modelData.lastIpcObject.class) || ""

                                    width: parent.width
                                    height: Theme.rowHeightDense
                                    radius: Theme.radiusSmall
                                    color: winDrag.dragging ? Theme.selectedFill
                                        : winDrag.containsMouse ? Theme.hoverFill
                                        : "transparent"

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spaceS
                                        anchors.rightMargin: Theme.spaceS
                                        spacing: Theme.spaceM

                                        Item {
                                            id: winIco
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitWidth: Theme.fontSmall
                                            implicitHeight: Theme.fontSmall

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
                                                font.pixelSize: Theme.fontSmall
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - winIco.width - parent.spacing

                                            elide: Text.ElideRight
                                            text: winRow.modelData.title || winRow.cls
                                            color: Theme.subtext
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.fontSmall
                                        }
                                    }

                                    // Click focuses this window; dragging it onto
                                    // another cell moves it there instead.
                                    //
                                    // Hand-rolled rather than Qt's Drag/DropArea to
                                    // match BarWidgetList's reorder grip, the only
                                    // other drag in the shell: press, track the
                                    // pointer against each cell's bounds, act on
                                    // release. Nothing here needs a drag proxy item
                                    // or mime data, so the native API would only add
                                    // moving parts.
                                    MouseArea {
                                        id: winDrag
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                        property bool dragging: false
                                        property real pressX: 0
                                        property real pressY: 0

                                        function workspaceAt(mouse) {
                                            const p = mapToItem(grid, mouse.x, mouse.y)
                                            for (let i = 0; i < grid.children.length; i++) {
                                                const c = grid.children[i]
                                                if (c.wsId === undefined) continue
                                                if (p.x >= c.x && p.x <= c.x + c.width
                                                    && p.y >= c.y && p.y <= c.y + c.height) return c.wsId
                                            }
                                            return -1
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
                                            const target = workspaceAt(mouse)
                                            root.dropTarget = target === cell.wsId ? -1 : target
                                        }

                                        onReleased: mouse => {
                                            const target = dragging ? workspaceAt(mouse) : -1
                                            const addr = "address:0x" + winRow.modelData.address
                                            root.dropTarget = -1

                                            if (!dragging) {
                                                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                                                root.requestClose()
                                            } else if (target !== -1 && target !== cell.wsId) {
                                                // Move the dragged window, not
                                                // whatever happens to be focused.
                                                Hyprland.dispatch("hl.dsp.window.move({window=\"" + addr
                                                    + "\", workspace=" + target + "})")
                                                Hyprland.refreshToplevels()
                                            }
                                            dragging = false
                                        }

                                        onCanceled: {
                                            dragging = false
                                            root.dropTarget = -1
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cell.windows.length === 0
                            text: "󰇘"
                            color: Theme.muted
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontIconSize
                        }
                    }
                }
            }
        }
    }
}
