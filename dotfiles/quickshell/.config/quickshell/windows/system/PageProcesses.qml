// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageProcesses.qml
//
// The full table: eighteen rows with pids and owners, sortable, with the
// two-step kill on anything you own. The window asks `top` for the longer
// list only while this page is up (see the procLimit binding in
// System.qml), so the summary tables elsewhere stay cheap.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Processes"
    subtitle: SystemStats.threadTotal + " threads, " + SystemStats.procRunning
        + " runnable  ·  sampled every 3 seconds, ranked over a real 1-second window"

    ProcessTable {
        detailed: true
        reserveRows: 18
    }

    // --- summary ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOTALS" }

    InfoRow {
        label: "CPU in use"
        value: SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--"
        valueColor: SystemStats.cpu >= 0.9 ? Theme.alert : undefined
    }
    InfoRow {
        label: "Memory in use"
        value: Format.kib(SystemStats.memUsedKb) + "  of  " + Format.kib(SystemStats.memTotalKb)
    }
    InfoRow {
        label: "Load average"
        value: SystemStats.load1.toFixed(2) + "  ·  " + SystemStats.load5.toFixed(2)
            + "  ·  " + SystemStats.load15.toFixed(2)
    }
    InfoRow { label: "Running as"; value: SystemStats.me }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    Text {
        width: parent.width
        text: "The kill button sends SIGTERM and only appears on your own processes — "
            + "killing root's would fail silently. For anything this table can't reach, "
            + "open a full monitor."
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "htop"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "command -v htop >/dev/null && htop || top"])
        }
        FlyoutChip {
            text: "Failed units"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "systemctl --failed; echo; systemctl --user --failed; read -r _"])
        }
        FlyoutChip {
            text: "User services"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "systemctl --user list-units --type=service; read -r _"])
        }
        FlyoutChip {
            text: "Startup blame"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "systemd-analyze blame | head -40; read -r _"])
        }
    }
}
