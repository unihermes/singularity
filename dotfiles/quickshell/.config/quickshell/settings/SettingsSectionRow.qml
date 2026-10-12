// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsSectionRow.qml
//
// One row in a window's sidebar (Settings, System): the page's icon, its
// name, and a line under it (`blurb`) saying what's there. A search hit
// uses the same row -- the setting's name over the page and heading it
// lives on, with that page's icon -- so the list looks the same whether
// it's the pages or what matched.
//
// Pages come in groups, set apart by a gap over each group's first row
// (`gapAbove`).
//
// Two ways to be lit: `selected` is the page on show (a tick and an
// accent chevron), `current` is where the arrow keys are while the search
// field has focus (a fill, a tick and a grey chevron). They differ because
// both can be true of different rows at once. A hovered row shows the grey
// chevron too, as a way in.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string blurb: ""
    property bool selected: false
    property bool current: false

    // room over the row, setting it apart from the group above; not part
    // of what lights up or takes the click
    property bool gapAbove: false
    readonly property int gapSpace: gapAbove ? Theme.spaceL : 0

    signal clicked()
    signal hovered()

    width: parent ? parent.width : 0
    // just clear of the two lines of text, so a long list fits unscrolled
    implicitHeight: Math.max(Theme.fieldHeight, texts.implicitHeight + Theme.spaceS) + gapSpace

    Item {
        y: root.gapSpace
        width: parent.width
        height: parent.height - root.gapSpace

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusInner
            color: root.current || mouse.containsMouse ? Theme.hoverFill : "transparent"
        }

        // the page on show, or the arrow keys' row: a tick on the left edge,
        // as a selected row
        Rectangle {
            visible: root.selected || root.current
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.indicatorWidth
            height: parent.height - 6
            radius: width / 2
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
                color: root.selected ? Theme.accent
                    : root.current || mouse.containsMouse ? Theme.textStrong : Theme.subtext
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
                color: root.selected || root.current || mouse.containsMouse ? Theme.textStrong : Theme.text
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
            visible: root.selected || root.current || mouse.containsMouse
            color: root.selected ? Theme.accent : Theme.subtext
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
