// Singularity - Quickshell
// ~/.config/quickshell/flyouts/CalendarFlyout.qml
//
// The clock module's calendar flyout, split out of shell.qml. Needs only
// Theme and Settings -- no bar or root state.
//
// A plain month view: page back and forth, and today is highlighted. Weeks
// start on the day Settings -> Date & Time picks (Settings.weekStart).

import QtQuick
import "../services"

FlyoutPanel {
    id: calendarFlyout
    flyout: "calendar"
    menuWidth: 240

    // offset in months from the current one, so the flyout can page
    // back and forth without tracking a whole date
    property int monthOffset: 0
    // today, taken at each open so a new day or time zone shows
    property date now: new Date()
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)

    // reset to this month every time it opens, so it never comes
    // back up three months deep from last time
    onOpenChanged: if (open) {
        monthOffset = 0
        now = new Date()
    }

    Item {
        width: parent.width
        height: Theme.chipHeight

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "‹"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontLarge
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.spaceM
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarFlyout.monthOffset--
            }
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDateTime(calendarFlyout.shown, "MMMM yyyy").toUpperCase()
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
            font.bold: true
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontLarge
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.spaceM
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarFlyout.monthOffset++
            }
        }
    }

    Grid {
        width: parent.width
        columns: 7
        spacing: 0

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
                required property int index
                width: calendarFlyout.contentColumn.width / 7
                height: Theme.row(22)

                // the 1st's column: JS getDay() is Sunday-first
                readonly property int firstDow:
                    (calendarFlyout.shown.getDay() - Settings.weekStart + 7) % 7
                readonly property int daysInMonth: {
                    var s = calendarFlyout.shown
                    return new Date(s.getFullYear(), s.getMonth() + 1, 0).getDate()
                }
                readonly property int dayNum: index - firstDow + 1
                readonly property bool inMonth: dayNum >= 1 && dayNum <= daysInMonth
                readonly property bool isToday: {
                    if (!inMonth) return false
                    return calendarFlyout.monthOffset === 0
                        && calendarFlyout.now.getDate() === dayNum
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.fs(20)
                    height: Theme.controlSize
                    radius: Theme.radiusSmall
                    color: parent.isToday ? Theme.meterFill : "transparent"

                    visible: parent.inMonth

                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.dayNum
                        color: parent.parent.isToday ? Theme.base : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                        font.bold: parent.parent.isToday
                    }
                }
            }
        }
    }
}
