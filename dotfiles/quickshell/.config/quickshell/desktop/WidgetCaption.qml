// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetCaption.qml
//
// A caption on a WidgetCard: small spaced capitals in bold, in the accent
// unless told otherwise. What leads a widget or heads a group.

import QtQuick

WidgetText {
    px: card.textCaption
    color: card.accent
    font.weight: card.weightStrong
    font.letterSpacing: 1
    font.capitalization: Font.AllUppercase
}
