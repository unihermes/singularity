// Singularity - Quickshell
// ~/.config/quickshell/flyouts/HeadCard.qml
//
// The card at the top of a System or Settings page: a glyph (or an app's
// icon, `image`), the answer
// large, a line or two of what's behind it, and the page's own actions at
// its end (the chips or a switch go in as children). `rule` draws a
// hairline under it, to keep it apart from the rows that follow.

import Quickshell.Widgets
import QtQuick
import "../services"

Item {
    id: root

    property string glyph: ""
    // an icon file in the glyph's place
    property string image: ""
    property color glyphColor: Theme.textStrong
    property string title: ""
    // quieter lines under the title; empty ones are left out
    property var lines: []
    property bool rule: false

    default property alias actions: chips.data
    // controls right after the title, on its line (Bluetooth's
    // Discoverable and Pairable)
    property alias besideTitle: titleExtras.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.fieldHeight, text.implicitHeight + Theme.spaceL * 2)

    Text {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fontTitle * 1.4
        horizontalAlignment: Text.AlignHCenter
        text: root.image === "" ? root.glyph : ""
        color: root.glyphColor
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontTitle

        IconImage {
            visible: root.image !== ""
            anchors.centerIn: parent
            implicitSize: Theme.fontTitle * 1.4
            source: root.image
        }
    }

    Column {
        id: text
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: chips.left
        anchors.rightMargin: chips.width > 0 ? Theme.spaceL : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Row {
            width: parent.width
            spacing: Theme.spaceL

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - (titleExtras.width > 0 ? titleExtras.width + parent.spacing : 0))
                elide: Text.ElideRight
                text: root.title
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontTitle
            }
            Row {
                id: titleExtras
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS
            }
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

    Rectangle {
        visible: root.rule
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.borderWidth
        color: Theme.stroke
    }
}
