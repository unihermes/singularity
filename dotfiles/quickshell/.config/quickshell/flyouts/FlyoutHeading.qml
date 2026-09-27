// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutHeading.qml
//
// Section label for a flyout: small caps, then a rule that runs out to the
// right edge -- the same "label cut into a border" motif the rest of the
// repo uses (see the fastfetch box headers).
//
// `hints` puts key hints at the rule's far end ("Enter open", "Esc close"),
// for the centred overlays that are driven from the keyboard.

import QtQuick
import "../services"

Item {
    id: root

    property string text: ""
    property var hints: []

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
        anchors.right: hintRow.left
        anchors.rightMargin: root.hints.length > 0 ? Theme.spaceL : 0
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.borderWidth
        color: Theme.stroke
    }

    Row {
        id: hintRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXl

        Repeater {
            model: root.hints

            Text {
                required property string modelData
                text: modelData.toUpperCase()
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontEyebrow
                font.letterSpacing: 1
            }
        }
    }
}
