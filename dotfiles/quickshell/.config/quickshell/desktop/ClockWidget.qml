// Singularity - Quickshell
// ~/.config/quickshell/desktop/ClockWidget.qml
//
// The day as the heading, the time large with its seconds small beside it,
// then the date and the ISO week.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

WidgetFrame {
    id: root
    menuWidth: 260

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ISO 8601: the week holding the year's first Thursday is week 1
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        const start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - start) / 86400000 + 1) / 7)
    }

    FlyoutHeading { text: Qt.formatDate(clock.date, "dddd").toUpperCase() }

    Row {
        spacing: Theme.spaceS

        Text {
            id: time
            text: Qt.formatTime(clock.date, Theme.timeFormat)
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fs(64)
        }
        Text {
            anchors.baseline: time.baseline
            text: Qt.formatTime(clock.date, "ss")
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fs(22)
        }
    }

    Item {
        width: parent.width
        height: date.implicitHeight

        Text {
            id: date
            text: Qt.formatDate(clock.date, "d MMMM yyyy")
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            text: "Week " + root.isoWeek(clock.date)
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }
}
