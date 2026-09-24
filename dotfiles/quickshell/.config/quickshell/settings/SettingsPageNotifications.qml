// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNotifications.qml
//
// swaync: Do Not Disturb and the queue, through the Notifications singleton
// the bar module already uses, and a few of config.json's top-level options.
//
// Config edits replace the value on that key's own line and nothing else, so
// the file keeps its layout -- a JSON round trip would reflow every inline
// object in it. `swaync-client -R` then reloads the config in place.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Notifications"
    description: "Do Not Disturb, and how long popups stay and where they appear. Saved to swaync's config.json, which reloads in place."

    readonly property string confPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/swaync/config.json"

    property var conf: ({})

    function reread() {
        confFile.reload()
        confFile.waitForJob()
        try { conf = JSON.parse(confFile.text()) }
        catch (e) { conf = {}; say("Couldn't parse " + confPath, true) }
    }

    Component.onCompleted: reread()

    // "key": value on a line of its own. Only top-level keys are set here,
    // and none of them share a name with a nested one.
    function setKey(key, value, message) {
        var re = new RegExp('^(\\s*"' + key + '"\\s*:\\s*)("[^"]*"|-?[0-9.]+|true|false)', "m")
        var json = JSON.stringify(value)
        AtomicFileWrite.write({
            path: confPath,
            transform: text => {
                var next
                if (re.test(text)) {
                    next = text.replace(re, (m, head) => head + json)
                } else {
                    // not set yet: add it after the opening brace
                    next = text.replace(/^\{\s*\n/, m => m + '  "' + key + '": ' + json + ",\n")
                }
                try { JSON.parse(next) } catch (e) { return null }
                return next
            },
            refusal: "Not written, the edit would break config.json",
            after: "swaync-client -R -sw >/dev/null",
            done: (status, detail) => {
                if (status === "ok" || status === "unchanged") page.say(message, false)
                else page.say(status === "refused" ? detail : "Couldn't write config.json", true)
                page.reread()
            }
        })
    }

    FileView {
        id: confFile
        path: page.confPath
        blockLoading: true
        printErrors: false
    }

    component Seconds: SettingsField {
        id: sec
        property string key: ""
        property int fallback: 0

        FlyoutStepper {
            anchors.right: parent.right
            width: Theme.fit(170)
            readonly property int current: page.conf[sec.key] !== undefined ? Number(page.conf[sec.key]) : sec.fallback
            value: current
            minimum: 0
            maximum: 60
            valueWidth: 64
            displayValue: current === 0 ? "never" : current + " s"
            onStepped: delta => page.setKey(sec.key, Math.max(0, Math.min(60, current + delta)),
                sec.label + ": " + (current + delta === 0 ? "never" : (current + delta) + " s"))
        }
    }

    FlyoutHeading { text: "QUICK ACTIONS" }

    FlyoutAction {
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        label: "Do Not Disturb"
        status: !Notifications.available ? "swaync isn't running"
            : Notifications.dnd ? "Popups are held; they still land in the panel" : "Popups show as they arrive"
        checked: Notifications.dnd
        enabled: Notifications.available
        onActivated: Notifications.toggleDnd()
    }

    FlyoutAction {
        icon: "󰎟"
        label: "Clear all"
        status: Notifications.count === 0 ? "Nothing waiting" : Notifications.count + " waiting"
        checkable: false
        enabled: Notifications.available && Notifications.count > 0
        onActivated: Quickshell.execDetached(["swaync-client", "-C", "-sw"])
    }

    FlyoutAction {
        icon: "󰍜"
        label: "Open the panel"
        checkable: false
        enabled: Notifications.available
        onActivated: Notifications.togglePanel()
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "POPUPS" }

    SettingsField {
        label: "Position"
        hint: "Where popups and the panel appear"

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            FlyoutSegmented {
                fill: false
                model: ["top", "bottom"]
                labelFor: v => v.charAt(0).toUpperCase() + v.slice(1)
                current: page.conf.positionY
                onPicked: v => page.setKey("positionY", v, "Popups: " + v)
            }
            FlyoutSegmented {
                fill: false
                model: ["left", "center", "right"]
                labelFor: v => v.charAt(0).toUpperCase() + v.slice(1)
                current: page.conf.positionX
                onPicked: v => page.setKey("positionX", v, "Popups: " + v)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "HOW LONG POPUPS STAY" }

    Seconds {
        key: "timeout"
        label: "Normal"
        fallback: 10
    }
    Seconds {
        key: "timeout-low"
        label: "Low priority"
        fallback: 5
    }
    Seconds {
        key: "timeout-critical"
        label: "Critical"
        hint: "Never means it stays until dismissed"
        fallback: 0
    }
}
