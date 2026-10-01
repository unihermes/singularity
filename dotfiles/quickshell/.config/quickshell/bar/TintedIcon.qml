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

    layer.enabled: tint !== "colour"
    layer.effect: MultiEffect {
        saturation: root.tint === "mono" ? -1 : 0
        colorization: root.tint === "accent" ? 1 : 0
        colorizationColor: Theme.accent
        // colourised icons keep their own lightness, and most app icons
        // are dark enough to turn muddy without a lift
        brightness: root.tint === "accent" ? 0.6 : 0
    }
}
