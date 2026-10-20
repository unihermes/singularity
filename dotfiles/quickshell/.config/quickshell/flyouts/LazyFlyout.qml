// Singularity - Quickshell
// ~/.config/quickshell/flyouts/LazyFlyout.qml
//
// Builds a flyout on first open, then keeps it (closing hides it). ensure()
// builds it early for a caller that must hand it something first.
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
