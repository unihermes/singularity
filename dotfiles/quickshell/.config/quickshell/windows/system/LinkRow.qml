// Singularity - Quickshell
// ~/.config/quickshell/windows/system/LinkRow.qml
//
// One entry on the Config page: a name, the path it stands for, a click
// that opens it, and a hover button that reveals the containing folder.
//
// Opening goes through scripts/open-file.sh rather than xdg-open, for the
// reasons that script's own header sets out -- half of what is listed here
// is a .lua, a .conf or a shell script, and xdg-open silently does nothing
// with most of those on this machine.
//
// A row whose file doesn't exist is shown greyed and refuses the click,
// rather than hidden: half the value of this page is seeing that the
// file you expected isn't there.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"

Item {
    id: root

    property string label: ""
    property string path: ""
    // set by the page once it has stat'd the whole list in one go
    property bool exists: true
    // what this file is for, shown small under the name
    property string note: ""

    readonly property string home: Quickshell.env("HOME")
    // "~/.config/hypr/hyprland.lua" reads better than the absolute path and
    // fits the pane without eliding
    readonly property string shortPath: path.indexOf(home) === 0
        ? "~" + path.slice(home.length) : path

    width: parent ? parent.width : 0
    implicitHeight: note !== "" ? Theme.row(36) : Theme.rowHeightTall

    function open() {
        if (!exists) return
        Quickshell.execDetached([root.home + "/.config/quickshell/scripts/open-file.sh", root.path])
    }

    function reveal() {
        Quickshell.execDetached([root.home + "/.config/quickshell/scripts/open-file.sh",
            root.path.replace(/\/[^/]*$/, "")])
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: (root.exists && mouse.containsMouse) ? Theme.hoverFill : "transparent"
    }

    HoverHandler { id: rowHover }

    Column {
        anchors.left: parent.left
        // the path sits on the right until the row is hovered, when the
        // reveal button takes that corner -- so the name's own right edge
        // has to follow whichever of the two is showing
        anchors.right: rowHover.hovered ? revealBtn.left : pathText.left
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: !root.exists ? Theme.textDisabled
                : mouse.containsMouse ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            visible: root.note !== ""
            width: parent.width
            text: root.note
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    Text {
        id: pathText
        visible: !rowHover.hovered
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // never more than half the row, so a long path elides instead of
        // pushing the name off its own line
        width: Math.min(implicitWidth, root.width * 0.5)
        horizontalAlignment: Text.AlignRight
        text: root.exists ? root.shortPath : "missing"
        elide: Text.ElideLeft
        color: root.exists ? Theme.muted : Theme.alert
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.exists
        enabled: root.exists
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
    }

    // after the row's MouseArea, so it sits on top and takes its own clicks
    Rectangle {
        id: revealBtn
        visible: rowHover.hovered && root.exists
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.fs(24)
        height: Theme.chipHeight
        radius: Theme.radiusInner
        color: revealMouse.containsMouse ? Theme.hoverFillSoft : "transparent"
        border.width: Theme.borderWidth
        border.color: revealMouse.containsMouse ? Theme.strokeHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: "󰝰"
            color: revealMouse.containsMouse ? Theme.textStrong : Theme.muted
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        MouseArea {
            id: revealMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.reveal()
        }
    }
}
