// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutCycler.qml
//
// A setting whose choices are a list, stepped one at a time: a label, the
// current choice right-aligned, and previous/next chips.
//
// FlyoutRow's click-to-cycle covers the settings with two or three choices,
// where clicking past the one you wanted costs one more click. This is for
// the longer lists -- a dozen fonts, every wallpaper on disk -- where going
// back one shouldn't mean clicking through all the others. It lines its
// label and value up the same way FlyoutStepper does, so a page can mix the
// two without the values wandering.

import QtQuick
import "../services"

Item {
    id: root

    property string label: ""
    property string value: ""
    property bool enabled: true
    // a shuffle chip between the arrows, for a list long enough that
    // stepping to somewhere new isn't worth the clicks
    property bool shuffleable: false

    signal stepped(int delta)
    signal shuffled()

    width: parent ? parent.width : 0
    implicitHeight: Theme.rowHeight

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    // takes whatever the label leaves and elides: look and wallpaper names
    // are as long as their files are
    Text {
        anchors.left: labelText.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: chips.left
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.value
        elide: Text.ElideRight
        color: root.enabled ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
    }

    Row {
        id: chips
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS

        FlyoutChip {
            glyph: true
            text: "󰒮"
            enabled: root.enabled
            onClicked: root.stepped(-1)
        }

        FlyoutChip {
            visible: root.shuffleable
            glyph: true
            text: "󰒝"
            enabled: root.enabled
            onClicked: root.shuffled()
        }

        FlyoutChip {
            glyph: true
            text: "󰒭"
            enabled: root.enabled
            onClicked: root.stepped(1)
        }
    }
}
