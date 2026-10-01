// Singularity - Quickshell
// ~/.config/quickshell/bar/ClockIsland.qml
//
// The clock chip, which doubles as a Dynamic Island: for a moment after
// something changes it shows that instead of the time, then eases back.
//
//   volume / brightness  a level meter
//   layout, lock keys    the mode just switched to (SUPER+M, Caps/Num Lock)
//
// While a timer runs (services/Timers.qml) it shows that and the clock in
// place of the time, sized to them, with the timer's progress as the fill.
//
// The chip keeps its width through an event, eliding what doesn't fit, so
// nothing on the bar moves when an event comes and goes.
//
// Settings.clockIsland turns it off, and LevelToast/ModeToast step aside
// only while it's on and the clock is actually on the bar
// (Settings.islandActive), so there's always exactly one place these show.

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
    // Thin spaces around the divider: in a monospace font an ordinary space
    // is a full character wide, which left the time and date far apart.
    // One format per clock style (Looks.js).
    readonly property var formats: ({
        stamp: "HH:mm:ss\u2009|\u2009MM/dd/yy",
        time:  "HH:mm",
        day:   "ddd d MMM\u2002HH:mm",
        long:  "dddd, MMMM d\u2002\u00b7\u2002HH:mm",
        seconds: "HH:mm:ss",
        iso:   "yyyy-MM-dd\u2002HH:mm",
        custom: Settings.clockFormat || "HH:mm",
    })
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

    // the running timer and the clock after it; the chip hugs these for as
    // long as the timer runs, rather than keeping the time's width
    // a Text, not TextMetrics: the label is a Text, and its implicit width
    // runs a pixel or two past TextMetrics' advance, which would elide it
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
        if (!ready || !Settings.clockIsland || !root.visible) return
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
