// Singularity - Quickshell
// ~/.config/quickshell/bar/ClockIsland.qml
//
// The clock chip, which doubles as a Dynamic Island: for a moment after
// something changes it shows that instead of the time, then eases back.
//
//   volume / brightness  the chip keeps its width and becomes a level meter
//   layout (SUPER+M)     the mode just switched to
//   track change         artist and title, while a player is playing
//   notifications        how many new ones arrived (not during DND)
//
// Settings.clockIsland turns it off, and LevelToast/LayoutToast step aside
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
        // ticks on the second boundary, so the seconds never skip or stall
        precision: SystemClock.Seconds
        enabled: root.visible
    }
    // thin spaces around the divider: in a monospace font an ordinary space
    // is a full character wide, which left the time and date far apart
    readonly property string timeText: Qt.formatDateTime(clockSource.date, "HH:mm:ss\u2009|\u2009MM/dd/yy")

    // the time's own width, so a level can take the chip over without the
    // modules either side of it moving
    TextMetrics {
        id: timeMetrics
        font.family: Theme.fontText
        font.pixelSize: Theme.barLabelSize
        text: root.timeText
    }
    readonly property int idleWidth: Math.ceil(timeMetrics.advanceWidth) + root.padH * 2

    icon: showing ? evIcon : ""
    label: showing ? evText : timeText
    fillValue: showing ? evFill : -1
    fillColor: Theme.muted
    fixedWidth: showing && evFill >= 0 ? idleWidth : 0
    labelMaxWidth: showing ? Theme.fs(320) : 0
    // Only while switching between the time and an event: in a proportional
    // font the time itself changes width every second, and easing (and
    // clipping) that would keep its first digit permanently cut off.
    animateWidth: morphing
    property bool morphing: false
    active: screenScope.openFlyout === "calendar"
    onActivated: screenScope.toggleFlyout("calendar", root)

    function show(kind, icon, text, fill, ms) {
        if (!ready || !Settings.clockIsland || !root.visible) return
        settle.stop()
        root.morphing = true
        root.kind = kind
        root.evIcon = icon
        root.evText = text
        root.evFill = fill
        hideTimer.interval = ms
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        onTriggered: {
            root.kind = ""
            settle.restart()
        }
    }

    // outlasts the width animation back to the time
    Timer {
        id: settle
        interval: Theme.durSlow + 50
        onTriggered: root.morphing = false
    }

    // Brightness loads from sysfs, the sink settles, swaync and the player
    // report in -- all of it looks like a change shortly after startup.
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

    // --- layout ---------------------------------------------------------------
    // layoutToastSeq is already filtered to the focused monitor (shell.qml)

    Connections {
        target: root.screenScope
        function onLayoutToastSeqChanged() {
            var monocle = root.screenScope.layoutToastMode === "monocle"
            root.show("layout", monocle ? "󰊓" : "󰕴", Theme.heading(monocle ? "MONOCLE" : "DWINDLE"), -1, 1100)
        }
    }

    // --- track ----------------------------------------------------------------
    // Title and artist arrive as separate property changes, so a change is
    // settled for a moment before showing -- otherwise the island would show
    // the new title under the old artist first.

    property string lastTrack: ""

    Connections {
        target: Media.player
        function onTrackTitleChanged() { trackSettle.restart() }
        function onTrackArtistChanged() { trackSettle.restart() }
        function onIsPlayingChanged() { trackSettle.restart() }
    }

    Timer {
        id: trackSettle
        interval: 250
        onTriggered: {
            var p = Media.player
            if (!p || !p.isPlaying || !p.trackTitle) return
            var t = (p.trackArtist ? p.trackArtist + " – " : "") + p.trackTitle
            if (t === root.lastTrack) return
            root.lastTrack = t
            root.show("track", "󰝚", t, -1, 3500)
        }
    }

    // --- notifications ----------------------------------------------------------

    property int lastCount: 0

    Connections {
        target: Notifications
        function onCountChanged() {
            var n = Notifications.count
            if (n > root.lastCount && !Notifications.dnd)
                root.show("notify", "󰂚", n === 1 ? "1 notification" : n + " notifications", -1, 3000)
            root.lastCount = n
        }
    }
}
