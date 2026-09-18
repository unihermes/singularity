// Singularity - Quickshell
// ~/.config/quickshell/AltTabSwitcher.qml
//
// The ALT+Tab switcher: a row of the open windows, most-recently-used first,
// with one highlighted. Hold ALT and tap Tab to step the highlight along,
// release ALT to focus what you landed on.
//
// The selection lives here, not in Hyprland. Hyprland's own cycle_next walks
// windows as it focuses them, so every tap would raise a window and resize the
// layout just to preview it -- and its reverse direction does not work. Here
// nothing is focused until ALT comes up, so stepping through is free and
// SHIFT+Tab is just -1.
//
// Keys arrive by two routes, which is a constraint rather than a choice.
// Hyprland matches its own binds before forwarding keys to any client, so
// ALT+Tab, SHIFT+Tab and grave never reach this window at all -- they run
// alt-tab.sh, which steps an already-open switcher over IPC. The ALT
// *release* is the opposite case: Hyprland will not deliver a modifier
// release to a bind, so this window takes the keyboard and catches it in
// Keys.onReleased. Escape is handled here too, being unbound on that side.

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import "../services"

PanelWindow {
    id: root

    required property var scope
    readonly property bool open: scope.openFlyout === "alttab"

    // The window list is captured once, by begin(), rather than tracked live.
    // Focus history reorders itself the moment anything is focused, so a live
    // binding would reshuffle the row under the highlight mid-cycle; and the
    // list must survive `open` going true, which happens after begin().
    property var windows: []

    property int selected: 0

    // MRU order: Hyprland's focusHistoryID counts 0 = focused, 1 = the one
    // before it, and so on -- exactly the order alt-tab should walk.
    // Start on the previous window, not the current one, so a single
    // tap-and-release is a straight there-and-back swap.
    // `clientsJson` is `{"clients": <raw output of hyprctl clients -j>}`,
    // handed over unparsed by alt-tab.sh. Wrapped in an object because `qs
    // ipc call` splits a bare top-level JSON array argument into multiple
    // positional arguments instead of passing it through as one string --
    // begin() only takes one, so the call itself would fail before any QML
    // here even ran.
    //
    // The filtering and ordering happen here, in the already-running shell
    // process, rather than in a subprocess on the bash side. Shelling out
    // (previously to python3) added a process start to the critical path
    // between the ALT+Tab bind firing and this window actually holding the
    // keyboard -- and that gap is the only window in which a fast ALT release
    // can be missed (see Keys.onReleased below), so it needs to be as short as
    // possible.
    //
    // The list still has to come from hyprctl rather than Hyprland.toplevels,
    // though: Quickshell caches each toplevel's lastIpcObject and only
    // refetches on request, and refreshToplevels() is asynchronous -- so
    // focusHistoryID (and workspace membership) read from here would be
    // whatever it was at the last refresh, not what it is now. Sorting on
    // that works exactly once and then sticks, always offering the same
    // window back. hyprctl is the source of truth, so the caller reads it
    // fresh and hands over the answer.
    function begin(clientsJson) {
        let clients
        try { clients = JSON.parse(clientsJson).clients } catch (e) { clients = [] }

        const cs = (clients || []).filter(c => c.class && c.class !== "org.quickshell")

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
            if (o && o.class && o.class !== "org.quickshell") byAddr["0x" + tl.address] = tl
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

    // Focus the highlighted window. Close first, focus second.
    //
    // The order matters and is not cosmetic. This window holds an exclusive
    // keyboard grab while it is up, and a layershell releasing that grab hands
    // focus back to whatever held it before -- so focusing while still on
    // screen got immediately undone, which is why the commit looked like it
    // did nothing even though the dispatch was correct. Dropping `open` first
    // lets the grab go, and the focus then lands for good.
    //
    // That grab release also fires its own focus event, bouncing focus back to
    // whatever was active before the switcher opened -- and the timing of that
    // bounce-back is Hyprland's, not ours, so it can land either before or
    // after the real focus dispatch below. When it lands after, it silently
    // steals focus back to the old window: hyprland.lua's window.active hook
    // still maximizes whatever ends up focused, so nothing is left half-sized,
    // but you end up looking at the wrong window -- the one from before the
    // switcher opened, not the one you actually selected. retryTimer redoes
    // the same focus dispatch once more, shortly after, so whichever window
    // the bounce-back leaves focused gets corrected back to the real target.
    //
    // Maximizing itself is no longer this file's problem: that used to be
    // dispatched from here too, straight after focus, because the old
    // implementation shelled a script out over hyprctl for every focus change
    // and that round trip was slow enough for the bounce-back to land in the
    // middle of it. hyprland.lua's hook now runs in-process on Hyprland's own
    // event thread, so it always finishes maximizing inside the same tick as
    // the focus event that triggered it -- there is nothing left here to race.
    function commit() {
        const win = windows[selected]
        scope.openFlyout = ""
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

    function cancel() { scope.openFlyout = "" }

    screen: scope.modelData
    visible: open && windows.length > 0
    anchors { top: true; left: true; right: true; bottom: true }
    // As in FlyoutPanel: anchors alone leave a PanelWindow at 100x100.
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, because this is the only way to see the ALT release: Hyprland
    // will not deliver a modifier release to a bind (verified by probe -- an
    // Alt_L release bind, with ignore_mods, never fired once), but a focused
    // Wayland client gets raw key events including modifier releases.
    //
    // A `hyprland-global-shortcuts-v1` GlobalShortcut on bare Alt_L/Alt_R was
    // tried here as a second, focus-independent route to the release, to
    // close the gap between alt-tab.sh's IPC round trip and this window
    // actually holding the keyboard. Reverted: registering a global shortcut
    // on a bare modifier changed how Hyprland treats that key everywhere, not
    // just here -- ALT is also the window drag/resize mod, and releasing it
    // after any of that started tearing down the switcher and refocusing
    // whatever the mouse was over instead of the selected window. The
    // remaining fix for a fast tap missing this grab is cutting latency out
    // of alt-tab.sh's round trip (see its own comments), not a second catch
    // for the release itself.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "singularity-alttab"

    // Focus has to land on the item for Keys handlers to see anything, and
    // only once the window is actually up -- grabbing before that silently
    // does nothing.
    onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        // Only Escape: Tab, SHIFT+Tab and grave are bound in hyprland.lua and
        // Hyprland consumes them before this window ever sees them, so
        // handling them here would be dead code. Escape is not bound there, so
        // it reaches the client and is handled here.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.cancel()
                event.accepted = true
            }
        }

        // The ALT release commits -- the event Hyprland would not hand over,
        // and the reason this window takes the keyboard at all. Close if the
        // Alt key itself is released, OR if any other key is released while
        // Alt is no longer held. The latter catches the case where Tab is
        // released after Alt, or where Alt is released before Tab and Tab's
        // release event needs to close the switcher anyway.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || !(event.modifiers & Qt.AltModifier)) {
                root.commit()
                event.accepted = true
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35
    }

    PanelFrame {
        anchors.centerIn: parent
        width: Math.min(root.width - 80, list.width + 40)
        height: list.height + 40

        Row {
            id: list
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.windows

                Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool active: index === root.selected
                    readonly property string cls: modelData.lastIpcObject.class || ""

                    width: 128
                    height: 116
                    radius: Theme.radiusInner
                    color: active ? Theme.overlay : Theme.surface
                    border.width: 1
                    border.color: active ? Theme.bright : Theme.border

                    // No Behavior on colour here: the highlight has to keep up
                    // with held-Tab autorepeat, and a fade would smear it.

                    IconImage {
                        id: ico
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        implicitSize: 48
                        opacity: card.active ? 1 : 0.55
                        source: {
                            const e = DesktopEntries.heuristicLookup(card.cls)
                            return e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: ico.bottom
                        anchors.topMargin: 10
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        text: card.modelData.lastIpcObject.title || card.cls
                        color: card.active ? Theme.text : Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontSmall
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
    }
}
