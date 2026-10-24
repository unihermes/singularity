// Singularity - Quickshell
// ~/.config/quickshell/desktop/DeskWidget.qml
//
// One desktop widget by key, at its size: "s", "m" or "l" (WidgetCard's
// grid). Sized to its card. A key "note:" and an id is that sticky note,
// which can have its own size instead, in card units.

import QtQuick

Item {
    id: root

    required property string key
    property string size: "m"
    property real unitsWide: 0
    property real unitsHigh: 0
    // the screen's DesktopWidgets, for a note's +
    property var desk: null
    // a note handing its typing back
    signal letGo()

    width: loader.item ? loader.item.width : 0
    height: loader.item ? loader.item.height : 0

    Loader {
        id: loader
        sourceComponent: root.key.indexOf("note:") === 0 ? note
            : ({ clock: clock, weather: weather, music: music, stats: stats, sysinfo: sysinfo })[root.key] || null
    }

    Component { id: clock; ClockWidget { size: root.size } }
    Component { id: weather; WeatherWidget { size: root.size } }
    Component { id: music; MusicWidget { size: root.size } }
    Component { id: stats; StatsWidget { size: root.size } }
    Component { id: sysinfo; SysInfoWidget { size: root.size } }
    Component { id: note; NoteWidget { size: root.size; unitsWide: root.unitsWide; unitsHigh: root.unitsHigh; noteId: root.key.slice(5); desk: root.desk; onLetGo: root.letGo() } }
}
