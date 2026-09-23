// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowHeader.qml
//
// The header the standalone windows (Settings, System, Keybinds) share: an
// accent bar, a small spaced-out eyebrow over the window's name and a line
// under it, and a Close button. Dragging it moves the window.
//
// Pair it with a `bare` WindowChrome, which keeps the ground and Escape but
// leaves the title row to this.

import QtQuick
import "../services"

Item {
    id: root

    // the FloatingWindow this heads; needs close() and startSystemMove()
    required property var window
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""

    x: Theme.windowPad
    y: Theme.windowPad
    width: window.width - Theme.windowPad * 2
    height: headText.implicitHeight

    MouseArea {
        anchors.fill: parent
        onPressed: root.window.startSystemMove()
    }

    Rectangle {
        id: bar
        width: Math.max(3, Theme.borderWidth * 3)
        height: parent.height
        radius: width / 2
        color: Theme.accent
    }

    Column {
        id: headText
        anchors.left: bar.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: closeBtn.left
        anchors.rightMargin: Theme.spaceL
        spacing: 1

        Text {
            text: root.eyebrow
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontEyebrow
            font.letterSpacing: 1.5
        }

        Text {
            text: root.title
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontTitle
            font.bold: true
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.subtitle
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
    }

    Rectangle {
        id: closeBtn
        anchors.right: parent.right
        anchors.top: parent.top
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
            font.bold: true
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
