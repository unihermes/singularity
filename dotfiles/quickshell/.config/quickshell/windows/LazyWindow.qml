// Singularity - Quickshell
// ~/.config/quickshell/windows/LazyWindow.qml
//
// Builds a window (Settings, System, Keybinds) the first time it's opened
// instead of at login, then keeps it: closing only hides it, as before.
// Callers use open() on this rather than on the window, which may not exist
// yet.
//
//   LazyWindow { id: system; System {} }
//   system.open()

import Quickshell
import QtQuick

LazyLoader {
    id: root

    property bool used: false
    active: used

    function open(arg) {
        used = true
        var w = item
        // Torn down on close, so the next open builds a fresh window at its
        // set size. Kept alive, Hyprland would remap it at whatever size it
        // was dragged to. Hooked here rather than with Connections, since the
        // loader's item isn't a property Connections sees change. Deferred:
        // the window is still inside its own handler.
        if (hooked !== w) {
            hooked = w
            w.visibleChanged.connect(() => {
                if (!w.visible) Qt.callLater(() => { if (root.item === w && !w.visible) root.used = false })
            })
        }
        w.open(arg)
    }

    property var hooked: null
}
