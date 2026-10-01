// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowPanel.qml
//
// One framed panel inside a standalone window: the sections list or the
// open page in Settings and System. A faint surface tint over the window's
// ground, edged in the frame style like every other panel (PanelFrame).

import QtQuick
import "../services"
import "../flyouts"

PanelFrame {
    color: Theme.panelTint
    // see-through, and inside a window that has its own
    shadowed: false
}
