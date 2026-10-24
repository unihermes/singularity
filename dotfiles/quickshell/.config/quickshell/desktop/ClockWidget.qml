// Singularity - Quickshell
// ~/.config/quickshell/desktop/ClockWidget.qml
//
// The day in the accent over the time, its seconds small beside it.
// Small adds the date; medium the month and ISO week, and this week as a
// strip with today lit; large the whole month.

import Quickshell
import QtQuick
import "../services"

WidgetCard {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    readonly property date now: clock.date
    // today, which changes once a day: the week and month hang off it, so
    // their cells aren't rebuilt each second
    readonly property string dayKey: Qt.formatDate(now, "yyyy-MM-dd")
    readonly property date today: new Date(dayKey + "T00:00:00")

    // ISO 8601: the week holding the year's first Thursday is week 1
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        const start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - start) / 86400000 + 1) / 7)
    }

    // the dates from the first day of the week (Settings.weekStart) that
    // holds `d`, `count` of them
    function daysFrom(d, count) {
        const first = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        first.setDate(first.getDate() - (first.getDay() - Settings.weekStart + 7) % 7)
        const out = []
        for (let i = 0; i < count; i++) {
            const x = new Date(first)
            x.setDate(first.getDate() + i)
            out.push(x)
        }
        return out
    }

    // the month's weeks, as whole weeks
    readonly property var monthDays: {
        const first = new Date(today.getFullYear(), today.getMonth(), 1)
        const last = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
        const lead = (first.getDay() - Settings.weekStart + 7) % 7
        return daysFrom(first, Math.ceil((lead + last) / 7) * 7)
    }

    readonly property var weekDays: daysFrom(today, 7)

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    Item {
        id: top
        width: parent.width
        height: day.height

        WidgetCaption {
            id: day
            card: root
            text: Qt.formatDate(root.today, "dddd")
        }
        WidgetText {
            visible: !root.small
            anchors.right: parent.right
            card: root
            px: root.textCaption
            text: Qt.formatDate(root.today, "MMMM") + " · Week " + root.isoWeek(root.today)
            color: root.fgDim
        }
    }

    WidgetText {
        id: time
        anchors.top: top.bottom
        anchors.topMargin: -Math.round(font.pixelSize * 0.08)
        card: root
        px: root.large ? Theme.fit(96) : root.small ? Theme.fit(38) : Theme.fit(60)
        text: Qt.formatTime(root.now, Theme.timeFormat)
    }
    WidgetText {
        anchors.left: time.right
        anchors.leftMargin: Theme.fit(4)
        anchors.baseline: time.baseline
        card: root
        px: Math.round(time.font.pixelSize * 0.4)
        text: Qt.formatTime(root.now, "ss")
        color: root.fgDim
    }

    WidgetText {
        visible: root.small
        anchors.bottom: parent.bottom
        card: root
        text: Qt.formatDate(root.today, "d MMMM")
        color: root.fgDim
    }

    // this week (medium) or the month (large): the day letters, then dates
    Grid {
        visible: !root.small
        anchors.bottom: parent.bottom
        width: parent.width
        columns: 7
        readonly property real cell: width / 7

        Repeater {
            model: root.small ? [] : root.weekDays
            WidgetText {
                required property var modelData
                width: parent.cell
                horizontalAlignment: Text.AlignHCenter
                card: root
                px: root.textCaption
                text: Qt.formatDate(modelData, "ddd").charAt(0)
                color: root.fgFaint
                font.weight: root.weightStrong
            }
        }

        Repeater {
            model: root.large ? root.monthDays : root.small ? [] : root.weekDays
            Item {
                required property var modelData
                readonly property bool today: root.sameDay(modelData, root.today)
                width: parent.cell
                height: Theme.fit(root.large ? 30 : 26)

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    visible: parent.today
                }
                WidgetText {
                    anchors.centerIn: parent
                    card: root
                    px: root.textCaption
                    text: modelData.getDate()
                    color: parent.today ? Theme.textOnAccent
                        : modelData.getMonth() === root.today.getMonth() ? root.fg : root.fgFaint
                    font.weight: parent.today ? root.weightStrong : root.weightBody
                }
            }
        }
    }
}
