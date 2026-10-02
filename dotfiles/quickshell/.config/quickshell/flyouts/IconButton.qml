// Singularity - Quickshell
// ~/.config/quickshell/flyouts/IconButton.qml
//
// A bare glyph that's a button: no frame until it's pointed at, then the
// soft hover fill and stroke. For the small actions that sit inside a row
// or a header -- close, reveal, page back and forth, forget, kill -- where a
// FlyoutChip's standing border would be one frame too many.
//
// `confirm` makes it two clicks, for what can't be undone: the first arms
// it -- the glyph becomes an alert check -- and the second emits clicked().
// It disarms itself after 3s. A caller that keeps its own armed state (the
// process table's, shared with its hint line) sets `armed` instead.
//
// `lit` shows the glyph in the accent, for one that toggles a state (mute).

import QtQuick
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property bool enabled: true
    property bool confirm: false
    property bool armed: confirm && disarm.running
    property bool lit: false

    signal clicked()

    function disarmNow() { disarm.stop() }

    implicitWidth: Theme.controlSize
    implicitHeight: Theme.controlSize
    radius: Theme.radiusInner
    opacity: enabled ? 1 : 0.5
    color: armed ? Theme.alert : mouse.containsMouse ? Theme.hoverFillSoft : "transparent"
    readonly property color edge: armed ? Theme.alert : mouse.containsMouse ? Theme.strokeHover : "transparent"
    border.width: Theme.controlBorder(edge)
    border.color: Theme.controlStroke(edge)

    // only once it's under the pointer, like its stroke
    ControlEdge {
        visible: mouse.containsMouse || root.armed
        stroke: root.edge
        radius: root.radius
    }

    Text {
        anchors.centerIn: parent
        text: root.armed ? "󰄬" : root.icon
        color: root.armed ? Theme.base : root.lit ? Theme.accent
            : mouse.containsMouse ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    Timer { id: disarm; interval: 3000 }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirm && !disarm.running) { disarm.restart(); return }
            disarm.stop()
            root.clicked()
        }
    }
}
