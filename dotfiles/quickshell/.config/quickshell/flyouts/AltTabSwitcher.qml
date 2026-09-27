// Singularity - Quickshell
// ~/.config/quickshell/flyouts/AltTabSwitcher.qml
//
// The ALT+Tab switcher: a row of the open windows, most-recently-used first,
// with one highlighted. Hold ALT and tap Tab to step the highlight along,
// release ALT to focus what you landed on.
//
// The selection lives here, not in Hyprland: cycle_next focuses (and
// raises) each window as it walks. Here nothing is focused until ALT comes
// up, and SHIFT+Tab is just -1.
//
// Keys arrive by two routes. Hyprland's binds win over any client, so
// ALT+Tab, SHIFT+Tab and grave never reach this window -- they run
// alttab-ipc.sh, which steps it over IPC. But Hyprland won't deliver a
// modifier release to a bind, so this window takes the keyboard to catch
// the ALT release in Keys.onReleased. Escape is handled here too.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import "../services"

OverlayWindow {
    id: root

    readonly property bool open: scope.openFlyout === "alttab"

    // The window list is captured once, by begin(), rather than tracked live.
    // Focus history reorders itself the moment anything is focused, so a live
    // binding would reshuffle the row under the highlight mid-cycle; and the
    // list must survive `open` going true, which happens after begin().
    property var windows: []

    property int selected: 0

    // The gesture this switcher belongs to, from the Tab press that opened
    // it (hyprland.lua's altTabWatchGen, carried through the relay). -1 when
    // the caller sent none. shell.qml matches the ALT release against it --
    // see the altTabPendingCommitGen comment there.
    property int gen: -1

    // MRU order: focusHistoryID 0 is the focused window, 1 the one before.
    // Start on 1, so a single tap-and-release swaps back and forth.
    //
    // `clientsJson` is `{"gen": N, "clients": <what hyprctl clients -j
    // prints>}`, from alttab-relay (or alttab-ipc.sh without it) -- an
    // object, because `qs ipc call` splits a top-level array into several
    // arguments.
    //
    // Read fresh from Hyprland for each gesture rather than from
    // Hyprland.toplevels: Quickshell's cached lastIpcObject only refreshes
    // on request, asynchronously, so its focusHistoryID is stale.
    function begin(clientsJson) {
        let clients
        let parsed
        try { parsed = JSON.parse(clientsJson) } catch (e) { parsed = {} }
        clients = parsed.clients
        gen = parsed.gen === undefined ? -1 : parsed.gen

        // the shell's own windows (Settings, System, Keybinds) are in here
        // like any other toplevel: they can be focused and worked in, so
        // ALT+Tab reaches them
        const cs = (clients || []).filter(c => c.class)

        // Only offer windows on the workspace you're actually looking at.
        // That's the focused window's workspace (focusHistoryID 0) rather
        // than some separately-queried "current workspace", so it's exactly
        // the workspace this same read of hyprctl agrees you're on.
        const current = cs.find(c => c.focusHistoryID === 0)
        const onWs = current
            ? cs.filter(c => c.workspace && c.workspace.id === current.workspace.id)
            : cs
        onWs.sort((a, b) => a.focusHistoryID - b.focusHistoryID)

        const byAddr = {}
        for (const tl of Hyprland.toplevels.values) {
            const o = tl.lastIpcObject
            if (o && o.class) byAddr["0x" + tl.address] = tl
        }

        const out = []
        for (const c of onWs) if (byAddr[c.address]) out.push(byAddr[c.address])

        windows = out
        selected = out.length > 1 ? 1 : 0
    }

    function step(delta) {
        const n = windows.length
        if (n === 0) return
        selected = ((selected + delta) % n + n) % n
    }

    // Focus the highlighted window. Close first, focus second: releasing
    // this window's keyboard grab hands focus back to whoever had it before,
    // which would undo a focus made while still open.
    //
    // That release also bounces focus back on Hyprland's own timing, which
    // can land after the focus below; retryTimer repeats the focus once,
    // shortly after, to correct it. Maximizing is hyprland.lua's focus hook.
    function commit() {
        const win = windows[selected]
        scope.openFlyout = ""
        // Both routes to the ALT release fire on every gesture; this marks
        // the gesture done, so shell.qml can tell the second from a release
        // that beat the switcher onto the screen.
        scope.altTabCommittedGen = Math.max(scope.altTabCommittedGen, scope.altTabOpenGen)
        scope.altTabOpenGen = -1
        if (win) {
            const addr = win.address
            const addr_str = "address:0x" + addr
            const refocus = () => {
                Hyprland.dispatch("hl.dsp.focus({window=\"" + addr_str + "\"})")
            }
            const bringToTop = () => {
                Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr_str + "\"})")
            }
            Qt.callLater(refocus)
            Qt.callLater(bringToTop)
            retryTimer.action = refocus
            retryTimer.restart()
        }
    }

    Timer {
        id: retryTimer
        interval: 150
        property var action: null
        onTriggered: if (action) action()
    }

    // Escape. Marks the gesture committed too, so the ALT release still to
    // come isn't kept as one waiting for a switcher.
    function cancel() {
        scope.openFlyout = ""
        scope.altTabCommittedGen = Math.max(scope.altTabCommittedGen, scope.altTabOpenGen)
        scope.altTabOpenGen = -1
    }

    visible: open && windows.length > 0
    // Exclusive, because a focused client is the only thing that sees a
    // modifier release. A release before this window has the keyboard is
    // caught by hyprland.lua's key-state poll instead; this grab is the fast
    // path, and whichever notices first wins. (Not a GlobalShortcut on bare
    // ALT: that changes how Hyprland treats ALT everywhere.)
    focusMode: WlrKeyboardFocus.Exclusive
    layerNamespace: "singularity-alttab"

    // Focus has to land on the item for Keys handlers to see anything, and
    // only once the window is actually up -- grabbing before that silently
    // does nothing.
    onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        // Only Escape: Tab, SHIFT+Tab and grave are bound in hyprland.lua and
        // never reach this window.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.cancel()
                event.accepted = true
            }
        }

        // The ALT release commits: ALT itself coming up, or any other key
        // coming up once ALT is no longer held (Tab released after ALT).
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || !(event.modifiers & Qt.AltModifier)) {
                root.commit()
                event.accepted = true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
    }

    // Cards wrap onto more rows once a row would be wider than the screen;
    // a short list is still one centred row. The cards are icons only; the
    // highlighted window's app and title are the caption under the grid,
    // where they have the frame's whole width instead of a card's.
    readonly property int cardW: Theme.fs(80)
    // the launcher's padding inside the frame, and as much again outside it
    readonly property int pad: Theme.panelPad * 2
    readonly property int maxColumns: Math.max(1, Math.floor((width - pad * 6 + list.spacing) / (cardW + list.spacing)))
    // the caption may widen the frame past a short row, up to this
    readonly property int captionMax: Math.min(Theme.fs(560), width - pad * 6)

    function titleOf(win) {
        const o = win ? win.lastIpcObject : null
        return o ? (o.title || o.class || "") : ""
    }

    // Sized for the longest title, not the highlighted one, so the frame
    // holds still while Tab walks the row.
    FontMetrics {
        id: captionMetrics
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }
    readonly property int captionW: {
        let w = 0
        for (const win of windows) w = Math.max(w, captionMetrics.advanceWidth(titleOf(win)))
        return Math.ceil(w)
    }

    PanelFrame {
        anchors.centerIn: parent
        width: body.width + root.pad * 2
        height: Math.min(root.height - root.pad * 4, body.height + root.pad * 2)
        // only matters past what even a wrapped grid can show (several
        // dozen windows): the rows that don't fit are cut off inside the
        // frame instead of spilling out of it
        clip: true

        Column {
            id: body
            anchors.centerIn: parent
            spacing: Theme.spaceXl
            width: Math.max(list.width, Math.min(root.captionW, root.captionMax))

            Grid {
                id: list
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spaceL
                columns: Math.min(root.windows.length, root.maxColumns)

                Repeater {
                    model: root.windows

                    Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.selected
                        readonly property var ipc: modelData.lastIpcObject || ({})
                        readonly property string cls: ipc.class || ""

                        width: root.cardW
                        height: root.cardW
                        radius: Theme.radiusInner
                        color: active ? Theme.selectedFill : Theme.surface
                        border.width: Theme.borderWidth
                        border.color: active ? Theme.selectedStroke : Theme.stroke

                        // No Behavior on colour here: the highlight has to keep up
                        // with held-Tab autorepeat, and a fade would smear it.

                        Item {
                            id: ico
                            anchors.centerIn: parent
                            implicitWidth: Theme.fs(48)
                            implicitHeight: Theme.fs(48)
                            opacity: card.active ? 1 : 0.55

                            readonly property string iconPath: Apps.iconForClass(card.cls)

                            IconImage {
                                anchors.fill: parent
                                visible: ico.iconPath !== ""
                                source: ico.iconPath
                            }

                            // the shell's own windows, and anything else with no
                            // themed icon: a glyph rather than an empty card
                            Text {
                                anchors.centerIn: parent
                                visible: ico.iconPath === ""
                                text: Apps.glyphForWindow(card.cls, card.ipc.title)
                                color: Theme.text
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fs(40)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selected = card.index
                                root.commit()
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spaceXs

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    readonly property var ipc: root.windows[root.selected] ? root.windows[root.selected].lastIpcObject : null
                    text: ipc ? Apps.nameForWindow(ipc.class, ipc.title) : ""
                    color: Theme.textDisabled
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    text: root.titleOf(root.windows[root.selected])
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontBody
                }
            }
        }
    }
}
