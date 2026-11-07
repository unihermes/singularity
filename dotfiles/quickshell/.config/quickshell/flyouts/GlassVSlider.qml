// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassVSlider.qml
//
// Glass's tall level control: a capsule filled from the bottom with a glyph
// at its foot. Drag, click or scroll; `moved` carries the new 0-100 value.

import QtQuick
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property int value: 0
    property bool dimmed: false
    signal moved(int v)

    implicitWidth: Theme.fs(58)
    implicitHeight: Theme.fs(120)
    radius: width / 2
    color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.16)
    clip: true

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Math.max(width, parent.height * Math.max(0, Math.min(100, root.value)) / 100)
        radius: width / 2
        color: root.dimmed ? Theme.subtext : Theme.isLight ? "#2a2a2a" : "#f2f2f2"
        Behavior on height { enabled: !mouse.pressed; NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceM
        text: root.icon
        color: root.value > 12 ? (Theme.isLight ? "#f2f2f2" : "#222222") : Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function at(y) { root.moved(Math.round(Math.max(0, Math.min(1, 1 - y / height)) * 100)) }
        onPressed: m => at(m.y)
        onPositionChanged: m => { if (pressed) at(m.y) }
        onWheel: w => root.moved(Math.max(0, Math.min(100, root.value + (w.angleDelta.y > 0 ? 5 : -5))))
    }
}
