// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Switch.qml
//
// The one on/off control: Quick Actions' toggles and every boolean on the
// Settings pages. A choice between two values that reads as a state (on,
// off) is this; a choice between named options is a FlyoutSegmented.
//
// `interactive: false` for a switch inside a row that takes the click
// itself (FlyoutAction), so the whole row is the target.

import QtQuick
import "../services"

Rectangle {
    id: root

    property bool checked: false
    property bool enabled: true
    property bool interactive: true
    signal toggled()

    implicitWidth: Theme.switchWidth
    implicitHeight: Theme.switchHeight
    radius: Math.min(height / 2, Theme.radius)
    opacity: enabled ? 1 : 0.5
    color: checked ? Theme.meterFill : Theme.fieldFill
    readonly property color edge: checked ? Theme.meterFill
        : (mouse.containsMouse ? Theme.strokeHover : Theme.stroke)
    border.width: Theme.controlBorder(edge)
    border.color: Theme.controlStroke(edge)
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    readonly property int knobInset: Math.max(2, Math.round(height / 5))

    // the track is a well; not under double, where an inner stroke would
    // crowd the knob
    ControlEdge {
        visible: !Theme.frameDouble
        stroke: root.edge
        sunken: true
        radius: root.radius
    }

    Rectangle {
        width: parent.height - root.knobInset * 2
        height: width
        radius: Math.min(width / 2, Theme.radiusSmall)
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - root.knobInset : root.knobInset
        color: root.checked ? Theme.base : Theme.muted
        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        visible: root.interactive
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
