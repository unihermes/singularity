// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNotifications.qml
//
// The shell's own notifications (services/Notifications.qml): Do Not
// Disturb, the history, and where popups appear and how long they stay.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Notifications"
    description: "Do Not Disturb, the history, and how long popups stay and where they appear."

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
        status: Notifications.dnd ? "Popups are held; they still land in the history" : "Popups show as they arrive"
        checked: Notifications.dnd
        onActivated: Notifications.toggleDnd()
    }

    FlyoutAction {
        icon: "󰎟"
        label: "Clear all"
        status: Notifications.count === 0 ? "Nothing waiting" : Notifications.count + " waiting"
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
