// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageUpdates.qml
//
// Software updates: how often Updates.qml checks, whether the AUR is part of
// it, and packages to leave alone -- all kept in Settings.qml, so the bar's
// Updates module and flyout follow at once. What's pending and the upgrade
// itself are Updates.qml's, as the flyout uses them; the upkeep rows are
// Health's package checks, with the same repair buttons as System's Health
// page.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Software Update"
    description: "How often to check, the AUR, and packages to leave out."

    readonly property var intervals: [0, 30, 60, 360, 1440]

    function intervalLabel(m) {
        return m === 0 ? "Manually" : m < 60 ? m + " min" : m === 60 ? "Hourly" : m === 1440 ? "Daily" : (m / 60) + " h"
    }

    // "01:17, 12 min ago", "Yesterday, 19:36", "Tue 22 Sep, 09:03"
    function when(d) {
        if (!d) return "Not yet"
        var mins = Math.round((clock.date.getTime() - d.getTime()) / 60000)
        if (mins < 1) return Qt.formatTime(d, Theme.timeFormat) + ", just now"
        if (mins < 60) return Qt.formatTime(d, Theme.timeFormat) + ", " + mins + " min ago"
        var day = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
        if (d >= day) return "Today, " + Qt.formatTime(d, Theme.timeFormat)
        if (d >= new Date(day.getTime() - 86400000)) return "Yesterday, " + Qt.formatTime(d, Theme.timeFormat)
        return Qt.formatDateTime(d, Theme.hours("ddd d MMM, HH:mm"))
    }

    // "1.2.0-1  →  1.<b>3.0-1</b>": the part of the version that moves, brighter
    function verChange(from, to) {
        var i = 0
        while (i < from.length && i < to.length && from[i] === to[i]) i++
        while (i > 0 && !/[.:+-]/.test(from[i - 1])) i--
        return from + "  →  " + to.slice(0, i) + "<font color=\"" + Theme.textStrong + "\">" + to.slice(i) + "</font>"
    }

    readonly property var orphans: Health.checks.find(c => c.id === "orphans") || null
    readonly property var reclaim: Health.checks.find(c => c.id === "reclaim") || null

    function ignore(name) {
        if (Settings.updateIgnore.indexOf(name) >= 0) return
        Settings.setUpdateIgnore(Settings.updateIgnore.concat([name]))
        say("Ignoring " + name, false)
    }
    function unignore(name) {
        Settings.setUpdateIgnore(Settings.updateIgnore.filter(n => n !== name))
        say(name + " is back in updates", false)
    }

    Component.onCompleted: {
        Health.scan()
        installedProc.running = true
    }

    // the "ago"s and the next check move on by the minute
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // every installed package, { name, version, aur }, for the search under
    // Ignore a package…; `pacman -Qm` marks the ones from the AUR
    property var installed: []
    readonly property int aurInstalled: installed.filter(p => p.aur).length

    Process {
        id: installedProc
        command: ["sh", "-c", "pacman -Q; echo; pacman -Qmq"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("\n\n")
                var aur = {}
                ;(parts[1] || "").split("\n").forEach(n => { if (n) aur[n] = true })
                page.installed = (parts[0] || "").split("\n").filter(l => l).map(l => {
                    var f = l.split(" ")
                    return { name: f[0], version: f[1] || "", aur: !!aur[f[0]] }
                })
            }
        }
    }

    // --- layout --------------------------------------------------------------

    FlyoutHeading { text: "STATUS" }

    SettingsNote {
        visible: !Updates.available
        text: "checkupdates (pacman-contrib) isn't installed"
        alert: true
    }

    // how things stand: the count large, when it last looked and last
    // upgraded, and both actions
    Item {
        width: parent.width
        implicitHeight: Math.max(Theme.fieldHeight, cardText.implicitHeight + Theme.spaceL * 2)

        Text {
            id: cardGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontTitle * 1.4
            horizontalAlignment: Text.AlignHCenter
            text: Updates.count > 0 || Updates.lastChecked === null ? "󰚰" : "󰄬"
            color: Updates.count > 0 ? Theme.accent : Updates.lastChecked === null ? Theme.muted : Theme.good
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontTitle
        }

        Column {
            id: cardText
            anchors.left: cardGlyph.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: cardChips.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Updates.checking && Updates.lastChecked === null ? "Checking…"
                    : Updates.lastChecked === null ? "Not checked yet"
                    : Updates.count === 0 ? "Up to date"
                    : Updates.count + (Updates.count === 1 ? " update" : " updates")
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontTitle
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: Updates.aurCount > 0 ? Updates.aurCount + " from the AUR" : ""
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Updates.checking ? "Checking now…"
                    : Updates.lastChecked === null ? "The first check runs a minute after the shell starts"
                    : "Checked " + page.when(Updates.lastChecked).replace(", ", " · ")
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: Updates.lastUpgrade !== null
                text: "Last upgrade " + page.when(Updates.lastUpgrade).replace(/^(Today|Yesterday)/, s => s.toLowerCase())
                    + (Updates.lastUpgradeCount > 0 ? ", " + Updates.lastUpgradeCount
                        + (Updates.lastUpgradeCount === 1 ? " package" : " packages") : "")
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        Row {
            id: cardChips
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceS

            FlyoutChip {
                text: "Check now"
                icon: "󰑐"
                spinning: Updates.checking
                enabled: Updates.available && !Updates.checking
                onClicked: Updates.refresh()
            }
            FlyoutChip {
                text: Updates.updating ? "Updating…" : "Update now"
                icon: "󰚰"
                enabled: Updates.count > 0 && !Updates.updating
                onClicked: Updates.update()
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "CHECKING" }

    SettingsField {
        label: "Check for updates"
        hint: Settings.updateInterval === 0 ? "Only when you press Check now"
            : Updates.checking ? "Checking now…"
            : Updates.nextCheck === null || Updates.nextCheck <= clock.date ? "Next check in a minute or so"
            : "Next check at " + Qt.formatTime(Updates.nextCheck, Theme.timeFormat)

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
        hint: !Settings.updateAur ? "Only the official repositories are checked"
            : page.aurInstalled > 0 ? page.aurInstalled + " AUR packages installed, checked with yay"
            : "Checked with yay"

        Switch {
            anchors.right: parent.right
            checked: Settings.updateAur
            onToggled: {
                Settings.setUpdateAur(!Settings.updateAur)
                page.say(Settings.updateAur ? "AUR included" : "Official repositories only", false)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: Updates.count > 0 ? "PENDING  " + Updates.count : "PENDING" }

    property bool showAllPending: false
    readonly property int shortList: 10

    FlyoutRow {
        visible: Updates.count === 0
        enabled: false
        label: Updates.checking ? "Checking…"
            : Updates.lastChecked === null ? "Not checked yet" : "Everything is up to date"
    }

    Repeater {
        model: page.showAllPending ? Updates.packages : Updates.packages.slice(0, page.shortList)

        FlyoutRow {
            required property var modelData
            leadingIcon: "󰏗"
            label: modelData.name
            note: page.verChange(modelData.from, modelData.to)
            noteStyled: true
            trailing: modelData.aur ? "AUR" : "repo"
            actionText: "Ignore"
            onAction: page.ignore(modelData.name)
        }
    }

    FlyoutRow {
        visible: Updates.count > page.shortList
        label: page.showAllPending ? "Show fewer" : "Show all " + Updates.count
        trailing: page.showAllPending ? "󰅀" : (Updates.count - page.shortList) + " more  󰅂"
        onActivated: page.showAllPending = !page.showAllPending
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "IGNORED" }

    FlyoutRow {
        visible: Settings.updateIgnore.length === 0
        enabled: false
        label: "Nothing is left out of updates"
    }

    // each one says whether it's holding an update back
    Repeater {
        model: Settings.updateIgnore

        FlyoutRow {
            required property string modelData
            readonly property var held: Updates.found.find(p => p.name === modelData) || null
            leadingIcon: "󰏤"
            label: modelData
            trailing: held ? "held back · " + held.to + " waiting" : "nothing new"
            actionText: "Stop ignoring"
            onAction: page.unignore(modelData)
        }
    }

    property bool adding: false
    property string query: ""
    readonly property int shownMatches: 6
    // names starting with the search first, then any containing it
    readonly property var matches: {
        if (!adding) return []
        var q = query.trim().toLowerCase()
        var free = installed.filter(p => Settings.updateIgnore.indexOf(p.name) < 0)
        if (q === "") return free
        var starts = [], rest = []
        free.forEach(p => {
            var i = p.name.indexOf(q)
            if (i === 0) starts.push(p)
            else if (i > 0) rest.push(p)
        })
        return starts.concat(rest)
    }

    FlyoutRow {
        leadingIcon: "󰐕"
        label: "Ignore a package…"
        highlighted: page.adding
        trailing: page.adding ? "󰅀" : "󰅂"
        onActivated: {
            page.adding = !page.adding
            search.text = ""
            if (page.adding) Qt.callLater(search.forceFocus)
        }
    }

    SettingsIndent {
        visible: page.adding

        FlyoutInput {
            id: search
            echoPassword: false
            glyph: "󰍉"
            placeholder: "Search installed packages"
            onTextChanged: page.query = text
            onAccepted: if (page.matches.length > 0) matchRows.pick(page.matches[0])
            onEscapePressed: page.adding = false
        }

        Repeater {
            id: matchRows
            function pick(p) {
                page.adding = false
                page.ignore(p.name)
            }
            model: page.matches.slice(0, page.shownMatches)

            FlyoutRow {
                required property var modelData
                label: modelData.name
                note: modelData.version
                trailing: modelData.aur ? "AUR" : "repo"
                onActivated: matchRows.pick(modelData)
            }
        }

        FlyoutRow {
            visible: page.matches.length > page.shownMatches
            enabled: false
            label: "and " + (page.matches.length - page.shownMatches) + " more; type to narrow"
        }
        FlyoutRow {
            visible: page.installed.length > 0 && page.matches.length === 0
            enabled: false
            label: "No installed package matches"
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "UPKEEP" }

    FlyoutRow {
        visible: !page.orphans && !page.reclaim
        enabled: false
        label: Health.scanning ? "Looking…" : "pacman isn't available"
    }

    SettingsField {
        visible: page.orphans !== null
        label: "Orphaned packages"
        hint: !page.orphans ? "" : page.orphans.status === "ok" ? "None: every dependency is still used" : page.orphans.detail

        FlyoutChip {
            anchors.right: parent.right
            visible: !!page.orphans && page.orphans.status !== "ok" && !!page.orphans.repairId
            text: page.orphans ? page.orphans.repairLabel || "Remove" : ""
            enabled: Health.busyRepair === ""
            onClicked: Health.repair(page.orphans)
        }
    }

    // the size goes in the question
    SettingsField {
        id: reclaimField
        readonly property string size: {
            var m = page.reclaim ? /^About ([\d.]+ [KMGT]?B)/.exec(page.reclaim.detail) : null
            return m ? m[1] : ""
        }
        visible: page.reclaim !== null
        label: "Reclaimable space"
        // "About 380 MB: AUR builds 337 MB, old packages 37 MB" -> "380 MB in AUR builds, old packages"
        hint: {
            if (Health.busyRepair === "reclaim") return "Cleaning…"
            if (!page.reclaim) return ""
            var m = /^About ([^:]+): (.*)$/.exec(page.reclaim.detail)
            return m ? m[1] + " in " + m[2].split(", ").map(s => s.replace(/ [\d.]+ [KMGT]?B$/, "")).join(", ")
                : page.reclaim.detail
        }

        FlyoutChip {
            anchors.right: parent.right
            text: page.reclaim ? page.reclaim.repairLabel || "Clean up" : ""
            icon: "󰃢"
            confirmText: reclaimField.size !== "" ? "Clean up " + reclaimField.size + "?" : "Clean up?"
            enabled: Health.busyRepair === "" && reclaimField.size !== ""
            onClicked: Health.repair(page.reclaim)
        }
    }
}
