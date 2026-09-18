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
        item.open(arg)
    }
}
