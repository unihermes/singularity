// Singularity - Quickshell
// ~/.config/quickshell/flyouts/IconButton.qml
//
// A bare glyph button, framed only on hover, for small actions in rows and
// headers. `confirm` makes it two clicks (armed for 3s; or the caller sets
// `armed`); `lit` shows it in the accent, `warn` in the alert colour (a
// mute that's on); `spinning` turns it.

import QtQuick
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property bool enabled: true
    property bool confirm: false
    property bool armed: confirm && disarm.running
    property bool lit: false
    property bool warn: false
    property bool spinning: false
    property real glyphSize: Theme.fontIconSize

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
        id: glyph
        anchors.centerIn: parent
        text: root.armed ? "󰄬" : root.icon
        color: root.armed ? Theme.base : root.warn ? Theme.alert : root.lit ? Theme.accent
            : mouse.containsMouse ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: root.glyphSize
    }

    RotationAnimation {
        target: glyph
        running: root.spinning
        loops: Animation.Infinite
        from: 0; to: 360
        duration: Theme.durPulse * 2
        onRunningChanged: if (!running) glyph.rotation = 0
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
