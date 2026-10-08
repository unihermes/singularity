// Singularity - Quickshell
// ~/.config/quickshell/bar/BarModule.qml
//
// One clickable module in the bar: an icon, an optional readout next to it
// (volume/brightness percentages, battery level, the clock), and the click
// that opens its flyout. The chip itself is ModuleFrame.
//
// The frame is wrapped in a full-height Item rather than being the root, so
// the click area covers the bar's whole height, not just the chip.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    // highlights the module while its flyout is open
    property bool active: false
    // dims the icon when the thing it represents is off/absent
    property bool dimmed: false
    property bool acceptWheel: false
    property int padH: Theme.modulePadH
    property int iconSize: Theme.iconSize
    // -1 for a normal chip; 0..1 replaces the readout with a fill bar and
    // the exact number moves into the flyout
    property real fillValue: -1
    property color fillColor: Theme.gaugeFill
    property int fixedWidth: 0
    // the width the chip adds around its content: padding and brackets
    readonly property int chrome: frame.chrome
    // ...and around the label, which also has the icon and its gap beside it
    readonly property real labelChrome: chrome
        + (icon !== "" ? iconText.implicitWidth + frame.spacing : 0)
    // caps the label and elides it, for text of unbounded length (a track
    // title); 0 lets the label take whatever width it needs
    property int labelMaxWidth: 0
    // overrides the lightness-based colour, for the few modules whose whole
    // point is to be noticed (privacy, failed units)
    property color iconColor: "transparent"
    // a count in a bubble on the icon's top-right corner, drawn over the
    // chip so its width doesn't change; 0 hides it
    property int badge: 0

    readonly property int badgeInset: Theme.borderWidth + 1

    signal activated()

    // Slides to its new slot when Bar Widgets reorders the bar; the bar
    // switches this on once startup layout has settled (shell.qml)
    property bool slideX: false
    Behavior on x {
        enabled: root.slideX
        NumberAnimation { duration: Theme.dur(160); easing.type: Theme.ease }
    }
    signal middleClicked()
    signal rightClicked()
    signal wheeled(int delta)

    // Gauge icons are always bright: they sit on top of the fill, and the
    // fill sweeps under them, so anything dimmer loses contrast as it passes.
    readonly property color fg: active && fillValue < 0 && Theme.moduleOpenFill ? Theme.textOnAccent
        : (active || fillValue >= 0)
        ? Theme.textStrong
        : (dimmed ? Theme.textDisabled : Theme.text)


    implicitWidth: frame.implicitWidth
    implicitHeight: Theme.barHeight

    ModuleFrame {
        id: frame
        anchors.centerIn: parent
        active: root.active
        padH: root.padH
        fillValue: root.fillValue
        fillColor: root.fillColor
        fixedWidth: root.fixedWidth

        Text {
            id: iconText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor.a > 0 ? root.iconColor : root.fg
            font.family: Theme.fontIcon
            font.pixelSize: root.iconSize

            Rectangle {
                visible: root.badge > 0
                // over the icon's corner, but kept inside the chip's
                // outline, clear of its stroke
                x: Math.min(parent.width - width * 0.3, parent.width + root.chrome / 2 - width - root.badgeInset)
                y: Math.max(parent.height / 2 - frame.chipHeight / 2 + root.badgeInset,
                    parent.height / 2 - Theme.iconSize / 2 - height / 2 + 1)
                height: Math.round(Theme.barFs(9) * 1.3)
                width: Math.max(height, badgeText.implicitWidth + 4)
                radius: height / 2
                color: Theme.accent
                border.width: 1
                border.color: Theme.bar

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.badge > 99 ? "99+" : root.badge
                    color: Theme.textOnAccent
                    font.family: Theme.fontText
                    font.pixelSize: Theme.barFs(9)
                    font.weight: Font.Bold
                }
            }
        }

        Text {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            // Centring a Text centres its *line box*, which carries the
            // font's full ascent and descent -- so digits, which use neither,
            // sit visibly high. Measured at 1.5-2px here, and it scales with
            // the font size, so it's derived rather than hardcoded: shift
            // down by the gap between the line box's centre and the ink's.
            anchors.verticalCenterOffset: root.inkNudge(labelInk)
            visible: root.label !== ""
            text: root.label
            width: root.labelMaxWidth > 0 ? Math.min(implicitWidth, root.labelMaxWidth) : implicitWidth
            elide: Text.ElideRight
            color: root.fg
            font.family: Theme.fontText
            font.pixelSize: Theme.barLabelSize
            font.weight: Theme.weightBody
        }
    }

    // A fixed reference string, not the live text: per-glyph ink varies, and
    // following the label would make it bob every time the number changed.
    TextMetrics {
        id: labelInk
        font: labelText.font
        text: "0"
    }

    function inkNudge(m) {
        var line = (m.boundingRect.top + m.boundingRect.bottom) / 2
        var ink  = (m.tightBoundingRect.top + m.tightBoundingRect.bottom) / 2
        return line - ink
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.middleClicked()
            else if (mouse.button === Qt.RightButton) root.rightClicked()
            else root.activated()
        }
        // accumulate to one notch per step so a touchpad flick doesn't
        // jump the level, and sideways swipes (y = 0) do nothing
        property real wheelAccum: 0
        onWheel: wheel => {
            if (!root.acceptWheel) return
            wheelAccum += wheel.angleDelta.y
            while (Math.abs(wheelAccum) >= 120) {
                root.wheeled(wheelAccum > 0 ? 1 : -1)
                wheelAccum -= wheelAccum > 0 ? 120 : -120
            }
        }
    }
}
