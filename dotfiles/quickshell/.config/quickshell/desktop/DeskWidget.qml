// Singularity - Quickshell
// ~/.config/quickshell/desktop/DeskWidget.qml
//
// One desktop widget by key, at its size (S, M or L scale the whole
// panel). Sized to what it draws.

import QtQuick

Item {
    id: root

    required property string key
    property string size: "m"
    readonly property real factor: ({ s: 0.85, m: 1, l: 1.25 })[size] || 1

    width: loader.item ? Math.round(loader.item.width * factor) : 0
    height: loader.item ? Math.round(loader.item.height * factor) : 0

    Loader {
        id: loader
        scale: root.factor
        transformOrigin: Item.TopLeft
        sourceComponent: ({ clock: clock, weather: weather, music: music, stats: stats })[root.key] || null
    }

    Component { id: clock; ClockWidget {} }
    Component { id: weather; WeatherWidget {} }
    Component { id: music; MusicWidget {} }
    Component { id: stats; StatsWidget {} }
}
