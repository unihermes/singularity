// Singularity - Quickshell
// ~/.config/quickshell/desktop/DeskWidget.qml
//
// One desktop widget by key, at its size: "s", "m" or "l" (WidgetCard's
// grid). Sized to its card. A key "note:" and an id is that sticky note.

import QtQuick

Item {
    id: root

    required property string key
    property string size: "m"
    // the screen's DesktopWidgets, for a note's +
    property var desk: null

    width: loader.item ? loader.item.width : 0
    height: loader.item ? loader.item.height : 0

    Loader {
        id: loader
        sourceComponent: root.key.indexOf("note:") === 0 ? note
            : ({ clock: clock, weather: weather, music: music, stats: stats })[root.key] || null
    }

    Component { id: clock; ClockWidget { size: root.size } }
    Component { id: weather; WeatherWidget { size: root.size } }
    Component { id: music; MusicWidget { size: root.size } }
    Component { id: stats; StatsWidget { size: root.size } }
    Component { id: note; NoteWidget { size: root.size; noteId: root.key.slice(5); desk: root.desk } }
}
