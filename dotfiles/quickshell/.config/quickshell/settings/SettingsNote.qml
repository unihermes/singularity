// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsNote.qml
//
// One line of small print on a Settings page, under a heading or a field:
// what a section is for, or a problem (`alert`) that stops it working.
// Kept to one line, as the hints are.

import QtQuick
import "../services"

Text {
    property bool alert: false

    width: parent ? parent.width : 0
    elide: Text.ElideRight
    color: alert ? Theme.alert : Theme.subtext
    font.family: Theme.fontText
    font.weight: Theme.weightBody
    font.pixelSize: Theme.fontSmall
}
