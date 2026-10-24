// Singularity - Quickshell
// ~/.config/quickshell/desktop/GlassCard.qml
//
// A desktop widget's card: frosted glass (the layer's blur behind a
// see-through ground) with large round corners and a hairline edge, the
// same under every style. Sizes sit on one grid so they line up: small is
// one unit square, medium two units and a gap wide, large two by two.
// Holds the inks and type the widgets draw with.

import QtQuick
import "../services"

Item {
    id: card

    property string size: "m"
    readonly property bool small: size === "s"
    readonly property bool large: size === "l"

    readonly property int unit: Theme.fit(164)
    readonly property int gap: Theme.fit(16)
    readonly property int pad: Theme.fit(16)

    readonly property bool light: Theme.isLight
    readonly property color fg: light ? "#1c1c1e" : "#ffffff"
    readonly property color fgDim: Qt.rgba(fg.r, fg.g, fg.b, 0.62)
    readonly property color fgFaint: Qt.rgba(fg.r, fg.g, fg.b, 0.3)
    readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.16)
    // the accent, lifted on dark glass so it reads as a tint
    readonly property color accent: light ? Theme.accent : Qt.lighter(Theme.accent, 1.5)
    readonly property string font: Fonts.resolve(Settings.systemFontFamily)

    default property alias content: body.data
    readonly property alias body: body

    width: small ? unit : unit * 2 + gap
    height: large ? unit * 2 + gap : unit

    Rectangle {
        anchors.fill: parent
        radius: Math.round(card.unit * 0.14)
        // over the alpha the layer rule blurs from
        color: card.light ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0.07, 0.07, 0.09, 0.42)
        border.width: 1
        border.color: card.light ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.12)
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: card.pad
    }
}
