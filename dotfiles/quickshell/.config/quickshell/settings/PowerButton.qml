// Singularity - Quickshell
// ~/.config/quickshell/settings/PowerButton.qml
//
// A round on/off button for a connection's radio or tunnel: an accent
// disc with a ring round it while on, a dark well while off. `busy` dims
// it while the change is under way.

import QtQuick
import "../services"

Item {
    id: root

    property bool on: false
    property bool enabled: true
    property bool busy: false
    property real size: Theme.fit(48)
    property string glyph: "󰐥"

    signal clicked()

    readonly property bool hot: enabled && mouse.containsMouse

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? (busy ? 0.6 : 1) : 0.45

    // the ring, a gap out from the disc while on
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: root.on ? Theme.accent : "transparent"
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.on ? Math.max(2, root.size * 0.08) : 0
        radius: width / 2
        color: root.on ? Theme.accent : root.hot ? Theme.overlay : Theme.surface
        border.width: root.on ? 0 : Theme.borderWidth
        border.color: edge
        readonly property color edge: root.hot ? Theme.strokeHover : Theme.stroke

        Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.on ? Theme.textOnAccent : root.hot ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Math.round(root.size * 0.42)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled && !root.busy
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
