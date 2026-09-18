// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutDivider.qml
//
// A plain rule between groups of rows, for menus that split into sections
// without wanting a label on each one. FlyoutHeading is the labelled
// version of the same idea.
//
// The negative margins match FlyoutRow's: rows bleed 4px past the content
// column on both sides so their hover highlight reaches the panel's inner
// padding, and a divider that stopped short of that would look inset.

import QtQuick
import "../services"

Item {
    id: root

    width: parent ? parent.width : 0
    implicitHeight: Theme.spaceL + 1

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.borderWidth
        color: Theme.stroke

    }
}
