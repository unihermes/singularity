// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlRow.qml
//
// A Control Centre row: a glyph, the name, its state in words, then the
// style's switch (a click anywhere on the face toggles; `checkable: false`
// leaves the words alone, for a row whose click steps a value). `split`
// adds a chevron of its own after a hairline that opens the row's details
// in place (moreClicked; 󰅀 while `expanded`); `goes` puts 󰅂 on a row whose
// whole face opens a page.

import QtQuick
import "../services"

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string caption: ""
    property bool checked: false
    property bool checkable: true
    property bool split: false
    property bool expanded: false
    property bool goes: false
    property bool usable: true

    signal clicked()
    signal moreClicked()

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeightTall

    // where the state's words end: before the switch, else the chevron
    readonly property real wordsEnd: toggle.visible ? toggle.x - Theme.spaceL
        : end.visible ? end.x - Theme.spaceL : width

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.spaceS
        anchors.rightMargin: -Theme.spaceS
        radius: Theme.radiusInner
        color: face.containsMouse || more.containsMouse ? Theme.hoverFill : "transparent"
    }

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconCell
        horizontalAlignment: Text.AlignHCenter
        text: root.icon
        color: !root.usable ? Theme.textDisabled
            : root.checkable && !root.checked ? Theme.subtext : Theme.textStrong
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontIconSize
    }

    Text {
        id: name
        anchors.left: glyph.right
        anchors.leftMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, words.x - x - Theme.spaceL)
        text: root.title
        elide: Text.ElideRight
        color: !root.usable ? Theme.subtext : face.containsMouse ? Theme.textStrong : Theme.text
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
    }

    Text {
        id: words
        anchors.right: toggle.visible ? toggle.left : end.left
        anchors.rightMargin: toggle.visible || end.visible ? Theme.spaceL : 0
        anchors.verticalCenter: parent.verticalCenter
        // takes what the name leaves, eliding from the end
        width: Math.min(implicitWidth, Math.max(0, root.wordsEnd - name.x - name.implicitWidth - Theme.spaceL * 2))
        horizontalAlignment: Text.AlignRight
        text: root.caption
        elide: Text.ElideRight
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }

    Switch {
        id: toggle
        visible: root.checkable && !root.goes
        anchors.right: end.visible ? end.left : parent.right
        anchors.rightMargin: end.visible ? Theme.spaceS : 0
        anchors.verticalCenter: parent.verticalCenter
        interactive: false
        checked: root.checked
        enabled: root.usable
    }

    // the chevron end, set off by a hairline when it is a part of its own
    Item {
        id: end
        visible: root.split || root.goes
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.controlSize + (root.split ? Theme.spaceS : 0)

        Rectangle {
            visible: root.split
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderWidth
            height: parent.height - Theme.spaceM * 2
            color: Theme.stroke
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.controlSize
            horizontalAlignment: Text.AlignHCenter
            text: root.expanded ? "󰅀" : "󰅂"
            color: more.containsMouse || (root.goes && face.containsMouse) ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        MouseArea {
            id: more
            anchors.fill: parent
            enabled: root.split && root.usable
            hoverEnabled: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.moreClicked()
        }
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
}
