// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowHeader.qml
//
// The title bar the standalone windows (Settings, System, Keybinds) share,
// one line high: an accent bar, the window's name with a quieter subtitle
// after it, then `slot` -- the rest of the line, where Settings puts its
// search -- and a Close button. Dragging it moves the window.
//
// Sits over a WindowChrome, which draws the ground and takes Escape.

import QtQuick
import "../services"

Item {
    id: root

    // the FloatingWindow this heads; needs close() and startSystemMove()
    required property var window
    property string title: ""
    property string subtitle: ""
    // the space between the title and Close, for a search field
    readonly property alias slot: slot

    x: Theme.windowPad
    y: Theme.windowPad
    width: window.width - Theme.windowPad * 2
    height: Theme.rowHeightTall + Theme.spaceM

    MouseArea {
        anchors.fill: parent
        onPressed: root.window.startSystemMove()
    }

    Rectangle {
        id: bar
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(3, Theme.borderWidth * 3)
        height: titleText.implicitHeight
        radius: width / 2
        color: Theme.accent
    }

    Text {
        id: titleText
        anchors.left: bar.right
        anchors.leftMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.textStrong
        font.family: Theme.fontText
        font.pixelSize: Theme.fontTitle
        font.weight: Theme.weightStrong
    }

    Text {
        id: subtitleText
        anchors.left: titleText.right
        anchors.leftMargin: Theme.spaceM
        anchors.baseline: titleText.baseline
        // as much as fits beside a search field, all of it without one
        width: Math.min(implicitWidth, slot.children.length > 0 ? Theme.fit(160) : closeBtn.x - x - Theme.spaceL)
        elide: Text.ElideRight
        text: root.subtitle
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontCaption
    }

    Item {
        id: slot
        anchors.left: subtitleText.right
        anchors.leftMargin: Theme.spaceXl
        anchors.right: closeBtn.left
        anchors.rightMargin: Theme.spaceL
        height: parent.height
    }

    Rectangle {
        id: closeBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: closeLabel.implicitWidth + Theme.spaceXl * 2
        height: Theme.rowHeight
        radius: Theme.radiusInner
        color: closeMouse.containsMouse ? Theme.hoverFill : Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: closeMouse.containsMouse ? Theme.strokeHover : Theme.stroke

        Text {
            id: closeLabel
            anchors.centerIn: parent
            text: "Close"
            color: closeMouse.containsMouse ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
            font.weight: Theme.weightStrong
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.window.close()
        }
    }
}
