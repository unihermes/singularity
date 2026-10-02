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

    FlyoutHeading { text: "CHECKS" }

    Row {
        width: parent.width
        spacing: Theme.spaceL

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Health.lastScan === "" ? "Not checked yet" : "Checked at " + Health.lastScan
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }

        FlyoutChip {
            text: Health.scanning ? "Checking…" : "Check again"
            enabled: !Health.scanning
            onClicked: Health.scan()
        }
    }

    Repeater {
        model: page.ordered

        HealthRow {
            required property var modelData

            status: modelData.status
            label: modelData.label
            detail: modelData.detail
            repairLabel: modelData.repairLabel
            busy: Health.busyRepair === modelData.id
            // relinking needs the repo the dotfiles came from; a config that
            // is a real file rather than a symlink has no repo to point at
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

    SettingsNote { text: "Read-only. If the shell is down, run diagnose in a terminal" }
}
