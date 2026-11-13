// A line in a Glass details card: glyph, name, then words or a tick (the current one).

import QtQuick
import "../services"

Item {
    id: dr
    property string icon: ""
    property string label: ""
    property string trailing: ""
    property bool current: false
    signal activated()
    width: parent ? parent.width : 0
    height: Theme.fs(30)
    Rectangle {
        anchors.fill: parent
        radius: Theme.fs(8)
        color: drMouse.containsMouse ? Theme.washActive : "transparent"
    }
    Text {
        id: drIcon
        x: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell
        horizontalAlignment: Text.AlignHCenter
        text: dr.icon
        color: Theme.textStrong
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }
    Text {
        anchors.left: drIcon.right
        anchors.leftMargin: Theme.spaceM
        anchors.right: drEnd.left
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        text: dr.label
        elide: Text.ElideRight
        color: dr.current ? Theme.textStrong : Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }
    Text {
        id: drEnd
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        text: dr.current ? "󰄬" : dr.trailing
        color: dr.current ? Theme.accent : Theme.subtext
        font.family: dr.current ? Theme.fontIcon : Theme.fontText
        font.pixelSize: dr.current ? Theme.fontIconSize : Theme.fontCaption
    }
    MouseArea {
        id: drMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dr.activated()
    }
}
