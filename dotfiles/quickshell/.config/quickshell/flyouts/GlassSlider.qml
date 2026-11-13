// Glass's level control: a thick capsule filled from the left with a glyph
// inside. Drag, click or scroll; `moved` carries the new 0-100 value.

import QtQuick
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property int value: 0
    property bool dimmed: false
    signal moved(int v)

    implicitHeight: Theme.fs(30)
    radius: height / 2
    color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.16)
    border.width: 1
    border.color: Theme.stroke
    clip: true

    GlassLevelFill {
        fraction: root.value / 100
        corner: root.radius
        fillColor: root.dimmed ? Theme.subtext : Theme.isLight ? "#2a2a2a" : "#f2f2f2"
        animated: !mouse.pressed
    }

    Text {
        x: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.value > 6 ? (Theme.isLight ? "#f2f2f2" : "#222222") : Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function at(x) { root.moved(Math.round(Math.max(0, Math.min(1, x / width)) * 100)) }
        onPressed: m => at(m.x)
        onPositionChanged: m => { if (pressed) at(m.x) }
        onWheel: w => root.moved(Math.max(0, Math.min(100, root.value + (w.angleDelta.y > 0 ? 5 : -5))))
    }
}
