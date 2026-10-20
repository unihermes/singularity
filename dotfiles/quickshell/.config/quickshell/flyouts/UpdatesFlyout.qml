// Singularity - Quickshell
// ~/.config/quickshell/flyouts/UpdatesFlyout.qml
//
// A card saying where things stand, with Check now always (beside Update
// now while there are some), then the packages, the space a clean-up would
// free, then Singularity's own commits waiting upstream while there are any.

import QtQuick
import "../services"

FlyoutPanel {
    flyout: "updates"
    menuWidth: 320

    // the reclaimable space comes from Health's package checks
    readonly property var reclaim: Health.checks.find(c => c.id === "reclaim") || null
    // "About 1.5 GB: AUR builds 1.2 GB, old packages 300 MB": the size, then
    // what it's in
    readonly property var reclaimParts: reclaim ? /^About ([\d.]+ [KMGT]?B): (.*)$/.exec(reclaim.detail) : null
    function scanHealth() { if (Health.lastScan === "" && !Health.scanning) Health.scan() }
    onOpenChanged: if (open) scanHealth()
    Component.onCompleted: if (open) scanHealth()

    FlyoutHeading { text: "UPDATES" }

    HeadCard {
        id: card
        readonly property bool some: Updates.count > 0
        glyph: some || Updates.lastChecked === null ? "󰚰" : "󰄬"
        glyphColor: some ? Theme.accent : Updates.lastChecked === null ? Theme.muted : Theme.good
        title: Updates.checking && Updates.lastChecked === null ? "Checking…"
            : Updates.lastChecked === null ? "Not checked"
            : !some ? "Up to date"
            : Updates.count + (Updates.count === 1 ? " update" : " updates")
        lines: [
            some && Updates.aurCount > 0 ? Updates.aurCount + " from the AUR" : "",
            Updates.checking || Updates.repoChecking ? "Checking now…"
                : Updates.lastChecked ? "Checked " + Qt.formatTime(Updates.lastChecked, Theme.timeFormat) : ""
        ]

        FlyoutChip {
            visible: card.some
            text: Updates.repoBehind > 0 ? "Update packages" : "Update now"
            selected: true
            onClicked: {
                Updates.update()
                scope.openFlyout = ""
            }
        }
        FlyoutChip {
            text: card.some ? "󰑓" : "Check now"
            glyph: card.some
            enabled: !Updates.checking && !Updates.repoChecking
            onClicked: Updates.refresh()
        }
    }

    ListView {
        id: updList
        visible: count > 0
        width: parent.width
        height: Math.min(contentHeight, 12 * Theme.rowHeightDense)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: Updates.packages

        delegate: Item {
            required property var modelData
            width: updList.width
            height: Theme.rowHeightDense

            Text {
                anchors.left: parent.left
                anchors.right: ver.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name + (modelData.aur ? "  ·aur" : "")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                id: ver
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Theme.fs(150))

                horizontalAlignment: Text.AlignRight
                text: modelData.to
                elide: Text.ElideLeft
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    // what cleaning the package caches and AUR builds would free
    FlyoutDivider { visible: reclaimRow.visible }

    Item {
        id: reclaimRow
        visible: !!reclaimParts
        width: parent.width
        height: Math.max(reclaimText.implicitHeight, cleanChip.height) + Theme.spaceXs

        Column {
            id: reclaimText
            anchors.left: parent.left
            anchors.right: cleanChip.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: "Reclaimable" + (reclaimParts ? ": " + reclaimParts[1] : "")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                text: Health.busyRepair === "reclaim" ? "Cleaning…" : !reclaimParts ? ""
                    : reclaimParts[2].split(", ").map(t => t.replace(/ [\d.]+ [KMGT]?B$/, "")).join(", ")
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        FlyoutChip {
            id: cleanChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clean up"
            confirmText: reclaimParts ? "Clean up " + reclaimParts[1] + "?" : "Clean up?"
            enabled: Health.busyRepair === ""
            onClicked: Health.repair(reclaim)
        }
    }

    // Singularity's clone, behind its upstream
    FlyoutDivider { visible: Updates.repoBehind > 0 }

    FlyoutHeading {
        visible: Updates.repoBehind > 0
        text: "SINGULARITY  " + Updates.repoBehind
            + (Updates.repoBehind === 1 ? " commit" : " commits") + " to pull"
    }

    Repeater {
        model: Updates.repoBehind > 0 ? Updates.repoCommits.slice(0, 3) : []

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: "󰜘"
            label: modelData.subject
        }
    }

    FlyoutRow {
        visible: Updates.repoCommits.length > 3
        enabled: false
        label: "and " + (Updates.repoCommits.length - 3) + " more"
    }

    // a fast-forward only, as in Settings, so not past local commits
    FlyoutRow {
        visible: Updates.repoBehind > 0
        label: Updates.repoUpdating ? "Pulling…"
            : Updates.repoAhead > 0 ? "Local commits in the way" : "Pull now"
        trailing: "󰇚"
        busy: Updates.repoUpdating
        enabled: Updates.repoAhead === 0 && !Updates.repoUpdating
        onActivated: {
            Updates.updateRepo()
            scope.openFlyout = ""
        }
    }

    FlyoutDivider {}

    FlyoutRow {
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("updates")
    }
}
