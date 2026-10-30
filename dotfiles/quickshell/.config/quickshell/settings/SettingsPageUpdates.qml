// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageUpdates.qml
//
// Software updates: check interval, AUR, ignored packages (Settings.qml);
// pending updates, the upgrade and the Singularity clone from Updates.qml;
// removing installed packages through singularity-remove and pkexec;
// upkeep rows from Health's package checks.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Software Update"
    description: "How often to check, the AUR, packages to leave out, and removing packages."

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

    // "3 commits behind origin/main · 1 local commit: merge by hand"
    readonly property string repoHint: {
        var behind = Updates.repoBehind, ahead = Updates.repoAhead
        if (Updates.repoState === "") return Updates.repoChecking ? "Checking…" : "Not checked yet"
        if (Updates.repoState === "none") return "~/.config/quickshell isn't a link into a clone"
        if (Updates.repoState === "noupstream") return "The branch tracks no remote branch"
        var parts = [behind === 0 ? "Up to date with " + Updates.repoUpstream
            : behind + (behind === 1 ? " commit" : " commits") + " behind " + Updates.repoUpstream]
        if (ahead > 0)
            parts.push(ahead + (ahead === 1 ? " local commit" : " local commits")
                + (behind > 0 ? ": merge by hand" : " not pushed"))
        if (Updates.repoState === "fetch") parts.push("couldn't reach the remote")
        return parts.join(" · ")
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
        removeHelperProbe.running = true
    }

    // the "ago"s and the next check move on by the minute
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // every installed package, { name, version, aur, explicit }, for the
    // searches under Ignore a package… and Remove a package…; `pacman -Qm`
    // marks the ones from the AUR, `pacman -Qe` the ones installed on purpose
    property var installed: []
    readonly property int aurInstalled: installed.filter(p => p.aur).length

    Process {
        id: installedProc
        command: ["sh", "-c", "pacman -Q; echo; pacman -Qmq; echo; pacman -Qeq"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("\n\n")
                var set = t => {
                    var o = {}
                    ;(t || "").split("\n").forEach(n => { if (n) o[n] = true })
                    return o
                }
                var aur = set(parts[1]), explicit = set(parts[2])
                page.installed = (parts[0] || "").split("\n").filter(l => l).map(l => {
                    var f = l.split(" ")
                    return { name: f[0], version: f[1] || "", aur: !!aur[f[0]], explicit: !!explicit[f[0]] }
                })
            }
        }
    }

    // --- removing --------------------------------------------------------------

    readonly property string removeHelper: "/usr/local/bin/singularity-remove"
    property bool removeHelperFound: false
    Process {
        id: removeHelperProbe
        command: ["test", "-x", page.removeHelper]
        onExited: code => page.removeHelperFound = code === 0
    }

    property bool removing: false
    property string removeQuery: ""
    // the package picked, and what pacman would take with it: [{ name, size }]
    // with the package first, or the reason it can't go
    property var removeTarget: null
    property var removeSet: []
    property string removeBlocked: ""
    property bool removeBusy: false
    readonly property var removeMatches: {
        if (!removing || removeTarget) return []
        var q = removeQuery.trim().toLowerCase()
        var mine = installed.filter(p => p.explicit)
        if (q === "") return mine
        var starts = [], rest = []
        mine.forEach(p => {
            var i = p.name.indexOf(q)
            if (i === 0) starts.push(p)
            else if (i > 0) rest.push(p)
        })
        return starts.concat(rest)
    }
    readonly property real removeBytes: removeSet.reduce((n, p) => n + p.size, 0)

    function size(bytes) {
        var units = ["B", "KB", "MB", "GB"], i = 0
        while (bytes >= 1000 && i < units.length - 1) { bytes /= 1000; i++ }
        return (i === 0 ? bytes : bytes.toFixed(bytes < 10 ? 1 : 0)) + " " + units[i]
    }

    function pickRemoval(p) {
        removeTarget = p
        removeSet = []
        removeBlocked = ""
        removePreview.command = ["pacman", "-Rs", "--print", "--print-format", "%n %s", "--", p.name]
        removePreview.running = true
    }
    function closeRemoval() {
        removing = false
        removeTarget = null
        removeSet = []
        removeBlocked = ""
    }

    // what -Rns would remove, worked out unprivileged; a dependency it would
    // break comes back as ":: removing x breaks dependency 'x' required by y"
    // on stdout, under an error on stderr
    Process {
        id: removePreview
        stdout: StdioCollector { id: previewOut }
        stderr: StdioCollector { id: previewErr }
        onExited: code => {
            if (code === 0) {
                page.removeSet = previewOut.text.split("\n").filter(l => l).map(l => {
                    var f = l.split(" ")
                    return { name: f[0], size: Number(f[1]) || 0 }
                })
                return
            }
            var needed = []
            previewOut.text.split("\n").forEach(l => {
                var m = /required by (\S+)/.exec(l)
                if (m && needed.indexOf(m[1]) < 0) needed.push(m[1])
            })
            page.removeBlocked = needed.length > 0
                ? "Needed by " + needed.slice(0, 3).join(", ") + (needed.length > 3 ? " and " + (needed.length - 3) + " more" : "")
                : previewErr.text.trim().split("\n")[0].replace(/^error: /, "") || "pacman can't remove it"
        }
    }

    function remove() {
        if (!removeTarget || removeBusy) return
        removeBusy = true
        remover.command = ["pkexec", removeHelper, removeTarget.name]
        remover.running = true
    }
    Process {
        id: remover
        stderr: StdioCollector { id: removeErr }
        onExited: code => {
            page.removeBusy = false
            var name = page.removeTarget ? page.removeTarget.name : ""
            var lines = removeErr.text.trim().split("\n").filter(l => l)
            var e = lines.filter(l => l.startsWith("error:")).pop() || lines.pop() || ""
            if (code === 0) {
                var more = page.removeSet.length - 1
                page.say("Removed " + name + (more > 0 ? " and " + more + (more === 1 ? " dependency" : " dependencies") : ""), false)
                page.closeRemoval()
                installedProc.running = true
                Updates.refresh()
            }
            // 126/127: pkexec was dismissed or refused
            else if (code === 126 || code === 127) page.say(name + " wasn't removed", false)
            else page.say("Couldn't remove " + name + (e ? ": " + e.replace(/^error: /, "") : ""), true)
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
                spinning: Updates.checking || Updates.repoChecking
                enabled: !Updates.checking && !Updates.repoChecking
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

    // pulls, relinks and installs new packages; a fast-forward only, so not
    // while local commits are in the way
    SettingsField {
        label: "Repository"
        hint: page.repoHint

        FlyoutChip {
            anchors.right: parent.right
            text: Updates.repoUpdating ? "Updating…" : "Update"
            icon: "󰚰"
            enabled: Updates.repoBehind > 0 && Updates.repoAhead === 0 && !Updates.repoUpdating
            onClicked: Updates.updateRepo()
        }
    }

    FlyoutRow {
        visible: Updates.repoBehind > 0 && Updates.repoNewPackages.length > 0
        enabled: false
        leadingIcon: "󰏗"
        label: "Installs " + Updates.repoNewPackages.join(", ")
        trailing: "new in packages/"
    }

    property bool showAllCommits: false

    Repeater {
        model: page.showAllCommits ? Updates.repoCommits : Updates.repoCommits.slice(0, page.shortList)

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: "󰜘"
            label: modelData.subject
            trailing: page.when(new Date(modelData.time))
        }
    }

    FlyoutRow {
        visible: Updates.repoCommits.length > page.shortList
        label: page.showAllCommits ? "Show fewer" : "Show all " + Updates.repoCommits.length
        trailing: page.showAllCommits ? "󰅀" : (Updates.repoCommits.length - page.shortList) + " more  󰅂"
        onActivated: page.showAllCommits = !page.showAllCommits
    }

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
    FlyoutHeading { text: "PACKAGES" }

    // what's waiting, only while there's some; the card says when there's none
    SettingsSubhead { visible: Updates.count > 0; caption: "PENDING  " + Updates.count }

    property bool showAllPending: false
    readonly property int shortList: 10

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

    SettingsSubhead { caption: "IGNORED" }

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

    SettingsSubhead { caption: "REMOVE" }

    FlyoutRow {
        leadingIcon: "󰆴"
        label: "Remove a package…"
        enabled: page.removeHelperFound
        note: page.removeHelperFound ? "" : "Run install.sh to remove packages from here"
        highlighted: page.removing
        trailing: page.removing ? "󰅀" : "󰅂"
        onActivated: {
            if (page.removing) { page.closeRemoval(); return }
            page.removing = true
            removeSearch.text = ""
            Qt.callLater(removeSearch.forceFocus)
        }
    }

    SettingsIndent {
        visible: page.removing

        FlyoutInput {
            id: removeSearch
            visible: !page.removeTarget
            echoPassword: false
            glyph: "󰍉"
            placeholder: "Search packages you installed"
            onTextChanged: page.removeQuery = text
            onAccepted: if (page.removeMatches.length > 0) page.pickRemoval(page.removeMatches[0])
            onEscapePressed: page.closeRemoval()
        }

        Repeater {
            model: page.removeMatches.slice(0, page.shownMatches)

            FlyoutRow {
                required property var modelData
                label: modelData.name
                note: modelData.version
                trailing: modelData.aur ? "AUR" : "repo"
                onActivated: page.pickRemoval(modelData)
            }
        }

        FlyoutRow {
            visible: page.removeMatches.length > page.shownMatches
            enabled: false
            label: "and " + (page.removeMatches.length - page.shownMatches) + " more; type to narrow"
        }
        FlyoutRow {
            visible: !page.removeTarget && page.installed.length > 0 && page.removeMatches.length === 0
            enabled: false
            label: "No package you installed matches"
        }

        // the one picked: what goes with it, and the button
        SettingsField {
            visible: page.removeTarget !== null
            searchable: false
            label: page.removeTarget ? page.removeTarget.name : ""
            hint: {
                if (!page.removeTarget) return ""
                if (page.removeBusy) return "Removing…"
                if (page.removeBlocked !== "") return page.removeBlocked
                if (page.removeSet.length === 0) return "Looking…"
                var deps = page.removeSet.slice(1).map(p => p.name)
                return page.size(page.removeBytes) + " freed"
                    + (deps.length === 0 ? ", nothing else goes with it"
                       : ", with " + (deps.length === 1 ? "1 dependency nothing else uses: " : deps.length + " dependencies nothing else uses: ")
                         + deps.slice(0, 4).join(", ") + (deps.length > 4 ? "…" : ""))
            }
            dimmed: page.removeBlocked !== ""

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceXs

                FlyoutChip {
                    text: "Back"
                    enabled: !page.removeBusy
                    onClicked: {
                        page.removeTarget = null
                        Qt.callLater(removeSearch.forceFocus)
                    }
                }
                FlyoutChip {
                    visible: page.removeBlocked === ""
                    text: "Remove"
                    icon: "󰆴"
                    spinning: page.removeBusy
                    confirmText: page.removeSet.length > 1 ? "Remove " + page.removeSet.length + " packages?" : "Remove it?"
                    enabled: !page.removeBusy && page.removeSet.length > 0
                    onClicked: page.remove()
                }
            }
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
            confirmText: "Remove them?"
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
