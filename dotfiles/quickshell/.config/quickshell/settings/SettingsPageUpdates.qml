// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageUpdates.qml
//
// Software updates: how often Updates.qml checks, whether the AUR is part of
// it, and packages to leave alone -- all kept in Settings.qml, so the bar's
// Updates module and flyout follow at once. What's pending and the upgrade
// itself are Updates.qml's, as the flyout uses them; the maintenance rows
// are Health's package checks, with the same repair buttons as System's
// Health page.

import Quickshell
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    title: "Software Update"
    description: "How often the bar checks for new packages, whether the AUR is included, and packages to leave out. Upgrades run yay in a terminal."

    readonly property var intervals: [0, 30, 60, 360, 1440]

    function intervalLabel(m) {
        return m === 0 ? "Manually" : m < 60 ? m + " min" : m === 60 ? "Hourly" : m === 1440 ? "Daily" : (m / 60) + " h"
    }

    // "20:14, 12 min ago", "Tue 22 Sep, 09:03"
    function when(d) {
        if (!d) return "Not yet"
        var mins = Math.round((Date.now() - d.getTime()) / 60000)
        if (mins < 1) return Qt.formatTime(d, Theme.timeFormat) + ", just now"
        if (mins < 60) return Qt.formatTime(d, Theme.timeFormat) + ", " + mins + " min ago"
        if (mins < 1440 && d.getDate() === new Date().getDate()) return "Today, " + Qt.formatTime(d, Theme.timeFormat)
        return Qt.formatDateTime(d, Theme.hours("ddd d MMM, HH:mm"))
    }

    readonly property var maintenance: Health.checks.filter(c => c.id === "orphans" || c.id === "cache")

    function ignore(name) {
        if (Settings.updateIgnore.indexOf(name) >= 0) return
        Settings.setUpdateIgnore(Settings.updateIgnore.concat([name]))
        say("Ignoring " + name, false)
    }
    function unignore(name) {
        Settings.setUpdateIgnore(Settings.updateIgnore.filter(n => n !== name))
        say(name + " is back in updates", false)
    }

    Component.onCompleted: Health.scan()

    // --- layout --------------------------------------------------------------

    FlyoutHeading { text: "CHECKING" }

    Text {
        width: parent.width
        visible: !Updates.available
        wrapMode: Text.WordWrap
        text: "checkupdates isn't installed (pacman-contrib), so nothing is checked."
        color: Theme.alert
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    SettingsField {
        label: "Check for updates"
        hint: "The bar shows a count when there are some"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: page.intervals
            labelFor: v => page.intervalLabel(v)
            current: Settings.updateInterval
            onPicked: v => {
                Settings.setUpdateInterval(v)
                page.say(v === 0 ? "Checks only when asked" : "Checks every " + page.intervalLabel(v).toLowerCase(), false)
            }
        }
    }

    SettingsField {
        label: "Include the AUR"
        hint: "Checked with yay -Qua and upgraded with the rest"

        Switch {
            anchors.right: parent.right
            checked: Settings.updateAur
            onToggled: {
                Settings.setUpdateAur(!Settings.updateAur)
                page.say(Settings.updateAur ? "AUR included" : "Official repositories only", false)
            }
        }
    }

    SettingsField {
        label: "Last checked"
        hint: Updates.checking ? "Checking now…" : ""

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceL

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: page.when(Updates.lastChecked)
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }
            FlyoutChip {
                anchors.verticalCenter: parent.verticalCenter
                text: "Check now"
                enabled: Updates.available && !Updates.checking
                onClicked: Updates.refresh()
            }
        }
    }

    SettingsField {
        label: "Last upgrade"
        hint: "pacman's last full upgrade"

        Text {
            anchors.right: parent.right
            text: page.when(Updates.lastUpgrade)
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "PENDING" }

    SettingsField {
        label: "Pending"
        hint: Updates.count === 0 ? "Everything is up to date"
            : Updates.count + (Updates.count === 1 ? " package" : " packages")
                + (Updates.aurCount > 0 ? ", " + Updates.aurCount + " from the AUR" : "")

        FlyoutChip {
            anchors.right: parent.right
            text: "Update now"
            enabled: Updates.count > 0
            onClicked: Updates.update()
        }
    }

    Repeater {
        model: Updates.packages

        SettingsField {
            required property var modelData
            label: modelData.name + (modelData.aur ? "  ·aur" : "")
            hint: modelData.from + "  →  " + modelData.to

            FlyoutChip {
                anchors.right: parent.right
                text: "Ignore"
                onClicked: page.ignore(modelData.name)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "IGNORED" }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Left out of the count and passed to yay as --ignore. pacman.conf's own IgnorePkg still applies."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        model: Settings.updateIgnore

        SettingsField {
            required property string modelData
            label: modelData

            FlyoutChip {
                anchors.right: parent.right
                text: "Remove"
                onClicked: page.unignore(modelData)
            }
        }
    }

    SettingsField {
        label: "Ignore a package"

        Item {
            anchors.right: parent.right
            width: Theme.fit(240) + Theme.spaceS + addChip.width
            height: Theme.rowHeightTall

            FlyoutInput {
                id: ignoreName
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(240)
                echoPassword: false
                placeholder: "package name"
                onAccepted: addChip.clicked()
            }
            FlyoutChip {
                id: addChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "+ Add"
                enabled: /^[a-z0-9@._+-]+$/i.test(ignoreName.text.trim())
                onClicked: if (enabled) {
                    page.ignore(ignoreName.text.trim())
                    ignoreName.text = ""
                }
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MAINTENANCE" }

    Text {
        width: parent.width
        visible: page.maintenance.length === 0
        text: Health.scanning ? "Looking…" : "pacman isn't available"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        model: page.maintenance

        SettingsField {
            required property var modelData
            label: modelData.label
            hint: modelData.detail

            FlyoutChip {
                anchors.right: parent.right
                visible: !!modelData.repairId
                text: modelData.repairLabel || "Fix"
                enabled: Health.busyRepair === ""
                onClicked: Health.repair(modelData)
            }
        }
    }
}
