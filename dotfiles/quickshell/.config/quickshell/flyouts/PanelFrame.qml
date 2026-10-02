// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PanelFrame.qml
//
// The panel ground every flyout and standalone window shares. How the frame
// itself is drawn is Theme.frameStyle:
//   double  the #141414 fill, an outer stroke, and a second stroke inset 3px
//           inside it -- Singularity's own look
//   single  the outer stroke alone
//   bevel   a raised chisel outside, a sunken one inside -- Windows 95
//   groove  the bevel inside out: sunken outside, raised inside, an etched line
//   accent  the outer stroke alone, in the accent colour
//   corners an L at each corner and nothing between them
//   none    no stroke -- the ground alone marks the edge
//   channel an outer line, a dark groove and an inner line (Channel.qml),
//           with rounder corners to clear them
// ModuleFrame is the bar chip's tighter version of the same look.

import QtQuick
import "../services"

Rectangle {
    id: root

    // no ground, stroke or shadow: the content straight on what's behind
    property bool bare: false
    // what the panel is filled with
    property color ground: Theme.panelFill
    readonly property bool channel: Theme.frameChannel && !bare

    radius: Theme.panelFrameRadius
    color: bare || channel ? "transparent" : ground
    // Theme.gradient: the same ground, shaded top to bottom
    gradient: Theme.gradient && !bare && !channel ? shading : null
    property Gradient shading: Gradient {
        GradientStop { position: 0; color: Theme.shadeTop(root.color) }
        GradientStop { position: 1; color: Theme.shadeBottom(root.color) }
    }
    border.width: Theme.frameStroked && !bare && !channel ? Theme.borderWidth : 0
    border.color: Theme.frameAccent ? Theme.accent : Theme.stroke

    // false for panels inside a window Hyprland already shadows
    property bool shadowed: true

    Shadow {
        radius: root.radius
        opaque: root.shadowed && !root.bare && Theme.panelOpacity >= 1
    }

    Channel {
        visible: root.channel
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        fill: root.ground
    }

    Bevel {
        visible: Theme.frameChiselled && !root.bare
        anchors.fill: parent
        raised: !Theme.frameGroove
        light: Theme.bevelLight
        dark: Theme.bevelDark
        thickness: Theme.borderWidth
    }

    Rectangle {
        anchors.fill: parent
        visible: Theme.frameDouble && !root.bare
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
        visible: Theme.frameChiselled && !root.bare
        anchors.fill: parent
        anchors.margins: Theme.frameInset
        raised: Theme.frameGroove
        light: Theme.surface
        dark: Theme.base
        thickness: Theme.borderWidth
    }

    FrameCorners {
        visible: Theme.frameCorners && !root.bare
        anchors.fill: parent
        color: Theme.strokeFocus
    }
}
