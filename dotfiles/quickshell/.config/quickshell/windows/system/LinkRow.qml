// Singularity - Quickshell
// ~/.config/quickshell/windows/system/LinkRow.qml
//
// A Config page entry: name, path, a click that opens it (open-file.sh), a
// hover button revealing its folder. A missing file is greyed and inert.

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
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        Text {
            visible: root.note !== ""
            width: parent.width
            text: root.note
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
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
        font.weight: Theme.weightBody
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
    IconButton {
        id: revealBtn
        visible: rowHover.hovered && root.exists
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰝰"
        onClicked: root.reveal()
    }
}
