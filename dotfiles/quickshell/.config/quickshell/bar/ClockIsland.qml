// Singularity - Quickshell
// ~/.config/quickshell/bar/ClockIsland.qml
//
// The clock chip as a Dynamic Island: briefly shows a level (volume,
// brightness), a mode (SUPER+M, lock keys) or the lid instead of the time,
// keeping its width. A running timer (Timers.qml) shows with the clock,
// its progress as the fill. With Settings.clockIsland off, or the clock off
// the bar (Settings.islandActive), LevelToast/ModeToast show instead.

import Quickshell
import QtQuick
import "../services"

BarModule {
    id: root

    required property var screenScope

    // "" shows the time
    property string kind: ""
    property string evIcon: ""
    property string evText: ""
    property real evFill: -1
    readonly property bool showing: kind !== ""

    SystemClock {
        id: clockSource
        // ticks on the second boundary, so the seconds never skip or stall;
        // on the minute when the clock style doesn't show seconds
        precision: (root.formats[Theme.clockStyle] || root.formats.stamp).indexOf("ss") >= 0 ? SystemClock.Seconds : SystemClock.Minutes
        enabled: root.visible
    }
    readonly property var formats: Theme.clockFormats
    readonly property string timeText: Qt.formatDateTime(clockSource.date,
        Theme.hours(formats[Theme.clockStyle] || formats.stamp))

    // the chip's width while it shows the time, which it keeps for events
    TextMetrics {
        id: timeMetrics
        font.family: Theme.fontText
        font.pixelSize: Theme.barLabelSize
        font.weight: Theme.weightBody
        text: root.timeText
    }
    readonly property int idleWidth: Math.ceil(timeMetrics.advanceWidth) + root.chrome

    // the running timer and the clock; a Text, since TextMetrics' advance
    // runs a pixel short and would elide the label
    Text {
        id: timerMetrics
        visible: false
        font.family: Theme.fontText
        font.pixelSize: Theme.barLabelSize
        font.weight: Theme.weightBody
        text: Timers.text + "\u2002·\u2002" + Qt.formatDateTime(clockSource.date, Theme.timeFormat)
    }
    readonly property int chipWidth: Timers.active ? Math.ceil(timerMetrics.implicitWidth + timerChrome) : idleWidth
    // the chip's room round the timer's text, icon included; held through
    // an event, whose own icon would otherwise resize the chip
    property real timerChrome: 0
    Binding {
        target: root
        property: "timerChrome"
        value: root.labelChrome
        when: Timers.active && !root.showing
        restoreMode: Binding.RestoreNone
    }

    icon: showing ? evIcon : Timers.active ? Timers.icon : ""
    label: showing ? evText : Timers.active ? timerMetrics.text : timeText
    fillValue: showing ? evFill : Timers.active ? Timers.progress : -1
    fillColor: Theme.muted
    fixedWidth: chipWidth
    labelMaxWidth: showing || Timers.active ? Math.max(1, Math.ceil(chipWidth - labelChrome)) : 0
    active: screenScope.openFlyout === "calendar"
    onActivated: screenScope.toggleFlyout("calendar", root)
    // middle click pauses or resumes a running timer
    onMiddleClicked: Timers.togglePause()

    function show(kind, icon, text, fill, ms) {
        // the startup guard is for levels only; modes are always real events
        if ((!ready && kind !== "mode") || !Settings.clockIsland || !root.visible) return
        root.kind = kind
        root.evIcon = icon
        root.evText = text
        root.evFill = fill
        hideTimer.interval = ms
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        onTriggered: root.kind = ""
    }

    // Brightness loads from sysfs and the sink settles -- both look like a
    // change shortly after startup.
    property bool ready: false
    Timer { interval: 2000; running: true; onTriggered: root.ready = true }

    // --- levels ---------------------------------------------------------------

    function showVolume() {
        show("volume", Audio.muted ? "󰖁" : "󰕾", Audio.muted ? "Muted" : Audio.percent + "%",
             Audio.muted ? 0 : Audio.percent / 100, 1600)
    }

    Connections {
        target: Audio
        function onPercentChanged() { root.showVolume() }
        function onMutedChanged() { root.showVolume() }
    }

    Connections {
        target: Brightness
        function onLevelChanged() {
            root.show("brightness", "󰃠", Brightness.level + "%", Brightness.level / 100, 1600)
        }
    }

    // --- modes --------------------------------------------------------------
    // modeToastSeq is already filtered to the focused monitor (shell.qml)

    Connections {
        target: root.screenScope
        function onModeToastSeqChanged() {
            root.show("mode", root.screenScope.modeToastIcon,
                      Theme.heading(root.screenScope.modeToastText), -1, 1100)
        }
    }
}
