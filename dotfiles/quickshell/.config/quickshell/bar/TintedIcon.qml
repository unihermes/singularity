// Singularity - Quickshell
// ~/.config/quickshell/bar/TintedIcon.qml
//
// An app icon in the bar, drawn as Theme.iconTint says: as it is, greyed,
// or recoloured to the accent's hue. The effect layer only exists while a
// tint is on.

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../services"

IconImage {
    id: root

    readonly property string tint: Theme.iconTint
    // greyed whatever the tint, for an icon that's set back from the rest
    property bool grey: false

    layer.enabled: tint !== "colour" || grey
    layer.effect: MultiEffect {
        saturation: root.tint === "mono" || root.grey ? -1 : 0
        colorization: root.tint === "accent" && !root.grey ? 1 : 0
        colorizationColor: Theme.accent
        // colourised icons keep their own lightness, and most app icons
        // are dark enough to turn muddy without a lift
        brightness: root.tint === "accent" ? 0.6 : 0
    }
}
