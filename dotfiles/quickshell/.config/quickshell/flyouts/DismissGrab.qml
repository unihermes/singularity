// Singularity - Quickshell
// ~/.config/quickshell/flyouts/DismissGrab.qml
//
// Closes a panel on a press anywhere outside it: over a window, on the other
// monitor, on another layer. A panel's Backdrop only covers its own screen,
// so before this a flyout stayed up while you clicked away on the next
// monitor, and an Exclusive overlay (the launcher) kept the keyboard there.
//
// Hyprland's focus grab (hyprland_focus_grab_v1), as end-4's, DMS's,
// Caelestia's and Noctalia's shells use for theirs. While it's active the
// compositor keeps pointer and keyboard on the listed surfaces; the first
// press anywhere else ends it, is not passed on (a menu's click-off, not a
// click-through), and sends `cleared`. Keyboard focus comes back to the
// window when the panel unmaps.
//
// Two ways Hyprland ends a grab by itself, both of which read as a click
// off: a surface outside it taking the keyboard as it maps, and a surface
// going to Exclusive keyboard focus while mapped. So a panel stays at one
// focus mode while open; it doesn't step up to Exclusive partway.

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
