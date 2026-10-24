// Singularity - Quickshell
// ~/.config/quickshell/desktop/ClockWidget.qml
//
// The day in the accent over the time. Small adds the date; medium the
// month and ISO week, and this week as a strip with today lit; large the
// whole month.

import Quickshell
import QtQuick
import "../services"

GlassCard {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property date now: clock.date

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
        const first = new Date(now.getFullYear(), now.getMonth(), 1)
        const last = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
        const lead = (first.getDay() - Settings.weekStart + 7) % 7
        return daysFrom(first, Math.ceil((lead + last) / 7) * 7)
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }

    Item {
        id: top
        width: parent.width
        height: day.height

        GlassText {
            id: day
            card: root
            px: Theme.fit(13)
            text: Qt.formatDate(root.now, "dddd").toUpperCase()
            color: root.accent
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        GlassText {
            visible: !root.small
            anchors.right: parent.right
            card: root
            px: Theme.fit(13)
            text: Qt.formatDate(root.now, "MMMM") + " · Week " + root.isoWeek(root.now)
            color: root.fgDim
        }
    }

    GlassText {
        id: time
        anchors.top: top.bottom
        anchors.topMargin: -Math.round(font.pixelSize * 0.08)
        card: root
        px: root.large ? Theme.fit(96) : root.small ? Theme.fit(46) : Theme.fit(60)
        text: Qt.formatTime(root.now, Theme.timeFormat)
        font.weight: Font.DemiBold
    }

    GlassText {
        visible: root.small
        anchors.bottom: parent.bottom
        card: root
        px: Theme.fit(14)
        text: Qt.formatDate(root.now, "d MMMM")
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
            model: root.small ? [] : root.daysFrom(root.now, 7)
            GlassText {
                required property var modelData
                width: parent.cell
                horizontalAlignment: Text.AlignHCenter
                card: root
                px: Theme.fit(11)
                text: Qt.formatDate(modelData, "ddd").charAt(0)
                color: root.fgFaint
                font.weight: Font.Bold
            }
        }

        Repeater {
            model: root.large ? root.monthDays : root.small ? [] : root.daysFrom(root.now, 7)
            Item {
                required property var modelData
                readonly property bool today: root.sameDay(modelData, root.now)
                width: parent.cell
                height: Theme.fit(root.large ? 30 : 26)

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    color: root.accent
                    visible: parent.today
                }
                GlassText {
                    anchors.centerIn: parent
                    card: root
                    px: Theme.fit(13)
                    text: modelData.getDate()
                    color: parent.today ? Theme.textOnAccent
                        : modelData.getMonth() === root.now.getMonth() ? root.fg : root.fgFaint
                    font.weight: parent.today ? Font.Bold : Font.Medium
                }
            }
        }
    }
}
