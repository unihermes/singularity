// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChip.qml
//
// A small bordered button for inline actions inside a flyout row -- the
// Log / Restart / Clear on a failed unit, the media transport controls --
// where a full-width FlyoutRow per action would bury the list under them.
//
// `confirmText` makes it two clicks, for what can't be undone: the first
// arms it -- alert-red, reading confirmText -- and the second emits
// clicked(). It disarms itself after 3s.

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
    property string confirmText: ""
    readonly property bool armed: disarm.running

    signal clicked()

    function disarmNow() { disarm.stop() }

    implicitWidth: label.implicitWidth + Theme.spaceM * 2 + (glyph && !armed ? 2 : 0)
    implicitHeight: Theme.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.armed ? Theme.alert
            : root.selected ? Theme.selectedFill
            : (root.enabled && mouse.containsMouse) ? Theme.hoverFillSoft : "transparent"
        border.width: Theme.borderWidth
        border.color: root.armed ? Theme.alert
            : root.selected ? Theme.selectedStroke
            : (root.enabled && mouse.containsMouse) ? Theme.strokeHover : Theme.stroke
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.armed ? root.confirmText : root.text
        color: !root.enabled ? Theme.textDisabled
            : root.armed ? Theme.base
            : (root.selected || mouse.containsMouse) ? Theme.textStrong : Theme.text

        font.family: root.glyph && !root.armed ? Theme.fontIcon : Theme.fontText
        font.pixelSize: root.glyph && !root.armed ? Theme.fontIconSize : Theme.fontBody
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirmText !== "" && !disarm.running) { disarm.restart(); return }
            disarm.stop()
            root.clicked()
        }
    }

    Timer { id: disarm; interval: 3000 }
}
