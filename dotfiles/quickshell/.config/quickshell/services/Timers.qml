// Singularity - Quickshell
// ~/.config/quickshell/services/Timers.qml
//
// One timer at a time, shown in the clock island and run from the calendar
// flyout or `qs ipc call timer ...`:
//   countdown  n minutes, then a notification and a chime
//   pomodoro   25 minutes of focus, 5 of break (15 after every fourth), each
//              phase starting the next on its own
//   stopwatch  counts up until stopped
//
// Kept as wall-clock times (when it ends, when it started) in a state file,
// never as a count of ticks: a suspend, a hibernate or a shell reload can't
// lose or stretch it, and one that ran out while the machine slept goes off
// on waking.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int focusMinutes: 25
    readonly property int breakMinutes: 5
    readonly property int longBreakMinutes: 15

    // "" | "countdown" | "pomodoro" | "stopwatch"
    readonly property string mode: st.mode
    readonly property bool active: mode !== ""
    readonly property bool paused: st.paused
    // pomodoro: "focus" | "break", and the focus sessions finished so far
    readonly property string phase: st.phase
    readonly property int rounds: st.rounds

    // ms since the epoch, moved on every second while running
    property real now: Date.now()

    readonly property real remaining: mode === "stopwatch" || !active ? 0
        : Math.max(0, paused ? st.pausedLeft : st.endsAt - now)
    readonly property real elapsed: mode !== "stopwatch" ? st.duration - remaining
        : paused ? st.pausedLeft : now - st.startedAt
    // 0..1 through the current countdown or phase; -1 for the stopwatch
    readonly property real progress: mode === "stopwatch" || !active || st.duration <= 0 ? -1
        : Math.min(1, Math.max(0, 1 - remaining / st.duration))

    readonly property string text: format(mode === "stopwatch" ? elapsed : remaining)
    readonly property string icon: paused ? "󰏤" : mode === "stopwatch" ? "󱎫"
        : mode === "pomodoro" ? (phase === "break" ? "󰾨" : "󰔟") : "󱫍"
    readonly property string title: mode === "stopwatch" ? "Stopwatch"
        : mode === "pomodoro" ? (phase === "break" ? "Break" : "Focus " + (rounds + 1))
        : "Timer"

    // "4:05", "1:04:05"
    function format(ms) {
        var s = Math.round(ms / 1000)
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
        var mm = h > 0 ? String(m).padStart(2, "0") : String(m)
        return (h > 0 ? h + ":" : "") + mm + ":" + String(sec).padStart(2, "0")
    }

    // --- actions -------------------------------------------------------------

    function begin(mode, minutes, phase, rounds) {
        var t = Date.now()
        now = t
        st.phase = phase || ""
        st.rounds = rounds || 0
        st.duration = minutes * 60000
        st.startedAt = t
        st.endsAt = t + minutes * 60000
        st.paused = false
        st.pausedLeft = 0
        // last: setting it starts the tick, which checks the times above
        st.mode = mode
    }

    function countdown(minutes) {
        minutes = Math.max(1, Math.min(24 * 60, Math.round(minutes)))
        begin("countdown", minutes)
    }
    function pomodoro() { begin("pomodoro", focusMinutes, "focus", 0) }
    function stopwatch() { begin("stopwatch", 0) }

    function togglePause() {
        if (!active) return
        var t = Date.now()
        if (!paused) {
            st.pausedLeft = mode === "stopwatch" ? t - st.startedAt : Math.max(0, st.endsAt - t)
            st.paused = true
        } else {
            if (mode === "stopwatch") st.startedAt = t - st.pausedLeft
            else st.endsAt = t + st.pausedLeft
            st.paused = false
        }
        now = t
    }

    function addMinutes(n) {
        if (!active || mode === "stopwatch") return
        if (paused) st.pausedLeft += n * 60000
        else st.endsAt += n * 60000
        st.duration += n * 60000
        now = Date.now()
    }

    // pomodoro: on to the next phase now
    function skip() { if (mode === "pomodoro") finish(false) }

    function stop() {
        st.mode = ""
        st.paused = false
    }

    // --- running out ---------------------------------------------------------

    function check() {
        now = Date.now()
        if (active && mode !== "stopwatch" && !paused && now >= st.endsAt) finish(true)
    }

    function finish(alert) {
        if (mode === "pomodoro") {
            var focusDone = phase === "focus"
            var r = rounds + (focusDone ? 1 : 0)
            var next = focusDone ? (r % 4 === 0 ? longBreakMinutes : breakMinutes) : focusMinutes
            if (alert) notify(focusDone ? "Focus done" : "Break over",
                focusDone ? next + " minute break" : "Back to it: " + next + " minutes of focus")
            begin("pomodoro", next, focusDone ? "break" : "focus", r)
        } else {
            if (alert) notify("Time's up", format(st.duration) + " timer")
            stop()
        }
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "Timer", "-i", "alarm-symbolic", summary, body])
        Quickshell.execDetached(["sh", "-c",
            "f=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; [ -r \"$f\" ] && exec pw-play \"$f\""])
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && !root.paused
        triggeredOnStart: true
        onTriggered: root.check()
    }

    Connections {
        target: Session
        function onResumed() { root.check() }
    }

    // --- persistence ---------------------------------------------------------

    // Writes wait a moment: writing from inside onAdapterUpdated drops the
    // assignments that follow in the same call.
    Timer {
        id: saveTimer
        interval: 100
        onTriggered: stateFile.writeAdapter()
    }

    FileView {
        id: stateFile
        path: Settings.stateDir + "/timer.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onAdapterUpdated: saveTimer.restart()
        // a timer that ran out while the shell was down goes off now
        onLoaded: Qt.callLater(root.check)

        JsonAdapter {
            id: st
            property string mode: ""
            property string phase: ""
            property int rounds: 0
            property real duration: 0
            property real startedAt: 0
            property real endsAt: 0
            property bool paused: false
            // ms left (or, for the stopwatch, gone) when paused
            property real pausedLeft: 0
        }
    }

    IpcHandler {
        target: "timer"
        // `qs ipc call timer start 10`: a ten-minute countdown
        function start(minutes: int): void { root.countdown(minutes) }
        function pomodoro(): void { root.pomodoro() }
        function stopwatch(): void { root.stopwatch() }
        function toggle(): void { root.togglePause() }
        function stop(): void { root.stop() }
    }
}
