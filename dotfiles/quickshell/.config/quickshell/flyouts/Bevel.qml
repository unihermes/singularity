// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Bevel.qml
//
// A chiselled 3D edge -- light on two sides, dark on the other two -- the
// classic Windows 95 "raised button" (or, inverted, "sunken well") frame.
// Four thin Rectangles rather than Rectangle.border, which can only take one
// colour for all four sides.
//
// Caller positions it (anchors.fill: parent, with margins for a second,
// inset level) rather than this component claiming anchors.fill itself, so
// PanelFrame and ModuleFrame can stack an outer raised bevel and an inner
// sunken one the way a real Win95 window frame does.

import QtQuick
import "../services"

Item {
    id: root

    required property color light
    required property color dark
    // top+left light / bottom+right dark reads as pushed toward the
    // viewer; false swaps them for a pressed-in groove
    property bool raised: true
    property int thickness: Theme.borderWidth

    Rectangle {
        x: 0; y: 0
        width: parent.width; height: root.thickness
        color: root.raised ? root.light : root.dark
    }
    Rectangle {
        x: 0; y: 0
        width: root.thickness; height: parent.height
        color: root.raised ? root.light : root.dark
    }
    Rectangle {
        x: 0; y: parent.height - root.thickness
        width: parent.width; height: root.thickness
        color: root.raised ? root.dark : root.light
    }
    Rectangle {
        x: parent.width - root.thickness; y: 0
        width: root.thickness; height: parent.height
        color: root.raised ? root.dark : root.light
    }
}
