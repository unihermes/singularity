// Singularity - Quickshell
// ~/.config/quickshell/bar/ModuleFrame.qml
//
// The bar's chip, wrapped around whatever you put in it. Children are laid
// out in a centred Row. How it's drawn is Theme.moduleStyle:
//   outline  an outer stroke, plus an inset inner one when frames are
//            double, or a chiselled Bevel pair when they're bevel
//   filled   a solid ground, no stroke
//   ghost    bare until hovered or open
//   pill     filled, fully rounded
//   cornered marks at the corners only -- Corners
//   grouped  bare inside its section's channel (shell.qml): a fill on hover,
//            an accent ring while open, a gauge filling the whole chip
//
// This exists so the chrome has one definition. BarModule draws an
// icon/label pair in it, and the open-window icons draw a whole row of
// icons in a single one -- the alternative was a second hand-maintained
// lookalike that would drift the first time the border changed.

import QtQuick
import QtQuick.Effects
import "../services"
import "../flyouts"

Item {
    id: root

    // lit state: brighter strokes and a filled ground
    property bool active: false
    property int spacing: Theme.sp(5)
    // per-chip override, for the ones that look cramped at the shared value
    property int padH: Theme.modulePadH

    // Gauge mode. -1 leaves the chip as a plain icon/label chip; 0..1 turns
    // the right-hand side into a bar that fills with the value, and the
    // content is left-aligned beside it instead of centred.
    property real fillValue: -1
    readonly property bool gauge: fillValue >= 0
    property color fillColor: Theme.gaugeFill
    // when > 0 the chip is pinned to this width instead of hugging content
    property int fixedWidth: 0
    // the width the chip adds around its content
    readonly property int chrome: padH * 2
    // the drawn chip's height, which can be less than the item's
    readonly property real chipHeight: frame.height

    default property alias content: contentRow.children

    // Slides to its new slot when Bar Widgets reorders the bar; the bar
    // switches this on once startup layout has settled (shell.qml)
    property bool slideX: false
    Behavior on x {
        enabled: root.slideX
        NumberAnimation { duration: Theme.dur(160); easing.type: Theme.ease }
    }

    implicitWidth: frame.width
    implicitHeight: Theme.barHeight

    // Theme.hoverStyle, while the pointer is on the chip and it isn't lit
    // false for a chip whose items show their own hover (the open
    // windows): the chip itself then stays as it is under the pointer
    property bool hoverWhole: true
    HoverHandler { id: hover; enabled: root.hoverWhole }
    readonly property bool hovered: hover.hovered && !active
    readonly property string hoverStyle: hovered ? Theme.hoverStyle : "none"

    Rectangle {
        id: frame
        anchors.verticalCenter: parent.verticalCenter
        width: root.fixedWidth > 0
            ? root.fixedWidth
            : contentRow.implicitWidth + root.chrome
        readonly property string style: Theme.moduleStyle
        readonly property bool solid: style === "filled" || style === "pill"
        readonly property bool grouped: style === "grouped"
        readonly property bool cornered: style === "cornered"
        // the gauge draws in the chip's interior
        readonly property bool track: root.gauge
        // filled with the accent while open (Solid, Capsule, Glass);
        // a level chip keeps its fill and takes an accent ring instead
        readonly property bool openFill: Theme.moduleOpenFill && root.active && !root.gauge
        readonly property bool openRing: root.active && (grouped || (Theme.moduleOpenFill && root.gauge))
        // a solid chip's own ground: Glass's is a faint frost, and Solid's
        // tint option mixes in the accent
        readonly property color restFill: Theme.glass ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06))
            : Theme.style === "solid" && Theme.opt("tint") ? Qt.tint(Theme.surface, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16))
            : Theme.surface

        readonly property bool bevel: Theme.frameChiselled && style === "outline"

        height: grouped ? Theme.groupHeight - Theme.channelWidth * 2 : Theme.moduleHeight
        radius: style === "pill" ? height / 2 : Theme.radius
        color: grouped ? (root.active || hover.hovered ? Theme.overlay : "transparent")
            : openFill ? (Theme.glass ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : Theme.accent)
            : root.hoverStyle === "fill" ? (Theme.glass ? Theme.stroke : Theme.overlay)
            : cornered && root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
            : cornered ? "transparent"
            // open under a tab-style flyout: the flyout's own ground, so
            // the chip reads as the tab it hangs from
            : root.active ? (Theme.flyoutAttach === "tab" ? Theme.panelFill : Theme.selectedFill)
            : solid ? restFill : "transparent"

        border.width: !grouped && (root.hoverStyle === "outline" || (style === "outline" && Theme.frameStroked)) ? Theme.borderWidth : 0
        border.color: root.active || root.hoverStyle === "outline" ? Theme.strokeFocus : Theme.stroke

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Shadow {
            radius: frame.radius
            opaque: frame.solid
            offset: Theme.shadowOffset
        }

        // Glass and Corners' glow, round the open chip
        RectangularShadow {
            visible: Theme.glow && root.active
            anchors.fill: parent
            z: -1
            radius: frame.radius
            blur: Theme.sp(12)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
        }

        CornerMarks {
            visible: frame.cornered
            color: root.active ? Theme.accent : hover.hovered ? Theme.textStrong : Theme.muted
        }

        Bevel {
            visible: frame.bevel
            anchors.fill: parent
            raised: true
            light: Theme.bevelLight
            dark: Theme.bevelDark
            thickness: Theme.borderWidth
        }

        // inner stroke, inset -- the second half of the double border
        Rectangle {
            anchors.fill: parent
            visible: Theme.frameDouble && frame.style === "outline"
            anchors.margins: 2
            radius: Theme.radiusInner
            color: "transparent"
            border.width: Theme.borderWidth
            // faint at rest unless Double's lit option is on
            border.color: root.active || Theme.opt("lit") ? Theme.frameStroke : Theme.surface
        }

        // the bevel's own second level: a sunken groove just inside the
        // raised outer edge
        Bevel {
            visible: frame.bevel
            anchors.fill: parent
            anchors.margins: 2
            raised: false
            light: Theme.surface
            dark: Theme.base
            thickness: Theme.borderWidth
        }

        // Tabbed's accent edge option: the open tab's outer edge lit
        Rectangle {
            visible: Theme.style === "tabbed" && Theme.opt("lift") && root.active
            y: Theme.barPosition === "bottom" ? parent.height - height : 0
            width: parent.width
            height: Math.max(2, Theme.borderWidth * 2)
            color: Theme.accent
        }

        // Flush inside the double border: the outer stroke sits at 0..1, the
        // inner one at 2..3, so 3 is the first clear pixel. Matching that
        // exactly is what makes the bar touch the border with no gap.
        readonly property int barInset: grouped ? 0 : 3

        // The bar is the whole interior now, with the icon sitting on top of
        // it rather than beside it.
        Rectangle {
            id: track
            visible: frame.track
            anchors.fill: parent
            anchors.margins: frame.barInset
            // one less than the inner stroke's radius, being one pixel
            // further in, so the curves stay concentric -- floored because
            // the radius is user-settable down to square
            radius: frame.style === "pill" ? height / 2 : frame.grouped ? frame.radius : Theme.radiusSmall
            color: frame.grouped ? (root.active || hover.hovered ? Theme.overlay : "transparent")
                : frame.cornered ? "transparent" : Theme.meterTrack


            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // clamped to its own diameter so a nearly-empty bar is still
                // a rounded stub rather than a sliver with clipped corners
                width: root.fillValue <= 0
                    ? 0
                    : Math.max(radius * 2, parent.width * Math.min(1, root.fillValue))
                radius: parent.radius
                color: root.fillColor

                Behavior on width {
                    NumberAnimation { duration: Theme.dur(120); easing.type: Theme.ease }
                }
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

            }
        }

        // the open module's accent ring, over any gauge fill: grouped
        // chips, and the level chips of the styles that fill open chips
        Rectangle {
            visible: frame.openRing
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.width: Theme.borderWidth * 2
            border.color: Theme.accent
        }

        // Drawn after the track, so the icon reads on top of the fill
        // wherever the fill has reached.
        // Placed by x rather than by swapping anchors.left for
        // anchors.horizontalCenter: for a moment in between both are set,
        // which pins the row to a width it keeps afterwards.
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            x: frame.track && !frame.grouped ? root.padH : Math.round((parent.width - width) / 2)
            spacing: root.spacing
        }
    }
}
