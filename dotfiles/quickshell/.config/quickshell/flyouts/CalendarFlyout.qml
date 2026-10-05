// Singularity - Quickshell
// ~/.config/quickshell/flyouts/CalendarFlyout.qml
//
// The clock module's calendar flyout, split out of shell.qml. Needs only
// Theme and Settings -- no bar or root state.
//
// A month view: the arrows or the scroll wheel page back and forth, today is
// highlighted, and the days either side of the month fill the grid dimmed
// (clicking one pages to its month). The footer names today's date and,
// while paged away, takes you back to it. Weeks start on the day
// Settings -> Date & Time picks (Settings.weekStart).
//
// Three tabs, one shown at a time: Month, the picked day's events (Today),
// and the timer the clock island shows (services/Timers.qml). With feeds in
// calendars.conf (services/Calendar.qml), days with events carry a dot, and
// picking one in the month opens its events; without feeds there's no
// events tab.

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: calendarFlyout
    flyout: "calendar"
    menuWidth: Calendar.configured ? 280 : 240

    // offset in months from the current one, so the flyout can page
    // back and forth without tracking a whole date
    property int monthOffset: 0

    // today, kept current while open so midnight moves the highlight
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: calendarFlyout.open
    }
    readonly property date now: clock.date
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)

    // the day whose events are listed; null is today
    property var picked: null
    readonly property date selected: picked || now
    function sameDay(a, b) {
        return a.getDate() === b.getDate() && a.getMonth() === b.getMonth()
            && a.getFullYear() === b.getFullYear()
    }

    // "month", "today" or "timer"
    property string tab: "today"
    readonly property string firstTab: Calendar.configured ? "today" : "month"

    // reset to this month, today and the first tab every time it opens, so
    // it never comes back up three months deep from last time
    onOpenChanged: if (open) { monthOffset = 0; picked = null; tab = firstTab }

    // wheel anywhere over the box pages; one step per notch, and touchpads
    // accumulate so a flick doesn't fly through a year
    property real wheelAccum: 0
    FlyoutSegmented {
        model: (Calendar.configured ? [
            { value: "month", text: "Month" },
            { value: "today", text: calendarFlyout.picked === null ? "Today" : "Day" },
        ] : [{ value: "month", text: "Month" }]).concat([
            { value: "timer", text: Timers.active ? "Timer ●" : "Timer" },
        ])
        current: calendarFlyout.tab
        onPicked: v => calendarFlyout.tab = v
    }

    FlyoutDivider {}

    // --- month ----------------------------------------------------------------

    WheelHandler {
        enabled: calendarFlyout.tab === "month"
        parent: calendarFlyout.contentColumn
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            calendarFlyout.wheelAccum += event.angleDelta.y
            while (Math.abs(calendarFlyout.wheelAccum) >= 120) {
                calendarFlyout.monthOffset += calendarFlyout.wheelAccum > 0 ? -1 : 1
                calendarFlyout.wheelAccum -= calendarFlyout.wheelAccum > 0 ? 120 : -120
            }
        }
    }

    Item {
        visible: calendarFlyout.tab === "month"
        width: parent.width
        height: Theme.chipHeight

        IconButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰅁"
            onClicked: calendarFlyout.monthOffset--
        }

        Text {
            anchors.centerIn: parent
            text: Theme.heading(Qt.formatDateTime(calendarFlyout.shown,
                calendarFlyout.shown.getFullYear() === calendarFlyout.now.getFullYear()
                    ? "MMMM" : "MMMM yyyy"))
            color: Theme.headingColor
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            font.weight: Theme.headingBold ? Theme.weightStrong : Theme.weightBody
            font.letterSpacing: Theme.headingSpacing
        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰅂"
            onClicked: calendarFlyout.monthOffset++
        }
    }

    Grid {
        id: grid
        visible: calendarFlyout.tab === "month"
        width: parent.width
        columns: 7
        spacing: 0

        // the 1st's column: JS getDay() is Sunday-first
        readonly property int firstDow:
            (calendarFlyout.shown.getDay() - Settings.weekStart + 7) % 7

        Repeater {
            // Sunday-first, rotated to the chosen first day
            model: {
                var d = ["S", "M", "T", "W", "T", "F", "S"]
                return d.slice(Settings.weekStart).concat(d.slice(0, Settings.weekStart))
            }

            Text {
                required property var modelData
                width: calendarFlyout.contentColumn.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.muted
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        Repeater {
            // 42 cells = 6 weeks, enough for any month/start-day
            // combination, so the grid never reflows height
            model: 42

            Item {
                id: cell
                required property int index
                width: calendarFlyout.contentColumn.width / 7
                height: Theme.rowHeightDense

                // the Date constructor rolls day 0 and day 32 over into the
                // neighbouring months, which is what fills the edges
                readonly property date day: {
                    var s = calendarFlyout.shown
                    return new Date(s.getFullYear(), s.getMonth(), index - grid.firstDow + 1)
                }
                readonly property bool inMonth: day.getMonth() === calendarFlyout.shown.getMonth()
                readonly property bool isToday: {
                    var n = calendarFlyout.now
                    return day.getDate() === n.getDate() && day.getMonth() === n.getMonth()
                        && day.getFullYear() === n.getFullYear()
                }

                readonly property bool isPicked: calendarFlyout.picked !== null
                    && calendarFlyout.sameDay(day, calendarFlyout.picked)
                readonly property bool busy: Calendar.busyDays[Calendar.dayKey(day)] === true

                Rectangle {
                    id: dayBox
                    anchors.centerIn: parent
                    width: Theme.fs(20)
                    height: Theme.controlSize
                    radius: Theme.radiusSmall
                    color: cell.isToday ? Theme.meterFill
                        : dayArea.containsMouse ? Theme.hoverFill
                        : "transparent"
                    border.width: cell.isPicked && !cell.isToday ? Theme.borderWidth : 0
                    border.color: Theme.strokeHover
                    opacity: cell.isToday && !cell.inMonth ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        color: cell.isToday ? Theme.textOnMeter : cell.inMonth ? Theme.text : Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                        font.weight: cell.isToday ? Theme.weightStrong : Theme.weightBody
                    }
                }

                // a day with events under it
                Rectangle {
                    visible: cell.busy
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: dayBox.bottom
                    anchors.topMargin: 1
                    width: 4
                    height: 4
                    radius: 2
                    color: cell.isToday || cell.isPicked ? Theme.accent : Theme.subtext
                    opacity: cell.inMonth ? 1 : 0.5
                }

                // picks the day for the list below (with calendars set up);
                // an edge day also pages to its own month
                MouseArea {
                    id: dayArea
                    anchors.fill: parent
                    enabled: !cell.inMonth || Calendar.configured
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!cell.inMonth) calendarFlyout.monthOffset += cell.index < 7 ? -1 : 1
                        if (!Calendar.configured) return
                        calendarFlyout.picked = calendarFlyout.sameDay(cell.day, calendarFlyout.now) ? null : cell.day
                        if (cell.inMonth) calendarFlyout.tab = "today"
                    }
                }
            }
        }
    }

    // today's date; a way back to it while paged away or on another day
    Rectangle {
        visible: calendarFlyout.tab === "month"
        width: parent.width
        height: Theme.chipHeight
        radius: Theme.radiusSmall
        readonly property bool away: calendarFlyout.monthOffset !== 0 || calendarFlyout.picked !== null
        color: away && todayArea.containsMouse ? Theme.hoverFill : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.away ? "Back to today"
                : Qt.formatDateTime(calendarFlyout.now, "dddd, MMMM d")
            color: parent.away && todayArea.containsMouse ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        MouseArea {
            id: todayArea
            anchors.fill: parent
            enabled: parent.away
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { calendarFlyout.monthOffset = 0; calendarFlyout.picked = null }
        }
    }

    // --- events ---------------------------------------------------------------

    readonly property var dayEvents: Calendar.configured && open ? Calendar.eventsOn(selected) : []
    readonly property int maxEvents: 8

    FlyoutHeading {
        visible: Calendar.configured && calendarFlyout.tab === "today"
        text: calendarFlyout.sameDay(calendarFlyout.selected, calendarFlyout.now) ? "TODAY"
            : Theme.heading(Qt.formatDateTime(calendarFlyout.selected, "ddd d MMMM"))
    }

    FlyoutRow {
        visible: Calendar.configured && calendarFlyout.tab === "today" && calendarFlyout.dayEvents.length === 0
        enabled: false
        label: Calendar.events.length === 0 && Calendar.refreshing ? "Loading events…" : "No events"
    }

    Repeater {
        model: calendarFlyout.tab === "today" ? calendarFlyout.dayEvents.slice(0, calendarFlyout.maxEvents) : []

        Item {
            id: ev
            required property var modelData
            readonly property bool past: !modelData.allDay && modelData.end < calendarFlyout.now
            width: parent.width
            height: Math.max(Theme.rowHeight, evText.implicitHeight + Theme.spaceS)
            opacity: past ? 0.5 : 1

            // "All day", or the start (and the end on the day it began)
            Text {
                id: evTime
                width: Theme.fs(90)
                anchors.top: parent.top
                anchors.topMargin: (Theme.rowHeight - height) / 2
                text: {
                    var e = ev.modelData
                    if (e.allDay) return "All day"
                    var f = Theme.hours("HH:mm")
                    var t = Qt.formatDateTime(e.start, f)
                    if (e.end > e.start && calendarFlyout.sameDay(e.start, e.end))
                        t += "–" + Qt.formatDateTime(e.end, f)
                    return t
                }
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }

            Column {
                id: evText
                anchors.left: evTime.right
                anchors.leftMargin: Theme.spaceS
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: (Theme.rowHeight - titleText.implicitHeight) / 2

                Text {
                    id: titleText
                    width: parent.width
                    text: ev.modelData.title
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    visible: text !== ""
                    width: parent.width
                    text: ev.modelData.location
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }

    FlyoutRow {
        visible: calendarFlyout.tab === "today" && calendarFlyout.dayEvents.length > calendarFlyout.maxEvents
        enabled: false
        label: "+" + (calendarFlyout.dayEvents.length - calendarFlyout.maxEvents) + " more"
    }

    FlyoutDivider { visible: Calendar.configured && calendarFlyout.tab === "today" }

    // as the weather flyout's: when the feeds last came in, and a way to
    // ask again; failed, the list is the last good copy
    FlyoutRow {
        visible: Calendar.configured && calendarFlyout.tab === "today"
        label: Calendar.refreshing ? "Refreshing…"
            : Calendar.offline ? "Update failed, try again" : "Refresh events"
        trailing: Calendar.fetched ? Qt.formatDateTime(Calendar.fetched,
            calendarFlyout.sameDay(Calendar.fetched, calendarFlyout.now) ? Theme.timeFormat : "MMM d") : ""
        busy: Calendar.refreshing
        alert: Calendar.offline && !Calendar.refreshing
        onActivated: Calendar.refresh(false)
    }

    // --- timer ----------------------------------------------------------------

    property int timerMinutes: 10
    readonly property bool onTimer: tab === "timer"

    // the time left (or gone, for the stopwatch), large
    Column {
        visible: calendarFlyout.onTimer
        width: parent.width

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Timers.active ? Timers.text : calendarFlyout.timerMinutes + ":00"
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontHero
            font.letterSpacing: 1
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Timers.active ? Timers.title + (Timers.paused ? " · paused" : "")
                : "Countdown · " + calendarFlyout.timerMinutes + " min"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    FlyoutDivider { visible: calendarFlyout.onTimer }

    // idle: a countdown of the stepped length, or one of the other two
    FlyoutStepper {
        visible: calendarFlyout.onTimer && !Timers.active
        label: "Countdown"
        minimum: 1
        maximum: 180
        valueWidth: 64
        value: calendarFlyout.timerMinutes
        displayValue: value + " min"
        onStepped: d => {
            var v = calendarFlyout.timerMinutes
            var step = v + d * (v >= 30 && !(d < 0 && v === 30) ? 5 : 1)
            calendarFlyout.timerMinutes = Math.max(minimum, Math.min(maximum, step))
        }
    }

    Row {
        visible: calendarFlyout.onTimer && !Timers.active
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL
        FlyoutChip { text: "Start"; onClicked: Timers.countdown(calendarFlyout.timerMinutes) }
        FlyoutChip { text: "Pomodoro"; onClicked: Timers.pomodoro() }
        FlyoutChip { text: "Stopwatch"; onClicked: Timers.stopwatch() }
    }

    // running: what can be done to it
    Row {
        visible: calendarFlyout.onTimer && Timers.active
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceL
        FlyoutChip { text: Timers.paused ? "Resume" : "Pause"; onClicked: Timers.togglePause() }
        FlyoutChip { visible: Timers.mode === "countdown"; text: "+1 min"; onClicked: Timers.addMinutes(1) }
        FlyoutChip { visible: Timers.mode === "pomodoro"; text: "Skip"; onClicked: Timers.skip() }
        FlyoutChip { text: "Stop"; confirmText: "Stop?"; onClicked: Timers.stop() }
    }
}
