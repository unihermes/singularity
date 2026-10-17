// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsSectionRow.qml
//
// One of Settings' search hits: the setting's name over the page and
// heading it lives on (`blurb`), with that page's icon.
//
// `current` is where the arrow keys are while the search field has focus
// (a fill, a tick and a grey chevron). A hovered row shows the fill and
// the grey chevron too, as a way in.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string blurb: ""
    property bool current: false

    signal clicked()
    signal hovered()

    width: parent ? parent.width : 0
    // just clear of the two lines of text, so a long list fits unscrolled
    implicitHeight: Math.max(Theme.fieldHeight, texts.implicitHeight + Theme.spaceS)

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusInner
            color: root.current || mouse.containsMouse ? Theme.hoverFill : "transparent"
        }

        // the arrow keys' row: a tick on the left edge, as a selected row
        Rectangle {
            visible: root.current
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.indicatorWidth
            height: parent.height - 6
            radius: Theme.pill(width)
            color: Theme.accent
        }

        Item {
            id: iconCell
            x: Theme.spaceL
            width: Theme.iconCell
            height: parent.height

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.current || mouse.containsMouse ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
        }

        Column {
            id: texts
            anchors.left: iconCell.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: chevron.left
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.label
                elide: Text.ElideRight
                color: root.current || mouse.containsMouse ? Theme.textStrong : Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.blurb
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅂"
            visible: root.current || mouse.containsMouse
            color: Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSmall
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered()
            onClicked: root.clicked()
        }
    }
}
