// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowPageTitle.qml
//
// An open page's icon (the accent, lightened) and name, large, over the page
// beside the sidebar.

import QtQuick
import "../services"

Row {
    id: root

    property string icon: ""
    property string label: ""

    x: Theme.spaceS
    spacing: Theme.spaceL
    height: Math.max(iconText.implicitHeight, nameText.implicitHeight) + Theme.spaceS

    Text {
        id: iconText
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: Theme.hasAccent ? Qt.lighter(Theme.accent, 1.4) : Theme.textStrong
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontTitle
    }

    Text {
        id: nameText
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.textStrong
        font.family: Theme.fontText
        font.pixelSize: Theme.fontTitle
        font.weight: Theme.weightStrong
    }
}
