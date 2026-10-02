// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsValue.qml
//
// A Settings row that only reports: the label and hint on the left, the
// value right-aligned where a control would sit, at the weight every
// readout in the shell uses.

import Quickshell
import QtQuick
import "../services"

SettingsField {
    id: root

    property string value: ""
    // a row with nothing to report steps aside rather than show a blank
    property bool hideEmpty: false
    // a value worth pasting elsewhere (an address): clicking it copies it,
    // and it reads Copied for a moment
    property bool copyable: false
    readonly property bool copied: copiedTimer.running

    visible: !hideEmpty || value !== ""

    // the hover fill, a little past the text so it doesn't touch it
    Rectangle {
        visible: root.copyable && copyMouse.containsMouse
        anchors.fill: valueText
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusSmall
        color: Theme.hoverFill
    }

    // no verticalCenter anchor: the control slot's height is its
    // childrenRect, so anchoring to it binds the row's height to itself
    Text {
        id: valueText
        anchors.right: parent.right
        text: root.copied ? "Copied" : root.value
        color: root.copied ? Theme.good : Theme.textStrong
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody

        MouseArea {
            id: copyMouse
            anchors.fill: parent
            anchors.margins: -Theme.spaceS
            enabled: root.copyable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["wl-copy", "--", root.value])
                copiedTimer.restart()
            }
        }
    }

    Timer { id: copiedTimer; interval: 1200 }
}
