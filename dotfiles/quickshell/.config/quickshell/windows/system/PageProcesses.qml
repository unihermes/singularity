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

    subtitle: "Sampled every 3 seconds"

    FlyoutHeading { text: "NOW" }

    // the totals the table sits under: threads and what's runnable, then
    // the machine's CPU, memory and load
    HeadCard {
        glyph: "󰅐"
        glyphColor: SystemStats.cpu >= 0.9 ? Theme.alert : Theme.textStrong
        title: SystemStats.threadTotal + " threads"
        lines: [
            SystemStats.procRunning + " runnable · running as " + SystemStats.me,
            "CPU " + (SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--")
                + " · memory " + Format.kib(SystemStats.memUsedKb) + " of " + Format.kib(SystemStats.memTotalKb)
                + " · load " + SystemStats.load1.toFixed(2),
        ]
    }

    Item { width: 1; height: Theme.spaceS }
    ProcessTable {
        // the page is already called Processes
        heading: SystemStats.procSort === "mem" ? "BY MEMORY" : "BY CPU"
        detailed: true
        reserveRows: 18
        machineShare: true
    }

    SettingsNote { text: "CPU is a share of the whole machine · × ends your own processes" }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    // each opens in a terminal; two to a line
    Grid {
        id: tools
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        FlyoutRow {
            width: tools.cell
            leadingIcon: "󰆍"
            label: "htop"
            note: "Every process, sortable and searchable"
            onActivated: Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c",
                "command -v htop >/dev/null && htop || top"])
        }
        FlyoutRow {
            width: tools.cell
            leadingIcon: "󰀦"
            label: "Failed units"
            note: "systemctl --failed, system and user"
            onActivated: Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c",
                "systemctl --failed; echo; systemctl --user --failed; read -r _"])
        }
        FlyoutRow {
            width: tools.cell
            leadingIcon: "󰒓"
            label: "User services"
            note: "What systemd runs for you"
            onActivated: Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c",
                "systemctl --user list-units --type=service; read -r _"])
        }
        FlyoutRow {
            width: tools.cell
            leadingIcon: "󰔟"
            label: "Startup blame"
            note: "What took longest at the last boot"
            onActivated: Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c",
                "systemd-analyze blame | head -40; read -r _"])
        }
    }
}
