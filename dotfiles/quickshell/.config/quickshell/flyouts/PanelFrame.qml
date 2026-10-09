// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PanelFrame.qml
//
// The panel ground every flyout and standalone window shares. How the frame
// itself is drawn is Theme.frameStyle:
//   double  the #141414 fill, an outer stroke, and a second stroke inset 3px
//           inside it -- Singularity's own look
//   single  the outer stroke alone
//   bevel   a raised chisel outside, a sunken one inside -- Windows 95
//   none    no stroke -- the ground alone marks the edge
//   channel an outer line, a dark groove and an inner line (Channel.qml),
//           with rounder corners to clear them
//   corners accent marks at the corners over a faint hairline, glowing
//           with the style's glow option
// ModuleFrame is the bar chip's tighter version of the same look.

import QtQuick
import QtQuick.Effects
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
    border.width: (Theme.frameStroked || Theme.frameCorners) && !bare && !channel ? Theme.borderWidth : 0
    border.color: Theme.frameCorners ? Theme.cornerHairline : Theme.stroke

    // false for panels inside a window Hyprland already shadows
    property bool shadowed: true

    Shadow {
        radius: root.radius
        opaque: root.shadowed && !root.bare && Theme.panelOpacity >= 1
    }

    // Corners' glow: the accent bleeding out round the panel
    RectangularShadow {
        visible: Theme.frameCorners && Theme.glow && !root.bare
        anchors.fill: parent
        z: -1
        blur: Theme.sp(22)
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
    }

    CornerMarks {
        visible: Theme.frameCorners && !root.bare
        length: Theme.cornerLarge
        thickness: Theme.opt("big") ? 2 : 1
        color: Theme.accent
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
        raised: true
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
        raised: false
        light: Theme.surface
        dark: Theme.base
        thickness: Theme.borderWidth
    }
}
