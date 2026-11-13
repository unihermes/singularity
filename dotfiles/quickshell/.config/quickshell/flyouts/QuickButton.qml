// Pane's quick-settings button: a framed button with the glyph, accent-
// filled while on (`lit`), and the name under it. `split` gives it a
// chevron part of its own, after a hairline, that opens its details
// (moreClicked; 󰅀 while `expanded`).

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property bool lit: false
    property bool split: false
    property bool expanded: false
    property bool usable: true

    signal clicked()
    signal moreClicked()

    implicitHeight: box.height + Theme.spaceS + name.implicitHeight

    Rectangle {
        id: box
        width: parent.width
        height: Theme.fs(44)
        radius: Theme.radiusInner
        color: root.lit ? Theme.accent : face.containsMouse || more.containsMouse ? Theme.hoverFill : Theme.overlay
        border.width: Theme.borderWidth
        border.color: root.lit ? Theme.accent : face.containsMouse || more.containsMouse ? Theme.muted : Theme.stroke
        opacity: root.usable ? 1 : 0.5

        Text {
            anchors.centerIn: face
            text: root.icon
            color: root.lit ? Theme.textOnAccent : Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize + Theme.spaceXs
        }
        MouseArea {
            id: face
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: root.split ? end.left : parent.right
            enabled: root.usable
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        Item {
            id: end
            visible: root.split
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.fs(26)
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.borderWidth
                height: parent.height - Theme.spaceM * 2
                color: root.lit ? Theme.textOnAccent : Theme.stroke
                opacity: root.lit ? 0.3 : 1
            }
            Text {
                anchors.centerIn: parent
                text: root.expanded ? "󰅀" : "󰅂"
                color: root.lit ? Theme.textOnAccent : more.containsMouse ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            MouseArea {
                id: more
                anchors.fill: parent
                enabled: root.usable
                hoverEnabled: enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.moreClicked()
            }
        }
    }

    Text {
        id: name
        anchors.top: box.bottom
        anchors.topMargin: Theme.spaceS
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontCaption
    }
}
