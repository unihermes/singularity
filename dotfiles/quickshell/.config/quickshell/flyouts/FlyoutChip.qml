// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChip.qml
//
// A small button for inline actions in a row, drawn per style.
// `confirmText` makes it two clicks (armed for 3s, alert-red).

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

    implicitWidth: content.implicitWidth + Theme.spaceM * 2 + (glyph && !armed ? 2 : 0)
    implicitHeight: Theme.chipHeight

    Rectangle {
        id: box
        readonly property color edge: root.armed ? Theme.alert
            : root.selected ? Theme.selectedStroke
            : root.hot ? Theme.strokeHover : Theme.stroke
        readonly property color frost: Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.armed ? Theme.alert
            : root.selected ? Theme.accent
            : root.kind === "solid" ? (root.hot ? Theme.overlay : Theme.surface)
            : root.kind === "glass" ? (root.hot ? Theme.stroke : frost)
            : root.kind === "flat" ? Theme.overlay
            : Theme.controlFill(root.hot ? Theme.hoverFillSoft : "transparent")
        border.width: root.kind === "solid" ? 0
            : root.kind === "glass" ? Theme.borderWidth
            : root.kind === "flat" ? (root.hot && !root.armed && !root.selected ? Math.max(2, Theme.borderWidth * 2) : 0)
            : Theme.controlBorder(edge)
        border.color: root.kind === "glass" ? Theme.stroke
            : root.kind === "flat" ? Theme.subtext : Theme.controlStroke(edge)

        // a lit chip is a pressed button
        ControlEdge {
            visible: root.kind === "channel" || root.kind === "double"
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
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.armed ? root.confirmText : root.text
            color: !root.enabled ? Theme.textDisabled
                : root.armed ? Theme.base
                : root.selected ? Theme.textOnAccent
                : mouse.containsMouse ? Theme.textStrong : Theme.text

            font.family: root.glyph && !root.armed ? Theme.fontIcon : Theme.fontText
            font.pixelSize: root.glyph && !root.armed ? Theme.fontIconSize : Theme.fontBody
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
