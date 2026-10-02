// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutChip.qml
//
// A small bordered button for inline actions inside a flyout row -- the
// Log / Restart / Clear on a failed unit, the media transport controls --
// where a full-width FlyoutRow per action would bury the list under them.
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

    implicitWidth: content.implicitWidth + Theme.spaceM * 2 + (glyph && !armed ? 2 : 0)
    implicitHeight: Theme.chipHeight

    Rectangle {
        id: box
        readonly property color edge: root.armed ? Theme.alert
            : root.selected ? Theme.selectedStroke
            : (root.enabled && mouse.containsMouse) ? Theme.strokeHover : Theme.stroke
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.controlFill(root.armed ? Theme.alert
            : root.selected ? Theme.accent
            : (root.enabled && mouse.containsMouse) ? Theme.hoverFillSoft : "transparent")
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        // a lit chip is a pressed button
        ControlEdge {
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
                : (root.selected || mouse.containsMouse) ? Theme.textStrong : Theme.text

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
