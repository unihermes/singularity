// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetCard.qml
//
// A desktop widget's card: a hard hairline edge round a see-through ground
// that's dark at the top and fades to nearly clear, its content in white
// with a tight dark shadow round every mark. The same under every style. Sizes sit on one grid so they line up: small is one unit square,
// medium two units and a gap wide, large two by two. Holds the inks and
// type the widgets draw with.

import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: card

    property string size: "m"
    readonly property bool small: size === "s"
    readonly property bool large: size === "l"

    readonly property int unit: Theme.fit(164)
    readonly property int gap: Theme.fit(16)
    readonly property int pad: Theme.fit(16)

    // white whatever the palette: it's over the wallpaper
    readonly property color fg: "#ffffff"
    readonly property color fgDim: Qt.rgba(1, 1, 1, 0.9)
    readonly property color fgFaint: Qt.rgba(1, 1, 1, 0.72)
    readonly property color track: Qt.rgba(1, 1, 1, 0.28)
    // the accent, lifted so it reads on any wallpaper
    readonly property color accent: Qt.lighter(Theme.accent, 1.6)
    readonly property string font: Fonts.resolve(Settings.systemFontFamily)

    default property alias content: body.data
    readonly property alias body: body

    width: small ? unit : unit * 2 + gap
    height: large ? unit * 2 + gap : unit

    // the ground: a hard-edged card, dark at the top fading to nearly clear
    Rectangle {
        anchors.fill: parent
        radius: Math.round(card.unit * 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.12) }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: card.pad

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 1)
            blurMax: 8
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }
}
