// Singularity - Quickshell
// ~/.config/quickshell/windows/system/HeadCard.qml
//
// The card at the top of a System page, as Settings' Network and Software
// Update pages have: a glyph, the answer large, a line or two of what's
// behind it, and the page's own actions at its end (the chips go in as
// children).

import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string glyph: ""
    property color glyphColor: Theme.textStrong
    property string title: ""
    // quieter lines under the title; empty ones are left out
    property var lines: []

    default property alias actions: chips.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.fieldHeight, text.implicitHeight + Theme.spaceL * 2)

    Text {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fontTitle * 1.4
        horizontalAlignment: Text.AlignHCenter
        text: root.glyph
        color: root.glyphColor
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontTitle
    }

    Column {
        id: text
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: chips.left
        anchors.rightMargin: chips.width > 0 ? Theme.spaceL : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontTitle
        }
        Repeater {
            model: root.lines.filter(l => l !== "")
            Text {
                required property string modelData
                width: parent.width
                elide: Text.ElideRight
                text: modelData
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    Row {
        id: chips
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS
    }
}
