// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNotifications.qml
//
// The shell's own notifications (services/Notifications.qml): Do Not
// Disturb, the history, and where popups appear and how long they stay.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"
import "../services/TimeWindow.js" as TimeWindow

SettingsPage {
    id: page

    title: "Notifications"
    description: "Do Not Disturb and its quiet hours, the history, and how long popups stay and where they appear."

    component Seconds: SettingsField {
        id: sec
        property string key: ""

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            readonly property int current: Settings[sec.key]
            value: current
            minimum: 0
            maximum: 60
            valueWidth: 64
            displayValue: current === 0 ? "never" : current + " s"
            onStepped: delta => Settings.setNotifTimeout(sec.key, current + delta)
        }
    }

    FlyoutHeading { text: "QUICK ACTIONS" }

    FlyoutAction {
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        label: "Do Not Disturb"
        status: Notifications.dnd ? "Popups are held, except critical ones; all still land in the history" : "Popups show as they arrive"
        checked: Notifications.dnd
        onActivated: Notifications.toggleDnd()
    }

    FlyoutAction {
        icon: "󰎟"
        label: "Clear all"
        status: Notifications.count === 0 ? "The history is empty" : Notifications.count + " in the history"
        checkable: false
        enabled: Notifications.count > 0
        onActivated: Notifications.clearAll()
    }

    FlyoutAction {
        icon: "󰍜"
        label: "Open the history"
        checkable: false
        onActivated: Notifications.togglePanel()
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "QUIET HOURS" }

    component QuietTime: SettingsField {
        id: qt
        property string key: ""
        enabled: Settings.notifQuiet
        opacity: enabled ? 1 : 0.5

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(190)
            // never inert at an end: the time wraps past midnight
            minimum: -1
            maximum: 1440
            value: Settings[qt.key]
            valueWidth: 80
            displayValue: TimeWindow.format(value, Theme.hours("HH:mm"))
            onStepped: delta => Settings.setScheduleTime(qt.key, value + delta * 30)
        }
    }

    FlyoutAction {
        icon: "󰔟"
        label: "Quiet hours"
        status: Settings.notifQuiet
            ? "Do Not Disturb turns itself on and off each day"
            : "Do Not Disturb only when you turn it on"
        checked: Settings.notifQuiet
        onActivated: Settings.setNotifQuiet(!Settings.notifQuiet)
    }

    QuietTime {
        key: "notifQuietFrom"
        label: "Starts"
    }
    QuietTime {
        key: "notifQuietTo"
        label: "Ends"
        hint: "Turning Do Not Disturb off during quiet hours holds until the next day's"
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "POPUPS" }

    SettingsField {
        label: "Position"
        hint: "Where popups appear"

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            FlyoutSegmented {
                fill: false
                model: ["top", "bottom"]
                labelFor: v => v.charAt(0).toUpperCase() + v.slice(1)
                current: Settings.notifPositionY
                onPicked: v => Settings.setNotifPosition(Settings.notifPositionX, v)
            }
            FlyoutSegmented {
                fill: false
                model: ["left", "center", "right"]
                labelFor: v => v.charAt(0).toUpperCase() + v.slice(1)
                current: Settings.notifPositionX
                onPicked: v => Settings.setNotifPosition(v, Settings.notifPositionY)
            }
        }
    }

    SettingsField {
        label: "Group by app"
        hint: Settings.notifGroup ? "Popups from one app stack into one, with a count"
            : "Every notification gets its own popup"

        Switch {
            anchors.right: parent.right
            checked: Settings.notifGroup
            onToggled: Settings.set("notifGroup", !Settings.notifGroup)
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "HOW LONG POPUPS STAY" }

    Seconds {
        key: "notifTimeout"
        label: "Normal"
        hint: "Unless the app asks for a time of its own"
    }
    Seconds {
        key: "notifTimeoutLow"
        label: "Low priority"
    }
    Seconds {
        key: "notifTimeoutCritical"
        label: "Critical"
        hint: "Never means it stays until dismissed"
    }
}
