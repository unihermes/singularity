// Singularity - Quickshell
// ~/.config/quickshell/bar/ModuleFrame.qml
//
// The bar's chip, wrapped around whatever you put in it. Children are laid
// out in a centred Row. How it's drawn is Theme.moduleStyle:
//   outline  an outer stroke, plus an inset inner one when frames are double,
//            a chiselled Bevel pair when they're bevel or groove, or only
//            the corners when they're corners
//   filled   a solid ground, no stroke
//   flat     nothing until active, then an accent underline
//   pill     filled, fully rounded
//   bracket  bare, between [ and ] in the text face -- a terminal status line
//   underline bare over a rule; a gauge fills the rule itself
//
// This exists so the chrome has one definition. BarModule draws an
// icon/label pair in it, and the open-window icons draw a whole row of
// icons in a single one -- the alternative was a second hand-maintained
// lookalike that would drift the first time the border changed.

import QtQuick
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
    HoverHandler { id: hover }
    readonly property bool hovered: hover.hovered && !active
    readonly property string hoverStyle: hovered ? Theme.hoverStyle : "none"

    Rectangle {
        id: frame
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.hoverStyle === "lift" ? -1 : 0
        width: root.fixedWidth > 0
            ? root.fixedWidth
            : contentRow.implicitWidth + root.chrome
        readonly property string style: Theme.moduleStyle
        readonly property bool solid: style === "filled" || style === "pill"
        readonly property bool brackets: style === "bracket"
        readonly property bool underline: style === "underline"
        readonly property int bracketW: brackets ? Math.ceil(bracketMetrics.advanceWidth) : 0
        // the gauge draws in the chip's interior, except under a rule
        // (the underline style's, or Theme.gaugeStyle "rule")
        readonly property bool track: root.gauge && !underline
        readonly property string gaugeStyle: underline ? "rule" : Theme.gaugeStyle
        readonly property real level: Math.max(0, Math.min(1, root.fillValue))

        readonly property bool bevel: Theme.frameChiselled && style === "outline"

        height: Theme.moduleHeight
        radius: style === "pill" ? height / 2 : Theme.radius
        color: root.hoverStyle === "fill" ? Theme.overlay
            : style === "flat" || brackets || underline ? "transparent"
            : root.active ? Theme.selectedFill
            : solid ? Theme.surface : "transparent"

        border.width: root.hoverStyle === "outline" || (style === "outline" && Theme.frameStroked) ? Theme.borderWidth : 0
        border.color: root.active || root.hoverStyle === "outline" ? Theme.strokeFocus
            : root.hoverStyle === "lift" ? Theme.strokeHover : Theme.stroke

        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Shadow {
            radius: frame.radius
            opaque: frame.solid
        }

        Bevel {
            visible: frame.bevel
            anchors.fill: parent
            raised: !Theme.frameGroove
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
            border.color: root.active ? Theme.frameStroke : Theme.surface
        }

        // the bevel's own second level: a sunken groove just inside the
        // raised outer edge
        Bevel {
            visible: frame.bevel
            anchors.fill: parent
            anchors.margins: 2
            raised: Theme.frameGroove
            light: Theme.surface
            dark: Theme.base
            thickness: Theme.borderWidth
        }

        FrameCorners {
            visible: Theme.frameCorners && frame.style === "outline"
            anchors.fill: parent
            length: Theme.sp(5)
            color: root.active ? Theme.strokeFocus : Theme.stroke
        }

        // the flat style's only mark: an underline under the active chip
        Rectangle {
            visible: frame.style === "flat" && root.active
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Theme.spaceL
            height: Theme.indicatorWidth
            radius: height / 2
            color: Theme.accent
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

        // the underline style's rule, which doubles as the gauge
        Rectangle {
            visible: frame.underline
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(2, Theme.borderWidth * 2)
            color: root.active ? Theme.accent : root.gauge ? Theme.meterTrack : Theme.stroke
            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Rectangle {
                visible: root.gauge
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, root.fillValue))
                color: root.fillColor
                Behavior on width { NumberAnimation { duration: Theme.dur(120); easing.type: Theme.ease } }
            }
        }

        // Flush inside the double border: the outer stroke sits at 0..1, the
        // inner one at 2..3, so 3 is the first clear pixel. Matching that
        // exactly is what makes the bar touch the border with no gap.
        readonly property int barInset: 3

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
            radius: frame.style === "pill" ? height / 2 : Theme.radiusSmall
            color: Theme.meterTrack


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

        // "segments": the same interior as five blocks, lit up to the level
        Row {
            visible: frame.track && frame.gaugeStyle === "segments"
            anchors.fill: parent
            anchors.margins: frame.barInset
            anchors.leftMargin: frame.barInset + frame.bracketW
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
                    // the first stays lit above zero so a low level still shows
                    color: frame.level > 0 && (index === 0 || frame.level >= (index + 0.5) / 5)
                        ? root.fillColor : Theme.meterTrack
                    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                }
            }
        }

        // "rule" for every module style but underline, which has its own:
        // a thin level along the chip's bottom, inside the frame
        Rectangle {
            visible: frame.track && frame.gaugeStyle === "rule"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: frame.barInset
            anchors.left: parent.left
            anchors.leftMargin: frame.barInset + frame.bracketW
            width: parent.width - (frame.barInset + frame.bracketW) * 2
            height: Math.max(2, Theme.borderWidth * 2)
            radius: height / 2
            color: Theme.meterTrack

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * frame.level
                color: root.fillColor
                Behavior on width { NumberAnimation { duration: Theme.dur(120); easing.type: Theme.ease } }
            }
        }

        // Drawn after the track, so the icon reads on top of the fill
        // wherever the fill has reached.
        // Placed by x rather than by swapping anchors.left for
        // anchors.horizontalCenter: for a moment in between both are set,
        // which pins the row to a width it keeps afterwards.
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            x: frame.track ? root.padH + frame.bracketW : Math.round((parent.width - width) / 2)
            spacing: root.spacing
        }
    }
}
