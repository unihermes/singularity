// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsSectionRow.qml
//
// One row in the Settings window's Sections panel: a two-digit number, the
// section's icon, a name, and a line under it saying what's there. The same
// row carries a search hit -- the setting's name over the page and heading
// it lives on, with that page's icon -- so the list looks the same whether
// it's the sections or what matched.
//
// Two ways to be lit: `selected` is the page on show (a stroke and a
// chevron), `current` is where the arrow keys are while the search field
// has focus (a fill). They differ because both can be true of different
// rows at once.

import QtQuick
import "../services"

Item {
    id: root

    property string number: ""
    property string icon: ""
    property string label: ""
    property string blurb: ""
    property bool selected: false
    property bool current: false

    signal clicked()
    signal hovered()

    width: parent ? parent.width : 0
    implicitHeight: Theme.fieldHeight + Theme.spaceL

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: root.selected || root.current ? Theme.selectedFill
            : mouse.containsMouse ? Theme.hoverFillSoft : "transparent"
        border.width: Theme.borderWidth
        border.color: root.selected ? Theme.selectedStroke
            : root.current ? Theme.strokeHover : "transparent"
    }

    Text {
        id: num
        x: Theme.spaceL
        width: Theme.fs(20)
        anchors.verticalCenter: parent.verticalCenter
        text: root.number
        color: root.selected ? Theme.accent : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
    }

    Item {
        id: iconCell
        anchors.left: num.right
        anchors.leftMargin: Theme.spaceS
        width: Theme.iconCell
        height: parent.height

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.selected ? Theme.accent
                : root.current || mouse.containsMouse ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
    }

    Column {
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
            color: root.selected || root.current || mouse.containsMouse ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.blurb
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: ">"
        visible: root.selected || root.current
        color: root.selected ? Theme.accent : Theme.subtext
        font.family: Theme.fontText
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
