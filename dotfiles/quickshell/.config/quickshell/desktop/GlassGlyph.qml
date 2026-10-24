// Singularity - Quickshell
// ~/.config/quickshell/desktop/GlassGlyph.qml
//
// A Nerd Font glyph on a GlassCard that acts as a button: dims under the
// pointer, faint while it can't act.

import QtQuick
import "../services"

GlassText {
    id: root

    property bool active: true
    signal clicked()

    font.family: Theme.fontIcon
    opacity: !active ? 0.3 : hover.containsMouse ? 0.7 : 1

    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -Theme.fit(6)
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
