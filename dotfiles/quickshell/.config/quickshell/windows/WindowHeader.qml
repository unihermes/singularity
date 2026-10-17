// Singularity - Quickshell
// ~/.config/quickshell/windows/WindowHeader.qml
//
// The title bar the standalone windows (Settings, System, Keybinds) share,
// one line high: an accent bar, the window's name with a quieter subtitle
// after it, then `slot` -- the rest of the line, where Settings puts its
// search -- and a Close button. Dragging it moves the window.
//
// Inside a page (`page` set) it reads as a path instead: a back button in
// place of the bar, the window's name quieter and clickable, then the
// page's name; both go back to the window's Home (`back`).
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
    // the open page's name, or "" on the window's Home
    property string page: ""
    readonly property bool inPage: page !== ""
    // the space between the title and Close, for a search field
    readonly property alias slot: slot

    signal back()

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
        visible: !root.inPage
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(3, Theme.borderWidth * 3)
        height: titleText.implicitHeight
        radius: Theme.pill(width)
        color: Theme.accent
    }

    Rectangle {
        id: backBtn
        visible: root.inPage
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.rowHeight
        height: Theme.rowHeight
        radius: Theme.radiusInner
        color: backMouse.containsMouse ? Theme.hoverFill : Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: backMouse.containsMouse ? Theme.strokeHover : Theme.stroke

        Text {
            anchors.centerIn: parent
            text: "󰁍"
            color: backMouse.containsMouse ? Theme.textStrong : Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    Text {
        id: titleText
        anchors.left: root.inPage ? backBtn.right : bar.right
        anchors.leftMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: !root.inPage || titleMouse.containsMouse ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontTitle
        font.weight: Theme.weightStrong

        MouseArea {
            id: titleMouse
            anchors.fill: parent
            enabled: root.inPage
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }

    // the page's name after the window's, on the same baseline
    Text {
        id: crumbSep
        visible: root.inPage
        anchors.left: titleText.right
        anchors.leftMargin: Theme.spaceM
        anchors.verticalCenter: titleText.verticalCenter
        text: "󰅂"
        color: Theme.muted
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontSmall
    }

    Text {
        id: pageText
        visible: root.inPage
        anchors.left: crumbSep.right
        anchors.leftMargin: Theme.spaceM
        anchors.baseline: titleText.baseline
        text: root.page
        color: Theme.textStrong
        font.family: Theme.fontText
        font.pixelSize: Theme.fontTitle
        font.weight: Theme.weightStrong
    }

    Text {
        id: subtitleText
        visible: !root.inPage
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
        anchors.left: root.inPage ? pageText.right : subtitleText.right
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
