// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DismissGrab.qml
//
// Closes a panel on a press anywhere outside it, other monitors and windows
// included, via Hyprland's focus grab (hyprland_focus_grab_v1): the first
// outside press ends the grab, isn't passed on, and sends `cleared`.
// Hyprland also ends it when another surface takes the keyboard as it maps
// or this one goes Exclusive while mapped, so a panel keeps one focus mode.

import Quickshell.Hyprland
import QtQuick

HyprlandFocusGrab {
    // the panel: `open`, requestClose()
    required property var panel
    // surfaces besides the panel a press may land on without closing it
    // (every screen's bar, for a flyout)
    property var also: []

    active: panel.open
    windows: [panel].concat((also || []).filter(w => !!w))

    // A grab cleared after its panel has already closed (the next one took
    // over) must not close what is open now.
    onCleared: if (panel.open) panel.requestClose()
}
