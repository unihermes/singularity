// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetText.qml
//
// Text on a WidgetCard, in its type and full ink unless told otherwise.

import QtQuick

Text {
    required property var card
    property int px: 14

    color: card.fg
    font.family: card.font
    font.pixelSize: px
    font.weight: Font.DemiBold
    elide: Text.ElideRight
}
