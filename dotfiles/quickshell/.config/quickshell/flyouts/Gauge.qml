// Singularity - Quickshell
// ~/.config/quickshell/Gauge.qml
//
// label | bar | value, on one line. Used by the System window.

import QtQuick
import "../services"

Item {
    id: g
    property string label: ""
    property real fraction: 0
    property string value: ""
    // lights the fill with the one alert hue in the palette
    property bool critical: false
    property bool available: true

    width: parent ? parent.width : 0
    height: 22

    Text {
        id: gLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        text: g.label
        color: Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Rectangle {
        anchors.left: gLabel.right
        anchors.right: gValue.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: height / 2
        color: Theme.base
        border.width: 1
        border.color: Theme.surface

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // clamped to its own diameter, so a near-zero reading is a
            // rounded stub rather than a sliver with clipped corners
            width: !g.available || g.fraction <= 0 ? 0
                : Math.max(height, parent.width * Math.min(1, g.fraction))
            radius: parent.radius
            color: g.critical ? Theme.alert : Theme.text

            Behavior on width { NumberAnimation { duration: Theme.dur(250); easing.type: Easing.OutCubic } }
        }
    }

    Text {
        id: gValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // wide enough for "210G / 476G" so every bar is the same length
        width: 90
        horizontalAlignment: Text.AlignRight
        text: g.value
        color: g.available ? Theme.bright : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }
}
