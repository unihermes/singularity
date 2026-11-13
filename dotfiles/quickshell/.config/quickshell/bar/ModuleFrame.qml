// The bar's chip, wrapped around whatever you put in it. Children are laid
// out in a centred Row. How it's drawn is Theme.moduleStyle:
//   outline  an outer stroke, plus an inset inner one when frames are
//            double
//   filled   a solid ground, no stroke
//   grouped  bare inside its section's channel (shell.qml): a fill on hover,
//            an accent ring while open, a gauge filling the whole chip
//   bare     the same with no channel round it (Settings.barChips)
//   taskbar  a bare slot the bar's height -- Flat: a fill on hover and
//            while open, an accent rule on the screen edge's side when open
//
// The one definition of the chip: BarModule and the open-window icons use it.

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

    // gauge mode: -1 a plain chip; 0..1 a fill on the right, content
    // left-aligned
    property real fillValue: -1
    readonly property bool gauge: fillValue >= 0
    property color fillColor: Theme.gaugeFill
    // when > 0 the chip is pinned to this width instead of hugging content
    property int fixedWidth: 0
    // the width the chip adds around its content
    readonly property int chrome: padH * 2
    // the drawn chip's height, which can be less than the item's
    readonly property real chipHeight: frame.height
    readonly property real levelStart: track.mapToItem(root, 0, 0).x
    readonly property real levelEnd: levelStart + glassFill.width

    default property alias content: contentRow.children

    // Slides to its new slot when Bar Widgets reorders the bar; the bar
    // switches this on once startup layout has settled (shell.qml)
    property bool slideX: false
    Behavior on x {
        enabled: root.slideX
        NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
    }

    implicitWidth: frame.width
    implicitHeight: Theme.barHeight

    // a hover fill on the whole chip; false when its items hover themselves
    property bool hoverWhole: true
    HoverHandler { id: hover; enabled: root.hoverWhole }
    readonly property bool hovered: hover.hovered && !active

    Rectangle {
        id: frame
        anchors.verticalCenter: parent.verticalCenter
        width: root.fixedWidth > 0
            ? root.fixedWidth
            : contentRow.implicitWidth + root.chrome
        readonly property string style: Theme.moduleStyle
        readonly property bool solid: style === "filled"
        readonly property bool grouped: style === "grouped"
        // no frame of its own: grouped, or bare
        readonly property bool flush: grouped || style === "bare"
        readonly property bool taskbar: style === "taskbar"
        // the gauge draws in the chip's interior
        readonly property bool track: root.gauge
        // filled with the accent while open (Solid, Glass);
        // a level chip keeps its fill and takes an accent ring instead
        readonly property bool openFill: Theme.moduleOpenFill && root.active && !root.gauge
        readonly property bool openRing: root.active && !Theme.washed && (flush || (Theme.moduleOpenFill && root.gauge))
        // what a bare chip's hover and open states fill with
        readonly property color wash: root.active ? Theme.washActive : hover.hovered ? Theme.washHover : "transparent"
        // a solid chip's own ground: Glass's is a faint frost, and Solid's
        // tint option mixes in the accent
        readonly property color restFill: Theme.glass ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06))
            : Theme.style === "solid" && Theme.opt("tint") ? Qt.tint(Theme.surface, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16))
            : Theme.surface

        height: grouped ? Theme.groupHeight - Theme.channelWidth * 2 : Theme.moduleHeight
        radius: Theme.radius
        readonly property color ground: flush ? (Theme.washed ? wash : root.active || hover.hovered ? Theme.overlay : "transparent")
            : openFill ? (Theme.glass ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : Theme.accent)
            : root.hovered ? (Theme.glass ? Theme.stroke : Theme.overlay)
            : root.active ? Theme.selectedFill
            : solid ? restFill : "transparent"

        color: Theme.frameCustom && !flush ? "transparent" : ground
        border.width: !Theme.frameCustom && style === "outline" && Theme.frameStroked ? Theme.borderWidth : 0
        border.color: root.active ? Theme.strokeFocus : Theme.stroke

        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

        Shadow {
            radius: frame.radius
            opaque: frame.solid || (Theme.frameStyle === "bevel" && !frame.flush)
        }

        StyleFrame {
            visible: Theme.frameCustom && !frame.flush
            ground: frame.ground
            stroke: root.active ? Theme.accent : Theme.stroke
            control: true
            sunken: root.active
        }

        // Glass's glow, round the open chip
        RectangularShadow {
            visible: Theme.glow && root.active && !frame.flush
            anchors.fill: parent
            z: -1
            radius: frame.radius
            blur: Theme.sp(12)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
        }

        // Keep the inner stroke above content fills, including end slots.
        Rectangle {
            anchors.fill: parent
            visible: Theme.frameDouble && frame.style === "outline"
            z: 1
            anchors.margins: 2
            radius: Theme.radiusInner
            color: "transparent"
            border.width: Theme.borderWidth
            // faint at rest unless Double's lit option is on
            border.color: root.active || Theme.opt("lit") ? Theme.frameStroke : Theme.surface
        }

        // flush inside the double border (3 is the first clear pixel)
        readonly property int barInset: flush || taskbar ? 0 : 3

        // The bar is the whole interior now, with the icon sitting on top of
        // it rather than beside it.
        Rectangle {
            id: track
            visible: frame.track
            anchors.fill: parent
            anchors.margins: frame.barInset
        // one less than the inner stroke's radius, concentric, floored at 0
            radius: Theme.glass ? Theme.pill(height) : frame.flush ? frame.radius : Theme.radiusSmall
            color: Theme.glass && frame.flush && !root.active && !hover.hovered ? frame.restFill
                : frame.flush || frame.taskbar ? (Theme.washed ? frame.wash : root.active || hover.hovered ? Theme.overlay : "transparent")
                : Theme.meterTrack
            border.width: Theme.glass ? 1 : 0
            border.color: Theme.stroke

            Rectangle {
                visible: !Theme.glass
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.fillValue <= 0
                    ? 0
                    : Math.max(radius * 2, parent.width * Math.min(1, root.fillValue))
                radius: parent.radius
                // softened on Flat's bare taskbar, where a full-strength
                // fill would outweigh everything round it
                color: frame.taskbar || Theme.washed ? Qt.alpha(root.fillColor, 0.45) : root.fillColor

                Behavior on width {
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease }
                }
                Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

            }

            // Clip a full-size rounded fill so its left edge always matches
            // the track, even when the level is narrower than the corner.
            GlassLevelFill {
                id: glassFill
                visible: Theme.glass
                fraction: root.fillValue
                corner: track.radius
                fillColor: Qt.alpha(root.fillColor, 1)
            }
        }

        // Flat's open slot: the outer edge lit, over any gauge fill
        Rectangle {
            visible: frame.taskbar && root.active
            y: Theme.barPosition === "bottom" ? parent.height - height : 0
            width: parent.width
            height: Math.max(2, Theme.borderWidth * 2)
            color: Theme.accent
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

        // after the track, so the icon reads over the fill; placed by x, as
        // swapping anchors pins the row's width
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            x: frame.track && !frame.flush && !frame.taskbar ? root.padH : Math.round((parent.width - width) / 2)
            spacing: root.spacing
        }
    }
}
