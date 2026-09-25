// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PanelFrame.qml
//
// The panel ground every flyout and standalone window shares. How the frame
// itself is drawn is Theme.frameStyle:
//   double  the #141414 fill, an outer stroke, and a second stroke inset 3px
//           inside it -- Neutrino's own look
//   single  the outer stroke alone
//   bevel   a raised chisel outside, a sunken one inside -- Windows 95
//   none    no stroke -- the ground alone marks the edge
// ModuleFrame is the bar chip's tighter version of the same look.

import QtQuick
import "../services"

Rectangle {
    id: root

    radius: Theme.radius
    color: Theme.panelFill
    border.width: Theme.frameBevel || Theme.frameNone ? 0 : Theme.borderWidth
    border.color: Theme.stroke

    Bevel {
        visible: Theme.frameBevel
        anchors.fill: parent
        light: Theme.bevelLight
        dark: Theme.bevelDark
        thickness: Theme.borderWidth
    }

    Rectangle {
        anchors.fill: parent
        visible: Theme.frameDouble
        anchors.margins: Theme.frameInset
        // follows the outer corners, so a panel with some corners squared
        // off keeps both strokes parallel
        topLeftRadius: Math.max(0, root.topLeftRadius - Theme.frameInset)
        topRightRadius: Math.max(0, root.topRightRadius - Theme.frameInset)
        bottomLeftRadius: Math.max(0, root.bottomLeftRadius - Theme.frameInset)
        bottomRightRadius: Math.max(0, root.bottomRightRadius - Theme.frameInset)
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.frameStroke
    }

    // the bevel's own second level: a sunken groove just inside the raised
    // outer edge, using the ground and its surface as the light/dark pair
    // rather than adding a second colour to every look
    Bevel {
        visible: Theme.frameBevel
        anchors.fill: parent
        anchors.margins: Theme.frameInset
        raised: false
        light: Theme.surface
        dark: Theme.base
        thickness: Theme.borderWidth
    }
}
