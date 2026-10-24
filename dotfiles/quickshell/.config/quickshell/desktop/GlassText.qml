// Singularity - Quickshell
// ~/.config/quickshell/desktop/GlassText.qml
//
// Text on a GlassCard, in its type and full ink unless told otherwise.

import QtQuick

Text {
    required property var card
    property int px: 14

    color: card.fg
    font.family: card.font
    font.pixelSize: px
    font.weight: Font.Medium
    elide: Text.ElideRight
}
