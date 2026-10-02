// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsIndent.qml
//
// What a row opens under itself (a passphrase, a saved network's or a
// device's settings), set in by a rule down its left side.

import QtQuick
import "../services"

Item {
    default property alias content: indentCol.data
    width: parent ? parent.width : 0
    implicitHeight: visible ? indentCol.implicitHeight + Theme.spaceM * 2 : 0

    Rectangle {
        x: Theme.spaceS
        y: Theme.spaceS
        width: Theme.indicatorWidth
        height: parent.height - Theme.spaceS * 2
        color: Theme.stroke
    }

    Column {
        id: indentCol
        x: Theme.spaceS + Theme.indicatorWidth + Theme.spaceL
        y: Theme.spaceM
        width: parent.width - x
        spacing: Theme.spaceS
    }
}
