// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageOverview.qml
//
// The page the window opens on: four headline figures, the two graphs that
// show whether a spike is happening now or just happened, anything
// currently wrong, the heaviest processes, the facts worth knowing without
// asking, and the handful of actions worth reaching for from here.
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
            detail: SystemStats.sensors.length > 1
                ? SystemStats.sensors.length + " sensors"
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
            detail: SystemStats.batNowWh > 0
                ? (SystemStats.batCharging ? "charging" : "on battery")
                  + (SystemStats.batWatts > 0 ? " · " + SystemStats.batWatts.toFixed(1) + " W" : "")
                : SystemStats.diskSize > 0
                    ? Format.bytes(SystemStats.diskSize - SystemStats.diskUsed) + " free" : "--"
            onActivated: page.go(SystemStats.batNowWh > 0 ? "power" : "storage")
        }
    }

    // --- graphs -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "LAST 60 SECONDS" }

    Spark {
        // CPU bright and filled, memory dimmer over it: the two share a
        // 0..1 scale, so one box holds both without a second axis
        series: [
            { values: SystemStats.cpuHistory, color: Theme.text, fill: true },
            { values: SystemStats.memHistory, color: Theme.subtext, fill: false },
        ]
        ceiling: 1
        caption: "CPU · RAM"
    }

    Spark {
        readonly property real peak: Math.max(65536,
            Math.max.apply(null, SystemStats.rxHistory.concat(SystemStats.txHistory, [0])))
        series: [
            { values: SystemStats.rxHistory, color: Theme.text, fill: true },
            { values: SystemStats.txHistory, color: Theme.subtext, fill: false },
        ]
        // 15% headroom above the peak itself, or the peak sample sits
        // exactly on y=0 and its stroke bleeds into the rounded border
        ceiling: peak * 1.15
        caption: "↓ ↑ · peak " + Format.rate(peak)
    }

    // --- health -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }

    // The heading doubles as the way through to the Health page, which runs
    // the checks these two lines are the headline of. It only reports what
    // the last scan found: opening Health is what runs one, since a scan
    // forks a couple of dozen processes and this page is on screen by
    // default every time the window opens.
    Row {
        width: parent.width
        spacing: Theme.spaceL

        FlyoutHeading { text: "HEALTH" }

        FlyoutChip {
            anchors.verticalCenter: parent.verticalCenter
            text: Health.lastScan === "" ? "Run checks"
                : Health.problems > 0 ? Health.problems + " to fix"
                : Health.warnings > 0 ? Health.warnings + " to look at"
                : "All clear"
            onClicked: page.go("health")
        }
    }

    InfoRow {
        label: "Failed units"
        value: FailedUnits.count === 0 ? "none"
            : FailedUnits.units.map(u => u.name).join(", ")
        valueColor: FailedUnits.count === 0 ? undefined : Theme.alert
    }
    InfoRow {
        label: "Updates"
        value: !Updates.available ? "checkupdates not installed"
            : Updates.checking ? "checking…"
            : Updates.count === 0 ? "up to date"
            : Updates.count + " pending  (" + Updates.aurCount + " AUR)"
        valueColor: Updates.available && !Updates.checking && Updates.count > 0
            ? Theme.text : undefined
    }
    InfoRow {
        visible: SystemStats.batNowWh > 0
        label: "Battery wear"
        value: SystemStats.batHealth > 0
            ? Format.pct(SystemStats.batHealth) + " of design capacity" : "n/a"
        valueColor: SystemStats.batHealth > 0 && SystemStats.batHealth < 0.7 ? Theme.alert : undefined
    }
    InfoRow {
        label: "Root filesystem"
        value: SystemStats.diskSize > 0
            ? Format.bytes(SystemStats.diskSize - SystemStats.diskUsed) + " free of "
              + Format.bytes(SystemStats.diskSize) : "--"
        valueColor: SystemStats.diskSize > 0
            && SystemStats.diskUsed / SystemStats.diskSize >= 0.9 ? Theme.alert : undefined
    }
    InfoRow {
        visible: SystemSpecs.orphanCount > 0
        label: "Orphan packages"
        value: SystemSpecs.orphanCount + " with nothing depending on them"
    }

    // --- top processes ------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    ProcessTable { heading: "HEAVIEST PROCESSES"; reserveRows: 5 }

    // --- at a glance -------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "AT A GLANCE" }

    InfoRow { label: "Kernel"; value: SystemSpecs.kernel || "--" }
    InfoRow {
        label: "Booted"
        // the wall-clock moment, since "up 3d 4h" is already in the
        // subtitle and the two answer different questions
        value: Qt.formatDateTime(SystemStats.bootTime, "ddd d MMM, HH:mm")
    }
    InfoRow {
        label: "Load"
        value: SystemStats.load1.toFixed(2) + "  " + SystemStats.load5.toFixed(2)
            + "  " + SystemStats.load15.toFixed(2)
        // one core's worth of work per core is a full machine; past that
        // things are queueing
        valueColor: SystemStats.cores.length > 0 && SystemStats.load1 > SystemStats.cores.length
            ? Theme.alert : undefined
    }
    InfoRow {
        label: "Tasks"
        value: SystemStats.threadTotal + " threads, " + SystemStats.procRunning + " running"
    }
    InfoRow {
        label: "Packages"
        value: SystemSpecs.pkgCount < 0 ? "--"
            : SystemSpecs.pkgCount + "  (" + SystemSpecs.aurCount + " AUR)"
    }
    InfoRow {
        label: "Network"
        value: SystemStats.iface === "" ? "offline"
            : SystemStats.iface + "  ·  " + (SystemStats.ipAddr || "no address")
        valueColor: SystemStats.iface === "" ? Theme.alert : undefined
    }

    // --- actions ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "QUICK ACTIONS" }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: SystemSpecs.copied ? "Specs copied" : "Copy specs"
            selected: SystemSpecs.copied
            onClicked: SystemSpecs.copySummary()
        }
        FlyoutChip {
            text: Updates.checking ? "Checking…" : "Check updates"
            enabled: !Updates.checking && Updates.available
            onClicked: Updates.refresh()
        }
        FlyoutChip {
            text: "Restart audio"
            onClicked: audioRestartProc.running = true
        }
        FlyoutChip {
            text: "Reload Hyprland"
            onClicked: Quickshell.execDetached(["hyprctl", "reload"])
        }
        FlyoutChip {
            text: "This boot's journal"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "journalctl", "-b", "-e"])
        }
        FlyoutChip {
            text: "Config files"
            onClicked: page.go("config")
        }
    }

    Process {
        id: audioRestartProc
        command: ["systemctl", "--user", "restart", "wireplumber", "pipewire", "pipewire-pulse"]
    }
}
