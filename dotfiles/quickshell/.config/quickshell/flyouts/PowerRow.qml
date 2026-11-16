// A large row for a session action (Lock, Reboot, Shut Down): a big glyph,
// the title with a caption under it, and a chevron slot at the end for
// `more`. `confirmText` makes it two clicks, armed alert-red for 3s.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string caption: ""
    property string confirmText: ""
    // something to open beside the row (Reboot's boot targets)
    property bool more: false
    property bool expanded: false
    readonly property bool armed: disarm.running

    signal activated()
    signal moreClicked()

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeightTall * 2

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceXs
        anchors.rightMargin: -Theme.spaceXs
        radius: Theme.radiusInner
        color: mouse.containsMouse ? Theme.hoverFill : "transparent"
    }

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell * 1.5
        horizontalAlignment: Text.AlignHCenter
        text: root.icon
        color: root.armed ? Theme.alert : mouse.containsMouse ? Theme.textStrong : Theme.accent
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize * 1.6
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: Theme.spaceM
        anchors.right: moreBtn.visible ? moreBtn.left : parent.right
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.label
            color: root.armed ? Theme.alert : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody + 3
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.armed ? root.confirmText : root.caption
            color: root.armed ? Theme.alert : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.confirmText !== "" && !disarm.running) { disarm.restart(); return }
            disarm.stop()
            root.activated()
        }
    }

    IconButton {
        id: moreBtn
        visible: root.more
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: root.expanded ? "󰅀" : "󰅂"
        onClicked: root.moreClicked()
    }

    Timer { id: disarm; interval: 3000 }
}
