// Singularity - Quickshell
// ~/.config/quickshell/flyouts/LazyFlyout.qml
//
// Builds a flyout the first time it's opened instead of at login. Every
// flyout is its own layer-shell window with a full tree of rows, and most
// sessions open only a few of them, so creating all of them up front was
// most of the shell's startup time for nothing.
//
// Once built it stays: closing only hides it, as before, so reopening is
// instant and the flyout keeps its own state (onOpenChanged still fires on
// close). ensure() builds it on demand for a caller that has to hand the
// flyout something before it opens (the tray menu's item).
//
//   LazyFlyout {
//       name: "network"; scope: screenScope
//       NetworkFlyout { scope: screenScope; bar: bar }
//   }

import Quickshell
import QtQuick

LazyLoader {
    id: root

    // the flyout's name in scope.openFlyout
    required property string name
    required property var scope

    property bool used: false
    readonly property bool wanted: scope.openFlyout === name
    onWantedChanged: if (wanted) used = true

    active: used || wanted

    function ensure() {
        used = true
        return item
    }
}
