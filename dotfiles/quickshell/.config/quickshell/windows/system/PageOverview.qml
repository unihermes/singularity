// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageOverview.qml
//
// The page the window opens on: four headline figures, each with its last
// minute drawn over its level, the network's minute in a strip, a health
// card that only lists what needs a look, the heaviest processes, the facts
// worth knowing without asking, and the handful of actions worth reaching
// for from here.
//
// Everything on it is a summary of a page behind it, and each tile clicks
// through to the page it summarises.

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

    title: "Overview"
    subtitle: SystemSpecs.distro
        + (SystemSpecs.arch ? "  ·  " + SystemSpecs.arch : "")
        + "  ·  up " + Format.duration(SystemStats.uptimeSec)

    // the window, for the tiles that click through to another page
    readonly property var win: {
        var p = page.parent
        while (p && p.currentPage === undefined) p = p.parent
        return p
    }
    function go(id) { if (win) win.select(id) }

    // --- headline figures -------------------------------------------------

    Row {
        width: parent.width
        spacing: Theme.spaceM

        readonly property int cellWidth: (width - spacing * 3) / 4

        StatCard {
            width: parent.cellWidth
            caption: "CPU"
            value: SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--"
            fraction: SystemStats.cpu
            critical: SystemStats.cpu >= 0.9
            history: SystemStats.cpuHistory
            detail: SystemStats.cpuMhz > 0
                ? (SystemStats.cpuMhz / 1000).toFixed(2) + " GHz · " + SystemStats.cores.length + "T"
                : SystemStats.cores.length + " threads"
            onActivated: page.go("cpu")
        }

        StatCard {
            width: parent.cellWidth
            caption: "Memory"
            value: Format.pct(SystemStats.mem)
            fraction: SystemStats.mem
            critical: SystemStats.mem >= 0.9
            history: SystemStats.memHistory
            detail: Format.kib(SystemStats.memUsedKb) + " of " + Format.kib(SystemStats.memTotalKb)
            onActivated: page.go("memory")
        }

        StatCard {
            width: parent.cellWidth
            caption: "Temp"
            available: SystemStats.tempC >= 0
            value: SystemStats.tempC >= 0 ? Math.round(SystemStats.tempC) + "°C" : "--"
            // 100C spans the bar: Intel mobile chips throttle in the high
            // 90s, so a full bar means what it looks like it means
            fraction: SystemStats.tempC / 100
            critical: SystemStats.tempC >= 90
            // the line from 30 °C, where an idle laptop sits, so a warm-up shows
            history: SystemStats.tempHistory
            historyFloor: 30
            historyCeiling: 100
            detail: SystemStats.sensors.length > 1
                ? "CPU package · " + SystemStats.sensors.length + " sensors"
                : SystemStats.tempC >= 0 ? "CPU package" : "no sensor"
            onActivated: page.go("hardware")
        }

        StatCard {
            width: parent.cellWidth
            caption: SystemStats.batNowWh > 0 ? "Battery" : "Disk"
            available: SystemStats.batNowWh > 0 || SystemStats.diskSize > 0
            value: SystemStats.batNowWh > 0
                ? (Number(SystemStats.bat.capacity) || 0) + "%"
                : SystemStats.diskSize > 0 ? Format.pct(SystemStats.diskUsed / SystemStats.diskSize) : "--"
            fraction: SystemStats.batNowWh > 0
                ? (Number(SystemStats.bat.capacity) || 0) / 100
                : SystemStats.diskSize > 0 ? SystemStats.diskUsed / SystemStats.diskSize : 0
            critical: SystemStats.batNowWh > 0
                ? !SystemStats.batCharging && Number(SystemStats.bat.capacity) <= 15
                : SystemStats.diskSize > 0 && SystemStats.diskUsed / SystemStats.diskSize >= 0.9
            history: SystemStats.batNowWh > 0 ? SystemStats.batHistory : []
            detail: SystemStats.batNowWh > 0
                ? (SystemStats.batCharging ? "charging" : "on battery")
                  + (SystemStats.batWatts > 0 ? " · " + SystemStats.batWatts.toFixed(1) + " W" : "")
                  + (SystemStats.batHours > 0 ? " · " + Format.duration(SystemStats.batHours * 3600) + " left" : "")
                : SystemStats.diskSize > 0
                    ? Format.bytes(SystemStats.diskSize - SystemStats.diskUsed) + " free" : "--"
            onActivated: page.go(SystemStats.batNowWh > 0 ? "power" : "storage")
        }
    }

    // the network's minute, one slim strip: down filled, up over it
    Spark {
        readonly property real peak: Math.max(65536,
            Math.max.apply(null, SystemStats.rxHistory.concat(SystemStats.txHistory, [0])))
        height: Theme.row(34)
        series: [
            { values: SystemStats.rxHistory, color: Theme.text, fill: true },
            { values: SystemStats.txHistory, color: Theme.subtext, fill: false },
        ]
        // 15% headroom above the peak itself, or the peak sample sits
        // exactly on y=0 and its stroke bleeds into the rounded border
        ceiling: peak * 1.15
        caption: SystemStats.iface === "" ? "offline"
            : SystemStats.iface + "  ↓ " + Format.rate(Math.max(0, SystemStats.rxRate))
              + "  ↑ " + Format.rate(Math.max(0, SystemStats.txRate)) + "  · peak " + Format.rate(peak)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.go("network")
        }
    }

    // --- health -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "HEALTH" }

    // what the last scan found, and the two ways on: run it here, or open
    // the page that explains each check. The scan isn't run on arrival: it
    // forks a couple of dozen processes and this page shows every time the
    // window opens.
    readonly property var needsLook: Health.checks.filter(c => c.status !== "ok")

    HeadCard {
        glyph: Health.lastScan === "" ? "󰓙" : Health.problems + Health.warnings > 0 ? "󰀦" : "󰄬"
        glyphColor: Health.lastScan === "" ? Theme.muted
            : Health.problems > 0 ? Theme.alert
            : Health.warnings > 0 ? Theme.textStrong : Theme.good
        title: Health.scanning ? "Checking…"
            : Health.lastScan === "" ? "Not checked yet"
            : Health.problems > 0 ? Health.problems + (Health.problems === 1 ? " problem" : " problems")
                + (Health.warnings > 0 ? ", " + Health.warnings + " to look at" : "")
            : Health.warnings > 0 ? Health.warnings + " to look at"
            : "All clear"
        lines: [Health.lastScan === "" ? "Run checks looks at services, packages, disks and config"
            : "Checked at " + Health.lastScan + " · " + Health.checks.length + " checks"]

        FlyoutChip {
            text: "Run checks"
            icon: "󰑐"
            spinning: Health.scanning
            enabled: !Health.scanning
            onClicked: Health.scan()
        }
        FlyoutChip {
            text: "Open Health  󰅂"
            onClicked: page.go("health")
        }
    }

    // only what needs a look, each opening where it's fixed
    FlyoutRow {
        visible: FailedUnits.count > 0
        leadingIcon: "󰀦"
        alert: true
        label: FailedUnits.count + (FailedUnits.count === 1 ? " failed unit" : " failed units")
        note: FailedUnits.units.map(u => u.name).join(", ")
        trailing: "󰅂"
        onActivated: page.go("health")
    }
    FlyoutRow {
        visible: Updates.count > 0
        leadingIcon: "󰚰"
        label: Updates.count + (Updates.count === 1 ? " update pending" : " updates pending")
        note: Updates.packages.slice(0, 3).map(p => p.name).join(", ") + (Updates.count > 3 ? "…" : "")
        trailing: "󰁔"
        onActivated: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "updates"])
    }
    Repeater {
        model: page.needsLook.filter(c => c.id !== "units")

        FlyoutRow {
            required property var modelData
            leadingIcon: "󰀦"
            alert: modelData.status === "bad"
            label: modelData.label
            note: modelData.detail
            trailing: "󰅂"
            onActivated: page.go("health")
        }
    }
    // everything fine, in one quiet line
    FlyoutRow {
        enabled: false
        leadingIcon: "󰄬"
        label: [FailedUnits.count === 0 ? "No failed units" : "",
                SystemStats.batHealth > 0 ? "battery at " + Format.pct(SystemStats.batHealth) + " of its design" : "",
                SystemStats.diskSize > 0 ? Format.bytes(SystemStats.diskSize - SystemStats.diskUsed) + " free on /" : "",
               ].filter(s => s !== "").join(" · ")
    }

    // --- top processes ------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    ProcessTable { heading: "HEAVIEST PROCESSES"; reserveRows: 5; machineShare: true }

    FlyoutRow {
        label: "All processes"
        trailing: "󰅂"
        onActivated: page.go("processes")
    }

    // --- at a glance -------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "AT A GLANCE" }

    // two columns, so six facts take three lines
    Grid {
        id: facts
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow { width: facts.cell; label: "Kernel"; value: SystemSpecs.kernel || "--" }
        InfoRow {
            width: facts.cell
            label: "Booted"
            // the wall-clock moment, since "up 3d 4h" is already in the
            // subtitle and the two answer different questions
            value: Qt.formatDateTime(SystemStats.bootTime, "ddd d MMM, HH:mm")
        }
        InfoRow {
            width: facts.cell
            label: "Load"
            value: SystemStats.load1.toFixed(2) + "  " + SystemStats.load5.toFixed(2)
                + "  " + SystemStats.load15.toFixed(2)
            // one core's worth of work per core is a full machine; past that
            // things are queueing
            valueColor: SystemStats.cores.length > 0 && SystemStats.load1 > SystemStats.cores.length
                ? Theme.alert : undefined
        }
        InfoRow {
            width: facts.cell
            label: "Tasks"
            value: SystemStats.threadTotal + " threads, " + SystemStats.procRunning + " running"
        }
        InfoRow {
            width: facts.cell
            label: "Packages"
            value: SystemSpecs.pkgCount < 0 ? "--"
                : SystemSpecs.pkgCount + "  (" + SystemSpecs.aurCount + " AUR)"
        }
        InfoRow {
            width: facts.cell
            label: "Network"
            value: SystemStats.iface === "" ? "offline"
                : SystemStats.iface + "  ·  " + (SystemStats.ipAddr || "no address")
            valueColor: SystemStats.iface === "" ? Theme.alert : undefined
        }
    }

    // --- actions ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "QUICK ACTIONS" }

    FlyoutRow {
        leadingIcon: SystemSpecs.copied ? "󰄬" : "󰆏"
        label: SystemSpecs.copied ? "Specs copied" : "Copy specs"
        note: "The machine in a paragraph, for a forum post"
        onActivated: SystemSpecs.copySummary()
    }
    FlyoutRow {
        leadingIcon: "󰚰"
        label: Updates.checking ? "Checking…" : "Check updates"
        note: Updates.lastChecked ? "Last checked " + Qt.formatTime(Updates.lastChecked, Theme.timeFormat) : ""
        enabled: Updates.available
        busy: Updates.checking
        onActivated: Updates.refresh()
    }
    // sound stops for a moment, so it asks first
    FlyoutRow {
        leadingIcon: "󰕾"
        label: "Restart audio"
        confirmText: "Restart audio?"
        note: "PipeWire and WirePlumber; sound stops for a second"
        onActivated: audioRestartProc.running = true
    }
    FlyoutRow {
        leadingIcon: "󰑐"
        label: "Reload Hyprland"
        note: "Re-reads hyprland.lua"
        onActivated: Quickshell.execDetached(["hyprctl", "reload"])
    }
    FlyoutRow {
        leadingIcon: "󰈙"
        label: "This boot's journal"
        note: "journalctl -b in a terminal"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "journalctl", "-b", "-e"])
    }
    FlyoutRow {
        leadingIcon: "󰈔"
        label: "Config files"
        note: "The files behind it all"
        trailing: "󰅂"
        onActivated: page.go("config")
    }

    Process {
        id: audioRestartProc
        command: ["systemctl", "--user", "restart", "wireplumber", "pipewire", "pipewire-pulse"]
    }
}
