// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetCard.qml
//
// A desktop widget's card: a panel framed and rounded as the style has
// it, on its ground kept see-through, its content in the palette's inks
// with a tight halo of the base colour round every mark. Sizes sit on one grid so they line up: small is one unit square,
// medium two units and a gap wide, large two by two. Holds the inks and
// type the widgets draw with.

import QtQuick
import QtQuick.Effects
import "../services"
import "../flyouts"

Item {
    id: card

    property string size: "m"
    readonly property bool small: size === "s"
    readonly property bool large: size === "l"

    readonly property int unit: Theme.fit(164)
    readonly property int gap: Theme.fit(16)
    readonly property int pad: Theme.fit(16)

    readonly property color fg: Theme.textStrong
    readonly property color fgDim: Theme.text
    readonly property color fgFaint: Theme.subtext
    readonly property color track: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.6)
    // lifted on a dark palette, so it reads through the see-through ground
    readonly property color accent: Theme.isLight ? Theme.accent : Qt.lighter(Theme.accent, 1.4)
    // the system font (Appearance > Apps), else the shell's
    readonly property string font: Fonts.loaded.indexOf(Settings.systemFontFamily) !== -1
        ? Settings.systemFontFamily : Theme.fontText
    // Three sizes and two weights, past each widget's one large figure:
    // captions (spaced capitals, bold, the accent for a widget's lead),
    // body and titles. Medium for anything read, the figures too; bold for
    // what names or leads: captions, labels, titles, today.
    readonly property int textCaption: Theme.fit(13)
    readonly property int textBody: Theme.fit(14)
    readonly property int textTitle: Theme.fit(16)
    readonly property int weightBody: Font.Medium
    readonly property int weightStrong: Font.Bold

    default property alias content: body.data
    readonly property alias body: body

    // a size of its own in units (a sticky note's, dragged in edit mode),
    // 0 for the grid's
    property real unitsWide: 0
    property real unitsHigh: 0

    width: unitsWide > 0 ? Math.round(unitsWide * unit) : small ? unit : unit * 2 + gap
    height: unitsHigh > 0 ? Math.round(unitsHigh * unit) : large ? unit * 2 + gap : unit

    PanelFrame {
        anchors.fill: parent
        ground: Theme.deskFill(0.3)
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: card.pad

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.base
            blurMax: 8
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }
}
