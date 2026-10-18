// Singularity - Quickshell
// ~/.config/quickshell/windows/LazyWindow.qml
//
// Builds a window on first open; callers use open() on this.
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
        // torn down on close, so the next open is at its set size (hooked
        // here, deferred, as Connections can't see the loader's item change)
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
