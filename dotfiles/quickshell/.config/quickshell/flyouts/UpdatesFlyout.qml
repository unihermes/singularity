// Singularity - Quickshell
// ~/.config/quickshell/flyouts/UpdatesFlyout.qml
//
// A card saying where things stand with Check and Update at its end, then
// a row per kind (Repositories, AUR, Singularity's commits, Clean up), each
// opening a page of its own with its list and its action, then Settings.

import QtQuick
import "../services"

FlyoutPanel {
    id: root
    flyout: "updates"
    menuWidth: Theme.flyoutMenuWidth

    // the reclaimable space comes from Health's package checks
    readonly property var reclaim: Health.checks.find(c => c.id === "reclaim") || null
    // "About 1.5 GB: AUR builds 1.2 GB, old packages 300 MB": the size, then
    // what it's in
    readonly property var reclaimParts: reclaim ? /^About ([\d.]+ [KMGT]?B): (.*)$/.exec(reclaim.detail) : null
    function scanHealth() { if (Health.lastScan === "" && !Health.scanning) Health.scan() }
    onOpenChanged: if (open) scanHealth(); else page = ""

    // "" is the overview; "repo", "aur", "singularity" or "clean" a page
    property string page: ""
    readonly property var pageTitles: ({ repo: "REPOSITORIES", aur: "AUR", singularity: "SINGULARITY", clean: "CLEAN UP" })
    Component.onCompleted: if (open) scanHealth()

    FlyoutHeading {
        crumb: root.page === "" ? "" : "UPDATES"
        text: root.page === "" ? "UPDATES" : root.pageTitles[root.page]
        onCrumbClicked: root.page = ""
    }

    // where things stand, with Check (and Update while there are some)
    HeadCard {
        id: card
        visible: root.page === ""
        readonly property bool some: Updates.count > 0
        glyph: some || Updates.lastChecked === null ? "󰚰" : "󰄬"
        glyphColor: some ? Theme.accent : Updates.lastChecked === null ? Theme.muted : Theme.good
        title: Updates.checking && Updates.lastChecked === null ? "Checking…"
            : Updates.lastChecked === null ? "Not checked"
            : !some ? "Up to date"
            : Updates.count + (Updates.count === 1 ? " update" : " updates")
        lines: [
            Updates.checking || Updates.repoChecking ? "Checking now…"
                : Updates.lastChecked ? "Checked " + Qt.formatTime(Updates.lastChecked, Theme.timeFormat) : ""
        ]

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰑓"
            spinning: Updates.checking || Updates.repoChecking
            enabled: !Updates.checking && !Updates.repoChecking
            onClicked: Updates.refresh()
        }
        FlyoutChip {
            anchors.verticalCenter: parent.verticalCenter
            visible: card.some
            text: Updates.repoBehind > 0 ? "Update packages" : "Update"
            selected: true
            onClicked: {
                Updates.update()
                scope.openFlyout = ""
            }
        }
    }

    // the packages by where they come from
    readonly property var repoPackages: Updates.packages.filter(p => !p.aur)
    readonly property var aurPackages: Updates.packages.filter(p => p.aur)

    FlyoutDivider { visible: root.page === "" }

    // a row per kind, its count at the end; each opens its page
    Repeater {
        model: root.page === "" ? [
            { page: "repo", icon: "󰏖", label: "Repositories", value: String(root.repoPackages.length) },
            { page: "aur", icon: "󰏗", label: "AUR", value: String(root.aurPackages.length) },
            { page: "singularity", icon: "󰜘", label: "Singularity",
              value: Updates.repoBehind > 0 ? Updates.repoBehind + (Updates.repoBehind === 1 ? " commit" : " commits") : "Current" },
            { page: "clean", icon: "󰃢", label: "Clean up",
              value: Health.busyRepair === "reclaim" ? "Cleaning…" : root.reclaimParts ? root.reclaimParts[1] : "Nothing" },
        ] : []

        FlyoutRow {
            required property var modelData
            leadingIcon: modelData.icon
            label: modelData.label
            trailing: modelData.value + "  󰅂"
            trailingIsValue: true
            onActivated: root.page = modelData.page
        }
    }

    // --- a page each ---

    FlyoutRow {
        visible: (root.page === "repo" && root.repoPackages.length === 0)
            || (root.page === "aur" && root.aurPackages.length === 0)
        enabled: false
        label: Updates.lastChecked === null ? "Not checked yet" : "Nothing to update"
    }
    PackageList { packages: root.page === "repo" ? root.repoPackages : root.page === "aur" ? root.aurPackages : [] }

    // Singularity's clone, behind its upstream
    Repeater {
        model: root.page === "singularity" ? Updates.repoCommits.slice(0, 8) : []

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: "󰜘"
            label: modelData.subject
        }
    }

    FlyoutRow {
        visible: root.page === "singularity" && Updates.repoCommits.length > 8
        enabled: false
        label: "and " + (Updates.repoCommits.length - 8) + " more"
    }

    FlyoutRow {
        visible: root.page === "singularity" && Updates.repoBehind === 0
        enabled: false
        label: "Up to date with " + (Updates.repoUpstream || "upstream")
    }

    // what cleaning the package caches and AUR builds would free, by part
    Repeater {
        model: root.page === "clean" && root.reclaimParts ? root.reclaimParts[2].split(", ") : []

        FlyoutRow {
            required property var modelData
            readonly property var m: /^(.*) ([\d.]+ [KMGT]?B)$/.exec(modelData)
            enabled: false
            label: m ? m[1].charAt(0).toUpperCase() + m[1].slice(1) : modelData
            trailing: m ? m[2] : ""
            trailingIsValue: true
        }
    }

    FlyoutRow {
        visible: root.page === "clean" && !root.reclaimParts
        enabled: false
        label: Health.scanning ? "Looking…" : "Nothing to clean up"
    }

    // every page's own action, after its list
    FlyoutDivider { visible: root.page !== "" }

    FlyoutChipLine {
        visible: (root.page === "repo" || root.page === "aur") && Updates.count > 0
        chips: [{ icon: "󰚰", text: Updates.count === 1 ? "Update 1 package" : "Update " + Updates.count + " packages", act: "update" }]
        onPicked: {
            Updates.update()
            scope.openFlyout = ""
        }
    }

    // a fast-forward only, as in Settings, so not past local commits
    FlyoutChip {
        visible: root.page === "singularity" && Updates.repoBehind > 0
        width: parent.width
        icon: "󰇚"
        text: Updates.repoUpdating ? "Pulling…"
            : Updates.repoAhead > 0 ? "Local commits in the way" : "Pull now"
        enabled: Updates.repoAhead === 0 && !Updates.repoUpdating
        onClicked: {
            Updates.updateRepo()
            scope.openFlyout = ""
        }
    }

    FlyoutChip {
        visible: root.page === "clean" && !!root.reclaimParts
        width: parent.width
        icon: "󰃢"
        text: Health.busyRepair === "reclaim" ? "Cleaning…" : "Clean up " + (root.reclaimParts ? root.reclaimParts[1] : "")
        confirmText: root.reclaimParts ? "Clean up " + root.reclaimParts[1] + "?" : "Clean up?"
        enabled: Health.busyRepair === ""
        onClicked: Health.repair(root.reclaim)
    }

    FlyoutDivider { visible: root.page === "" }

    FlyoutChipLine {
        visible: root.page === ""
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: scope.openSettings("updates")
    }
}
