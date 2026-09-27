// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsValue.qml
//
// A Settings row that only reports: the label and hint on the left, the
// value right-aligned where a control would sit, at the weight every
// readout in the shell uses.

import QtQuick
import "../services"

SettingsField {
    id: root

    property string value: ""
    // a row with nothing to report steps aside rather than show a blank
    property bool hideEmpty: false

    visible: !hideEmpty || value !== ""

    // no verticalCenter anchor: the control slot's height is its
    // childrenRect, so anchoring to it binds the row's height to itself
    Text {
        anchors.right: parent.right
        text: root.value
        color: Theme.textStrong
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }
}
