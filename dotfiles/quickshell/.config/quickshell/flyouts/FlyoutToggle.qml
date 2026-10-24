// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutToggle.qml
//
// A toggle as a glyph chip with its name under it, lit while on; for a
// row of them in a card (the Control Centre's).

import QtQuick
import "../services"

Column {
    id: root

    property alias icon: chip.text
    property alias caption: cap.text
    property alias lit: chip.selected
    property alias usable: chip.enabled
    signal clicked()

    spacing: Theme.spaceXs

    FlyoutChip {
        id: chip
        width: root.width
        height: Theme.rowHeightTall
        glyph: true
        onClicked: root.clicked()
    }

    Text {
        id: cap
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: chip.selected ? Theme.textStrong : Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontCaption
    }
}
