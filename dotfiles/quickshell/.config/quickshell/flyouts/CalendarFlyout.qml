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

import Quickshell
import QtQuick
import "../services"

FlyoutPanel {
    id: calendarFlyout
    flyout: "calendar"
    menuWidth: 240

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

    // reset to this month every time it opens, so it never comes
    // back up three months deep from last time
    onOpenChanged: if (open) monthOffset = 0

    // wheel anywhere over the box pages; one step per notch, and touchpads
    // accumulate so a flick doesn't fly through a year
    property real wheelAccum: 0
    WheelHandler {
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

    component PageButton: Rectangle {
        id: btn
        property string glyph
        signal clicked()
        width: Theme.controlSize
        height: Theme.controlSize
        radius: Theme.radiusSmall
        color: area.containsMouse ? Theme.hoverFill : "transparent"

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: area.containsMouse ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontLarge
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Item {
        width: parent.width
        height: Theme.chipHeight

        PageButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            glyph: "‹"
            onClicked: calendarFlyout.monthOffset--
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDateTime(calendarFlyout.shown,
                calendarFlyout.shown.getFullYear() === calendarFlyout.now.getFullYear()
                    ? "MMMM" : "MMMM yyyy").toUpperCase()
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            font.bold: true
        }

        PageButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "›"
            onClicked: calendarFlyout.monthOffset++
        }
    }

    Grid {
        id: grid
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
                height: Theme.row(22)

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

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.fs(20)
                    height: Theme.controlSize
                    radius: Theme.radiusSmall
                    color: cell.isToday ? Theme.meterFill
                        : !cell.inMonth && dayArea.containsMouse ? Theme.hoverFill
                        : "transparent"
                    opacity: cell.isToday && !cell.inMonth ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        color: cell.isToday ? Theme.base : cell.inMonth ? Theme.text : Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                        font.bold: cell.isToday
                    }
                }

                // an edge day pages to its own month
                MouseArea {
                    id: dayArea
                    anchors.fill: parent
                    enabled: !cell.inMonth
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calendarFlyout.monthOffset += cell.index < 7 ? -1 : 1
                }
            }
        }
    }

    // today's date; a way back to it while paged away
    Rectangle {
        width: parent.width
        height: Theme.chipHeight
        radius: Theme.radiusSmall
        readonly property bool away: calendarFlyout.monthOffset !== 0
        color: away && todayArea.containsMouse ? Theme.hoverFill : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.away ? "Back to today"
                : Qt.formatDateTime(calendarFlyout.now, "dddd, MMMM d")
            color: parent.away && todayArea.containsMouse ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
        MouseArea {
            id: todayArea
            anchors.fill: parent
            enabled: parent.away
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarFlyout.monthOffset = 0
        }
    }
}
