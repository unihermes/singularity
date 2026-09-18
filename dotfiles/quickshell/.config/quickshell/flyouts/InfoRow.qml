// Singularity - Quickshell
// ~/.config/quickshell/InfoRow.qml
//
// A label on the left and its value on the right, elided to fit. Used by
// the System window.

import QtQuick
import "../services"

Item {
    id: info
    property string label: ""
    property string value: ""
    // overrides the value text's default color, for a line that needs
    // to stand out (e.g. a non-empty failed-units list)
    property var valueColor: undefined

    width: parent ? parent.width : 0
    height: 20

    Text {
        id: infoLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: info.label
        color: Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Text {
        anchors.left: infoLabel.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: info.value
        color: info.valueColor !== undefined ? info.valueColor : Theme.bright
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }
}
