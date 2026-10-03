// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsSubhead.qml
//
// A small label splitting one section into groups (the touchpad's Clicking,
// then Scrolling and typing), quieter than a heading and with no rule, so
// the rows under it stay in the same channel.

import QtQuick
import "../services"

Text {
    width: parent ? parent.width : 0
    topPadding: Theme.spaceS
    elide: Text.ElideRight
    color: Theme.subtext
    font.family: Theme.fontText
    font.weight: Theme.weightBody
    font.pixelSize: Theme.fontCaption
    font.letterSpacing: Theme.headingSpacing
    text: Theme.heading(caption)

    property string caption: ""
}
