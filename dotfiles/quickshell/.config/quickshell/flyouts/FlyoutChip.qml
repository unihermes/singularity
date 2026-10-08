// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChip.qml
//
// A small bordered button for inline actions inside a flyout row -- the
// Log / Restart / Clear on a failed unit, the media transport controls --
// where a full-width FlyoutRow per action would bury the list under them.
//
// Each style draws its own: a stroked chip (with Double's inner stroke or
// Bevel's raised edge), a filled block (Solid), a pill (Capsule), frosted
// glass, [ text ] (Terminal), an accent text link (Underline), a 2px ink
// box with a hard shadow (Ledger), or corner marks round spaced capitals
// (Corners).
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
    // a glyph before the text, turning while `spinning` (a scan running)
    property string icon: ""
    property bool spinning: false
    readonly property bool armed: disarm.running

    signal clicked()

    function disarmNow() { disarm.stop() }

    readonly property string kind: Theme.style
    readonly property bool hot: root.enabled && mouse.containsMouse
    // drawn as text alone: Terminal's brackets, Underline's link
    readonly property bool bare: (kind === "terminal" || kind === "underline") && !armed && !selected

    implicitWidth: content.implicitWidth + (bare ? Theme.spaceXs * 2 : Theme.spaceM * 2) + (glyph && !armed ? 2 : 0)
        + (kind === "corners" ? Theme.spaceS : 0)
    implicitHeight: Theme.chipHeight

    Rectangle {
        id: box
        readonly property color edge: root.armed ? Theme.alert
            : root.selected ? Theme.selectedStroke
            : root.hot ? Theme.strokeHover : Theme.stroke
        readonly property color frost: Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
        visible: !root.bare
        anchors.fill: parent
        radius: root.kind === "capsule" ? height / 2 : Theme.radiusInner
        color: root.armed ? Theme.alert
            : root.selected ? Theme.accent
            : root.kind === "solid" ? (root.hot ? Theme.overlay : Theme.surface)
            : root.kind === "capsule" ? (root.hot ? Theme.surface : Theme.overlay)
            : root.kind === "glass" ? (root.hot ? Theme.stroke : frost)
            : root.kind === "ledger" ? (root.hot ? Theme.text : Theme.panel)
            : root.kind === "corners" ? (root.hot ? Theme.overlay : "transparent")
            : Theme.controlFill(root.hot ? Theme.hoverFillSoft : "transparent")
        border.width: root.kind === "solid" || root.kind === "capsule" || root.kind === "corners" ? 0
            : root.kind === "glass" || root.kind === "ledger" ? Theme.borderWidth
            : Theme.controlBorder(edge)
        border.color: root.kind === "ledger" ? Theme.stroke
            : root.kind === "glass" ? Theme.stroke : Theme.controlStroke(edge)

        Shadow {
            visible: root.kind === "ledger"
            radius: 0
            offset: Theme.borderWidth
        }

        CornerMarks {
            visible: root.kind === "corners"
            color: root.selected || root.armed ? Theme.accent : root.hot ? Theme.textStrong : Theme.muted
        }

        // a lit chip is a pressed button
        ControlEdge {
            visible: ["channel", "double", "bevel", "tabbed", "underline", "terminal"].indexOf(root.kind) !== -1
            stroke: box.edge; sunken: root.selected; radius: box.radius
            lit: false
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spaceS

        Text {
            id: iconText
            visible: root.icon !== "" && !root.armed
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: label.color
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontBody
            font.weight: Theme.weightBody

            RotationAnimation on rotation {
                running: root.spinning
                loops: Animation.Infinite
                from: 0; to: 360
                duration: Theme.durPulse * 2
                onRunningChanged: if (!running) iconText.rotation = 0
            }
        }

        Text {
            visible: root.bare && root.kind === "terminal"
            anchors.verticalCenter: parent.verticalCenter
            text: "["
            color: root.hot ? Theme.accent : Theme.muted
            font: label.font
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.armed ? root.confirmText
                : root.kind === "corners" && !root.glyph ? root.text.toUpperCase() : root.text
            font.underline: root.bare && root.kind === "underline" && root.hot
            font.letterSpacing: root.kind === "corners" && !root.glyph ? 1 : 0
            color: !root.enabled ? Theme.textDisabled
                : root.armed ? Theme.base
                : root.selected ? Theme.textOnAccent
                : root.kind === "underline" ? Theme.accent
                : root.kind === "ledger" && root.hot ? Theme.panel
                : root.kind === "terminal" && root.hot ? Theme.accent
                : mouse.containsMouse ? Theme.textStrong : Theme.text

            font.family: root.glyph && !root.armed ? Theme.fontIcon : Theme.fontText
            font.pixelSize: root.glyph && !root.armed ? Theme.fontIconSize : Theme.fontBody
        }

        Text {
            visible: root.bare && root.kind === "terminal"
            anchors.verticalCenter: parent.verticalCenter
            text: "]"
            color: root.hot ? Theme.accent : Theme.muted
            font: label.font
        }
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
