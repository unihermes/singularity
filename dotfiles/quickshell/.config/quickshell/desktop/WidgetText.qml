// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetText.qml
//
// Text on a WidgetCard, in its type and full ink unless told otherwise.

import QtQuick

Text {
    required property var card
    property int px: card.textBody

    color: card.fg
    font.family: card.font
    font.pixelSize: px
    font.weight: card.weightBody
    elide: Text.ElideRight
}
