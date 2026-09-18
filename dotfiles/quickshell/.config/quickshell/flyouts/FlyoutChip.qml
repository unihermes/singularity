// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChip.qml
//
// A small bordered button for inline actions inside a flyout row -- the
// Log / Restart / Clear on a failed unit, the media transport controls --
// where a full-width FlyoutRow per action would bury the list under them.

import QtQuick
import "../services"

Item {
    id: root

    property string text: ""
    // icon glyphs render bigger than letters at the same size
    property bool glyph: false
    property bool enabled: true
    // lit, for the current choice in a pair (°F / °C)
    property bool selected: false

    signal clicked()

    implicitWidth: label.implicitWidth + (glyph ? 14 : 12)
    implicitHeight: Theme.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.selected ? Theme.selectedFill
            : (root.enabled && mouse.containsMouse) ? Theme.hoverFillSoft : "transparent"
        border.width: Theme.borderWidth
        border.color: root.selected ? Theme.selectedStroke
            : (root.enabled && mouse.containsMouse) ? Theme.strokeHover : Theme.stroke
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: !root.enabled ? Theme.textDisabled
            : (root.selected || mouse.containsMouse) ? Theme.textStrong : Theme.text

        font.family: root.glyph ? Theme.fontIcon : Theme.fontText
        font.pixelSize: root.glyph ? Theme.fontIconSize : Theme.fontBody
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
