// Singularity - Quickshell
// ~/.config/quickshell/flyouts/GlassDot.qml
//
// Glass's round control button: a frosted disc with a glyph, the accent
// (and its glow) while lit. Used by the Control Centre's tiles and rows.

import QtQuick
import QtQuick.Effects
import "../services"

Rectangle {
    id: root

    property string icon: ""
    property bool lit: false
    property bool usable: true

    implicitWidth: Theme.fs(34)
    implicitHeight: implicitWidth
    radius: width / 2
    color: lit ? Theme.accent : Theme.isLight ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(1, 1, 1, 0.14)
    opacity: usable ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }

    RectangularShadow {
        visible: root.lit && Theme.glow
        anchors.fill: parent
        z: -1
        radius: root.radius
        blur: Theme.sp(12)
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.lit ? Theme.textOnAccent : Theme.text
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }
}
