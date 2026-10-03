// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageProcesses.qml
//
// The full table: eighteen rows with pids and owners, sortable, with the
// two-step kill on anything you own. The window asks `top` for the longer
// list only while this page is up (see the procLimit binding in
// System.qml), so the summary tables elsewhere stay cheap.

import Quickshell
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
import "../../settings"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Processes"
    subtitle: SystemStats.threadTotal + " threads, " + SystemStats.procRunning
        + " runnable  ·  sampled every 3 seconds"

    ProcessTable {
        // the page is already called Processes
        heading: SystemStats.procSort === "mem" ? "BY MEMORY" : "BY CPU"
        detailed: true
        reserveRows: 18
        machineShare: true
    }

    SettingsNote { text: "CPU is a share of the whole machine · × ends your own processes" }

    // --- totals -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOTALS" }

    Grid {
        id: totals
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow {
            width: totals.cell
            label: "CPU in use"
            value: SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--"
            valueColor: SystemStats.cpu >= 0.9 ? Theme.alert : undefined
        }
        InfoRow {
            width: totals.cell
            label: "Memory in use"
            value: Format.kib(SystemStats.memUsedKb) + " of " + Format.kib(SystemStats.memTotalKb)
        }
        InfoRow {
            width: totals.cell
            label: "Load"
            value: SystemStats.load1.toFixed(2) + "  " + SystemStats.load5.toFixed(2)
                + "  " + SystemStats.load15.toFixed(2)
        }
        InfoRow { width: totals.cell; label: "Running as"; value: SystemStats.me }
    }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    // each opens in a terminal
    FlyoutRow {
        leadingIcon: "󰆍"
        label: "htop"
        note: "Every process, sortable and searchable"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "command -v htop >/dev/null && htop || top"])
    }
    FlyoutRow {
        leadingIcon: "󰀦"
        label: "Failed units"
        note: "systemctl --failed, system and user"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "systemctl --failed; echo; systemctl --user --failed; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰒓"
        label: "User services"
        note: "What systemd runs for you"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "systemctl --user list-units --type=service; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰔟"
        label: "Startup blame"
        note: "What took longest at the last boot"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "systemd-analyze blame | head -40; read -r _"])
    }
}
