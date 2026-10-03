// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageHealth.qml
//
// Everything that is wrong with this machine, worst first, with the fix next
// to it. The checks and their repairs are services/Health.qml.
//
// Problems sort to the top and passes fall to the bottom rather than the
// list being grouped under headings: the whole point is that the first row
// is the answer, and a heading above an empty group is one more line to read
// before finding out there is nothing under it.
//
// Scanning is tied to this page being open. SystemPage instances are created
// by the window's Loader on arrival and destroyed on the way out, so the two
// handlers below are the whole of the lifecycle.

import QtQuick
import "../../services"
import "../../flyouts"
import "../../settings"
import "../system"

SystemPage {
    id: page

    title: "Health"
    subtitle: Health.scanning && Health.lastScan === "" ? "checking…"
        : Health.problems > 0
            ? Health.problems + (Health.problems === 1 ? " problem" : " problems")
              + (Health.warnings > 0 ? ", " + Health.warnings + " to look at" : "")
        : Health.warnings > 0
            ? Health.warnings + (Health.warnings === 1 ? " thing" : " things") + " to look at"
        : "Nothing wrong"

    Component.onCompleted: Health.active = true
    Component.onDestruction: Health.active = false

    // bad, then warn, then ok; within a status, the order the scan emitted,
    // which runs services -> tools -> disk -> packages -> space -> links -> log
    readonly property var ordered: {
        var rank = { bad: 0, warn: 1, ok: 2 }
        return Health.checks.slice().sort((a, b) => (rank[a.status] || 3) - (rank[b.status] || 3))
    }

    readonly property var problems: ordered.filter(c => c.status !== "ok")
    readonly property var passing: ordered.filter(c => c.status === "ok")

    // fixes that delete or switch something off take two clicks
    function confirmFor(c) {
        var kind = String(c.repairId || "").split(":")[0]
        return kind === "clean" || kind === "disable" ? c.repairLabel + "?" : ""
    }

    FlyoutHeading { text: "STATUS" }

    // the answer first: a tick or the count, when the checks ran, and the
    // one button that runs them again
    Item {
        width: parent.width
        implicitHeight: Math.max(Theme.fieldHeight, cardText.implicitHeight + Theme.spaceL * 2)

        Text {
            id: cardGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontTitle * 1.4
            horizontalAlignment: Text.AlignHCenter
            text: Health.lastScan === "" ? "󰓙" : page.problems.length > 0 ? "󰀦" : "󰄬"
            color: Health.lastScan === "" ? Theme.muted
                : Health.problems > 0 ? Theme.alert
                : Health.warnings > 0 ? Theme.textStrong : Theme.good
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontTitle
        }

        Column {
            id: cardText
            anchors.left: cardGlyph.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: againChip.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Health.lastScan === "" ? (Health.scanning ? "Checking…" : "Not checked yet")
                    : page.problems.length === 0 ? "All clear" : page.subtitle.charAt(0).toUpperCase() + page.subtitle.slice(1)
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontTitle
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Health.lastScan === "" ? "Services, packages, disks, config links and the shell's log"
                    : "Checked at " + Health.lastScan + " · " + page.passing.length + " of " + Health.checks.length + " passing"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        FlyoutChip {
            id: againChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Health.scanning ? "Checking…" : "Check again"
            icon: "󰑐"
            spinning: Health.scanning
            enabled: !Health.scanning
            onClicked: Health.scan()
        }
    }

    // what needs a look, worst first, each with its fix; no heading at all
    // when there's nothing in it
    Item { width: 1; height: Theme.spaceM; visible: page.problems.length > 0 }
    FlyoutHeading {
        visible: page.problems.length > 0
        text: "TO LOOK AT  " + page.problems.length
    }

    Repeater {
        model: page.problems

        HealthRow {
            required property var modelData

            status: modelData.status
            // a disk check is named by its mount point alone
            label: modelData.label.charAt(0) === "/" ? "Disk " + modelData.label : modelData.label
            detail: modelData.detail
            repairLabel: modelData.repairLabel
            confirmText: page.confirmFor(modelData)
            busy: Health.busyRepair === modelData.id
            // relinking needs the repo the dotfiles came from; a config that
            // is a real file rather than a symlink has no repo to point at
            repairEnabled: Health.busyRepair === ""
                && (modelData.repairId !== "relink" || Health.repoPath !== "")
            onRepaired: Health.repair(modelData)
        }
    }

    Item { width: 1; height: Theme.spaceM; visible: page.passing.length > 0 }
    FlyoutHeading {
        visible: page.passing.length > 0
        text: "PASSING  " + page.passing.length
    }

    Repeater {
        model: page.passing

        HealthRow {
            required property var modelData

            status: modelData.status
            // a disk check is named by its mount point alone
            label: modelData.label.charAt(0) === "/" ? "Disk " + modelData.label : modelData.label
            detail: modelData.detail
            // a pass can still offer something (Clean up, Refresh)
            repairLabel: modelData.repairLabel
            confirmText: page.confirmFor(modelData)
            busy: Health.busyRepair === modelData.id
            repairEnabled: Health.busyRepair === ""
                && (modelData.repairId !== "relink" || Health.repoPath !== "")
            onRepaired: Health.repair(modelData)
        }
    }

    FlyoutRow {
        visible: Health.checks.length === 0 && !Health.scanning
        enabled: false
        label: "No checks ran; is health-scan.sh executable?"
    }

    SettingsNote { text: "If the shell is down, run diagnose in a terminal" }
}
