// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNotifications.qml
//
// The shell's own notifications (services/Notifications.qml): STATUS
// (whether popups show, the history, quiet hours), POPUPS (where, grouping,
// how long they stay) and APPS, each with its own popups switch.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"
import "../services/TimeWindow.js" as TimeWindow

SettingsPage {
    id: page

    sectioned: true

    title: "Notifications"
    description: "When popups show, where, and for how long."

    // minutes since midnight, moved on each minute for the day strip
    property int nowMin: minutes(new Date())
    function minutes(d) { return d.getHours() * 60 + d.getMinutes() }
    Timer {
        interval: 30000
        repeat: true
        running: Settings.notifQuiet
        onTriggered: page.nowMin = page.minutes(new Date())
    }

    function hm(m) { return TimeWindow.format(m, Theme.hours("HH:mm")) }
    // "9 h", "8 h 30 min": how long from a to b, past midnight if need be
    function span(a, b) {
        var d = ((b - a) % 1440 + 1440) % 1440
        return Math.floor(d / 60) + " h" + (d % 60 ? " " + d % 60 + " min" : "")
    }
    readonly property bool inQuiet: Settings.notifQuiet
        && TimeWindow.contains(Settings.notifQuietFrom, Settings.notifQuietTo, new Date(0, 0, 0, 0, nowMin))

    // [{ app, count, icon }]: every app in the history, most first, then
    // any silenced app with nothing in it. `app` is the name as sent, "" for
    // an app that gives none, since that's what silencing is matched on.
    readonly property var apps: {
        var by = {}, order = []
        Notifications.history.forEach(e => {
            var a = e.appName || ""
            if (!by[a]) { by[a] = { app: a, count: 0, icon: e.icon || "" }; order.push(a) }
            by[a].count++
            if (!by[a].icon && e.icon) by[a].icon = e.icon
        })
        var list = order.map(a => by[a]).sort((x, y) => y.count - x.count)
        Settings.notifSilent.forEach(a => { if (!by[a]) list.push({ app: a, count: 0, icon: "" }) })
        return list
    }

    // A sample popup, where and as they'll appear. Transient, so it isn't
    // kept in the history.
    Process {
        id: testProc
        command: ["notify-send", "--transient", "-a", "Singularity", "-i", "preferences-desktop-notification",
            "A test notification", "Popups show here, for " + (Settings.notifTimeout > 0 ? Settings.notifTimeout + " seconds" : "as long as you leave them")]
    }

    // --- status ------------------------------------------------------------

    FlyoutHeading { text: "STATUS" }

    // whether popups show, and why: the bell, the state, the switch
    HeadCard {
        glyph: Notifications.dnd ? "󰂛" : "󰂚"
        glyphColor: Notifications.dnd ? Theme.muted : Theme.textStrong
        title: Notifications.dnd ? "Do Not Disturb" : "Notifications on"
        lines: [[!Notifications.dnd ? "Popups show as they arrive"
                  : Settings.notifDndBySchedule ? "Quiet hours, until " + page.hm(Settings.notifQuietTo)
                  : "Popups held, except critical ones",
                 Notifications.count === 0 ? "the history is empty"
                  : Notifications.count + " in the history"
                  + (Notifications.unread > 0 ? ", " + Notifications.unread + " unread" : "")
                ].join("  ·  ")]
        rule: true

        Switch {
            checked: Notifications.dnd
            onToggled: Notifications.toggleDnd()
        }
    }

    SettingsField {
        label: "History"
        hint: "The last " + Notifications.maxEntries + " are kept"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            FlyoutChip {
                text: "Open"
                onClicked: Notifications.togglePanel()
            }
            FlyoutChip {
                text: "Clear all"
                confirmText: "Clear " + Notifications.count + "?"
                enabled: Notifications.count > 0
                onClicked: Notifications.clearAll()
            }
        }
    }

    SettingsField {
        label: "Quiet hours"
        hint: Settings.notifQuiet
            ? "Every day, " + page.hm(Settings.notifQuietFrom) + " to " + page.hm(Settings.notifQuietTo)
                + " (" + page.span(Settings.notifQuietFrom, Settings.notifQuietTo) + ")"
            : "Do Not Disturb on a daily window"

        Switch {
            anchors.right: parent.right
            checked: Settings.notifQuiet
            onToggled: Settings.setNotifQuiet(!Settings.notifQuiet)
        }
    }

    // The day, midnight to midnight: the quiet window filled (in two parts
    // when it runs past midnight) and a marker at now.
    Item {
        id: day
        visible: Settings.notifQuiet
        width: parent.width
        implicitHeight: track.height + tickRow.height + Theme.spaceS * 3

        readonly property int from: Settings.notifQuietFrom
        readonly property int to: Settings.notifQuietTo
        readonly property var bands: from <= to ? [[from, to]] : [[from, 1440], [0, to]]

        Rectangle {
            id: track
            y: Theme.spaceS
            width: parent.width
            height: Theme.fit(16)
            radius: Theme.radiusSmall
            color: Theme.channelGroove
            border.width: Theme.borderWidth
            border.color: Theme.frameStroke

            Item {
                id: inner
                anchors.fill: parent
                anchors.margins: Theme.borderWidth + Theme.channelGrooveWidth

                Repeater {
                    model: day.bands
                    Rectangle {
                        required property var modelData
                        x: inner.width * modelData[0] / 1440
                        width: inner.width * (modelData[1] - modelData[0]) / 1440
                        height: inner.height
                        radius: Math.max(0, track.radius - 3)
                        color: Theme.accent
                    }
                }
            }
        }

        // now
        Rectangle {
            x: inner.x + inner.width * page.nowMin / 1440 - width / 2
            y: track.y - Theme.spaceXs
            width: Math.max(2, Theme.borderWidth * 2)
            height: track.height + Theme.spaceXs * 2
            color: Theme.textStrong
        }

        Item {
            id: tickRow
            anchors.top: track.bottom
            anchors.topMargin: Theme.spaceS
            width: parent.width
            height: Theme.fontCaption * 1.4

            Repeater {
                model: [0, 6, 12, 18, 24]
                Text {
                    required property int modelData
                    x: Math.max(0, Math.min(tickRow.width - implicitWidth,
                        inner.x + inner.width * modelData / 24 - implicitWidth / 2))
                    text: (modelData < 10 ? "0" : "") + modelData
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }

    component QuietTime: SettingsField {
        id: qt
        property string key: ""
        visible: Settings.notifQuiet

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(190)
            // never inert at an end: the time wraps past midnight
            minimum: -1
            maximum: 1440
            value: Settings[qt.key]
            valueWidth: 80
            displayValue: page.hm(value)
            onStepped: delta => Settings.setScheduleTime(qt.key, value + delta * 30)
        }
    }

    // a row of two, and each one's half
    Grid {
        id: quietTimes
        visible: Settings.notifQuiet
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2
        readonly property real half: (width - columnSpacing) / 2

        QuietTime {
            width: quietTimes.half
            labelWidth: width - Theme.fit(190) - Theme.spaceL
            key: "notifQuietFrom"
            label: "Starts"
            hint: page.inQuiet ? "In quiet hours now" : ""
        }
        QuietTime {
            width: quietTimes.half
            labelWidth: width - Theme.fit(190) - Theme.spaceL
            key: "notifQuietTo"
            label: "Ends"
        }
    }

    // --- popups --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "POPUPS" }

    // the spot picker beside where it is, grouping and a test
    Row {
        width: parent.width
        spacing: Theme.spaceXl

        PopupSpot {
            id: spot
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fit(180)
            height: Math.round(width * 10 / 16)
            onPicked: (x, y) => Settings.setNotifPosition(x, y)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - spot.width - parent.spacing
            spacing: Theme.spaceM

            SettingsField {
                width: parent.width
                labelWidth: width - testChip.width - Theme.spaceL
                label: "Position"
                hint: ({ top: "Top", bottom: "Bottom" })[Settings.notifPositionY] + " "
                    + ({ left: "left", center: "centre", right: "right" })[Settings.notifPositionX]

                FlyoutChip {
                    id: testChip
                    anchors.right: parent.right
                    text: "Send a test"
                    onClicked: {
                        testProc.running = true
                        if (Notifications.dnd) page.say("Do Not Disturb is on, so the test is held", false)
                    }
                }
            }

            SettingsField {
                width: parent.width
                labelWidth: width - Theme.switchWidth - Theme.spaceL
                label: "Group by app"
                hint: Settings.notifGroup ? "Stacks, with a count" : "A popup each"

                Switch {
                    anchors.right: parent.right
                    checked: Settings.notifGroup
                    onToggled: Settings.set("notifGroup", !Settings.notifGroup)
                }
            }
        }
    }

    SettingsSubhead { caption: "HOW LONG THEY STAY" }

    // 4 s · 8 s · 16 s · 30 s · Never, and a value set by hand as its own
    component Seconds: SettingsField {
        id: sec
        property string key: ""
        readonly property int current: Settings[key]
        width: durations.third
        labelWidth: width - secPick.width - Theme.spaceL

        SettingsDropdown {
            id: secPick
            anchors.right: parent.right
            width: Theme.fit(110)
            model: {
                var v = [4, 8, 16, 30]
                if (sec.current > 0 && v.indexOf(sec.current) < 0) v = v.concat([sec.current]).sort((a, b) => a - b)
                return v.concat([0])
            }
            labelFor: v => v === 0 ? "Never" : v + " s"
            current: sec.current
            onPicked: v => Settings.setNotifTimeout(sec.key, v)
        }
    }

    Grid {
        id: durations
        width: parent.width
        columns: 3
        columnSpacing: Theme.spaceXl
        readonly property real third: (width - columnSpacing * 2) / 3

        Seconds { key: "notifTimeout"; label: "Normal" }
        Seconds { key: "notifTimeoutLow"; label: "Low" }
        Seconds { key: "notifTimeoutCritical"; label: "Critical" }
    }

    // --- apps ------------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "APPS" + (page.apps.length > 0 ? "  " + page.apps.length : "") }

    // each app with its popups switch
    Repeater {
        model: page.apps

        SettingsField {
            id: appRow
            required property var modelData
            readonly property string app: modelData.app
            readonly property bool silent: Settings.notifSilent.indexOf(app) >= 0

            image: modelData.icon
            mark: modelData.icon === "" ? "󰂚" : ""
            label: app !== "" ? app : "Unknown"
            hint: silent ? "Silent: straight to the history"
                : modelData.count > 0 ? modelData.count + " in the history" : "None in the history"

            Switch {
                anchors.right: parent.right
                checked: !appRow.silent
                onToggled: Settings.setNotifSilent(appRow.app, !appRow.silent)
            }
        }
    }

    FlyoutRow {
        visible: page.apps.length === 0
        enabled: false
        label: "Apps show here once they notify"
    }
}
