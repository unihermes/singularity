// Singularity - Quickshell
// ~/.config/quickshell/flyouts/Gauge.qml
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
    height: Theme.row(22)

    Text {
        id: gLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // wide enough for the longest label a gauge is given ("Health"),
        // so the bars all start at the same x whatever the page
        width: Theme.fs(58)
        text: g.label
        color: Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Meter {
        anchors.left: gLabel.right
        anchors.right: gValue.left
        anchors.rightMargin: Theme.spaceXl
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.meterHeight + 2
        fraction: g.available ? g.fraction : 0
        fillColor: g.critical ? Theme.alert : Theme.meterFill
    }

    Text {
        id: gValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // wide enough for "210G / 476G" so every bar is the same length
        width: Theme.fs(90)
        horizontalAlignment: Text.AlignRight
        text: g.value
        color: g.available ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }
}
