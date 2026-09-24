// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowChrome.qml
//
// The ground of a standalone window (Settings, System) and Escape to close
// it. Declared first in the window so the content draws over it; the title
// row is WindowHeader.qml.

import QtQuick
import "../flyouts"

Item {
    id: root

    // the FloatingWindow this dresses; needs close()
    required property var window
    // takes Escape; focus it after anything else in the window had focus
    readonly property alias keySink: keySink

    anchors.fill: parent

    PanelFrame { anchors.fill: parent }

    // Escape anywhere in the window. A text field with focus takes Escape
    // itself (to clear, or to close an editor), so this only fires when
    // nothing more local wanted it.
    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.window.close()
    }
}
