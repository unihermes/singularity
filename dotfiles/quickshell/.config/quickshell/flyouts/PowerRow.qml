// A large boxed row for a session action (Lock, Reboot, Shut Down): a big
// glyph, the title with a caption under it, and a chevron at the end for
// `more`, whose options (children) open inside the box. `confirmText`
// makes it two clicks, armed alert-red for 3s.

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

    default property alias options: optionsBox.data
    readonly property real headHeight: Theme.rowHeightTall * 2

    width: parent ? parent.width : 0
    implicitHeight: headHeight + (root.expanded && optionsBox.childrenRect.height > 0
        ? optionsBox.childrenRect.height + Theme.spaceM : 0)

    Rectangle {
        id: box
        readonly property color edge: root.armed ? Theme.alert
            : mouse.containsMouse ? Theme.strokeHover : Theme.stroke
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.frameCustom && Theme.frameStyle === "notch" ? "transparent"
            : root.armed ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.12)
            : Theme.controlFill(mouse.containsMouse ? Theme.hoverFillSoft : "transparent")
        border.width: Theme.controlBorder(edge)
        border.color: Theme.controlStroke(edge)

        ControlEdge {
            visible: Theme.controlStyle === "channel" || Theme.controlStyle === "double" || Theme.frameCustom
            ground: Theme.frameStyle === "notch" ? box.color : "transparent"
            stroke: box.edge; radius: box.radius
            lit: false
        }
    }

    Item {
        id: optionsBox
        visible: root.expanded
        x: Theme.spaceM
        y: root.headHeight - Theme.spaceXs
        width: parent.width - Theme.spaceM * 2
        height: childrenRect.height
    }

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceM
        y: (root.headHeight - height) / 2
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
        y: (root.headHeight - height) / 2
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
        width: parent.width
        height: root.headHeight
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
        anchors.rightMargin: Theme.spaceS
        y: (root.headHeight - height) / 2
        implicitWidth: Theme.rowHeightTall * 1.5
        implicitHeight: Theme.rowHeightTall * 1.5
        glyphSize: Theme.fontIconSize * 1.6
        icon: root.expanded ? "󰅀" : "󰅂"
        onClicked: root.moreClicked()
    }

    Timer { id: disarm; interval: 3000 }
}
