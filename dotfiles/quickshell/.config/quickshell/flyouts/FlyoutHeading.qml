// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutHeading.qml
//
// Section label for a flyout: small caps, then a rule that runs out to the
// right edge -- the same "label cut into a border" motif the rest of the
// repo uses (see the fastfetch box headers).

import QtQuick
import "../services"

Item {
    id: root

    property string text: ""

    width: parent ? parent.width : 0
    implicitHeight: Theme.headingHeight

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.heading(root.text)
        color: Theme.headingColor
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
        font.bold: Theme.headingBold
        font.letterSpacing: Theme.headingSpacing
    }

    Rectangle {
        visible: Theme.headingRule
        anchors.left: label.right

        anchors.leftMargin: Theme.spaceL
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.borderWidth
        color: Theme.stroke

    }
}
