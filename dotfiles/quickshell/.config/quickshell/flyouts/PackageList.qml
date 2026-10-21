// Singularity - Quickshell
// ~/.config/quickshell/flyouts/PackageList.qml
//
// Pending package updates, a dense line each: the name, and the version
// it goes to. Scrolls past eight.

import QtQuick
import "../services"

ListView {
    id: list
    property var packages: []
    visible: packages.length > 0
    width: parent ? parent.width : 0
    height: Math.min(contentHeight, 8 * Theme.rowHeightDense)
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    model: packages

    delegate: Item {
        required property var modelData
        width: list.width
        height: Theme.rowHeightDense

        Text {
            anchors.left: parent.left
            anchors.right: ver.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.name
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
        Text {
            id: ver
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Theme.fs(150))
            horizontalAlignment: Text.AlignRight
            text: modelData.to
            elide: Text.ElideLeft
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }
}
