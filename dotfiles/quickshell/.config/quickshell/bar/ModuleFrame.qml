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
//   bracket  bare, between [ and ] in the text face -- a terminal status line
//   underline bare; a short accent line under (or over) the open one
//   boxed    a 2px ink box with a hard offset shadow -- Ledger
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
    readonly property int chrome: padH * 2 + frame.bracketW * 2
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
        readonly property bool brackets: style === "bracket" && !Theme.opt("pipes")
        readonly property bool underline: style === "underline"
        readonly property bool grouped: style === "grouped"
        readonly property bool boxed: style === "boxed"
        readonly property bool cornered: style === "cornered"
        readonly property int bracketW: brackets ? Math.ceil(bracketMetrics.advanceWidth) : 0
        // the gauge draws in the chip's interior
        readonly property bool track: root.gauge
        readonly property string gaugeStyle: Theme.gaugeStyle
        // filled with the accent while open (Solid, Capsule, Glass, Ledger);
        // a level chip keeps its fill and takes an accent ring instead
        readonly property bool openFill: Theme.moduleOpenFill && root.active && !root.gauge
        readonly property bool openRing: root.active && (grouped || (Theme.moduleOpenFill && root.gauge))
        // a solid chip's own ground: Glass's is a faint frost, and Solid's
        // tint option mixes in the accent
        readonly property color restFill: Theme.glass ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06))
            : Theme.style === "solid" && Theme.opt("tint") ? Qt.tint(Theme.surface, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16))
            : Theme.surface
        readonly property real level: Math.max(0, Math.min(1, root.fillValue))

        readonly property bool bevel: Theme.frameChiselled && style === "outline"

        height: grouped ? Theme.groupHeight - Theme.channelWidth * 2
            : boxed ? Theme.moduleHeight - 2 : Theme.moduleHeight
        radius: style === "pill" ? height / 2 : Theme.radius
        color: grouped ? (root.active || hover.hovered ? Theme.overlay : "transparent")
            : openFill ? (Theme.glass ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : Theme.accent)
            : root.hoverStyle === "fill" ? (Theme.glass ? Theme.stroke : Theme.overlay)
            : cornered && root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
            // Ledger's box is solid, so its offset shadow stays behind it
            : boxed ? Theme.bar
            : brackets || underline || cornered || style === "bracket" ? "transparent"
            // open under a tab-style flyout: the flyout's own ground, so
            // the chip reads as the tab it hangs from
            : root.active ? (Theme.flyoutAttach === "tab" ? Theme.panelFill : Theme.selectedFill)
            : solid ? restFill : "transparent"

        border.width: !grouped && (boxed || root.hoverStyle === "outline" || (style === "outline" && Theme.frameStroked)) ? Theme.borderWidth : 0
        border.color: boxed ? Theme.stroke
            : root.active || root.hoverStyle === "outline" ? Theme.strokeFocus : Theme.stroke

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Shadow {
            radius: frame.radius
            opaque: frame.solid || frame.boxed
            offset: frame.boxed ? Theme.borderWidth : Theme.shadowOffset
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

        TextMetrics {
            id: bracketMetrics
            font: leftBracket.font
            text: "["
        }

        Text {
            id: leftBracket
            visible: frame.brackets
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "["
            color: root.active ? Theme.accent : Theme.muted
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.barLabelSize
        }

        Text {
            visible: frame.brackets
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "]"
            color: leftBracket.color
            font: leftBracket.font
        }

        // Underline's mark on the open module: a short accent line under it,
        // or over it with the style's lines-above option
        Rectangle {
            visible: frame.underline && root.active
            x: Theme.spaceM
            y: Theme.opt("over") ? 0 : parent.height - height
            width: parent.width - Theme.spaceM * 2
            height: Math.max(2, Theme.borderWidth * 2)
            radius: height / 2
            color: Theme.accent
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
        readonly property int barInset: grouped ? 0 : boxed ? Theme.borderWidth + 1 : 3

        // The bar is the whole interior now, with the icon sitting on top of
        // it rather than beside it.
        Rectangle {
            id: track
            visible: frame.track && frame.gaugeStyle === "fill"
            anchors.fill: parent
            anchors.margins: frame.barInset
            anchors.leftMargin: frame.barInset + frame.bracketW
            anchors.rightMargin: frame.barInset + frame.bracketW
            // one less than the inner stroke's radius, being one pixel
            // further in, so the curves stay concentric -- floored because
            // the radius is user-settable down to square
            radius: frame.style === "pill" ? height / 2 : frame.grouped ? frame.radius : Theme.radiusSmall
            color: frame.grouped ? (root.active || hover.hovered ? Theme.overlay : "transparent")
                : frame.underline || frame.cornered ? "transparent" : Theme.meterTrack


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
                // Underline's level is a soft wash of the colour, not a block
                color: frame.underline ? Qt.alpha(root.fillColor, 0.38) : root.fillColor

                Behavior on width {
                    NumberAnimation { duration: Theme.dur(120); easing.type: Theme.ease }
                }
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

            }
        }

        // "segments": five blocks beside the icon, lit up to the level, as
        // a terminal meter would draw them
        Row {
            visible: frame.track && frame.gaugeStyle === "segments"
            anchors.fill: parent
            anchors.margins: frame.barInset + 1
            anchors.leftMargin: root.padH + frame.bracketW + contentRow.width + root.spacing
            anchors.rightMargin: frame.barInset + frame.bracketW
            spacing: Math.max(1, Theme.borderWidth)

            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    width: (parent.width - parent.spacing * 4) / 5
                    height: parent.height
                    radius: Math.min(Theme.radiusSmall, 2)
                    // a block is lit once the level passes its midpoint, and
                    // the first stays lit above zero so a low level still shows;
                    // unlit ones in the stroke colour, so all five read
                    color: frame.level > 0 && (index === 0 || frame.level >= (index + 0.5) / 5)
                        ? root.fillColor : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                }
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
            x: frame.track && !frame.grouped ? root.padH + frame.bracketW : Math.round((parent.width - width) / 2)
            spacing: root.spacing
        }
    }
}
