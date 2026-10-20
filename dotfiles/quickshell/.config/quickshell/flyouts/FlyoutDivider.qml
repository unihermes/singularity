// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutDivider.qml
//
// A plain rule between groups of rows (FlyoutHeading is the labelled one),
// bleeding past the column as FlyoutRow's hover does; in a sectioned
// column it splits the frames instead.

import QtQuick
import "../services"

Item {
    id: root

    // ends a collapsible section above it (FlyoutHeading)
    readonly property bool isSectionBreak: true
    // in a sectioned flyout's column, possibly through a Loader
    readonly property bool sectioned: {
        for (var p = parent; p; p = p.parent)
            if (p.sectioned !== undefined) return p.sectioned === true
        return false
    }

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
        // a sectioned flyout splits into separate frames instead
        visible: !root.sectioned

    }
}
