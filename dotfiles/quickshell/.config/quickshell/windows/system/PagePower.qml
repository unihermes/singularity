// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PagePower.qml
//
// The battery as the pack itself reports it, not as UPower rounds it: the
// charge, the draw in watts, and -- the number that actually matters on a
// three-year-old laptop -- how much of its design capacity is left.
//
// Every figure comes from one file, the battery's uevent, so the page costs
// a single read every three seconds. Packs report either charge (amp-hours)
// or energy (watt-hours); SystemStats converts both to watt-hours, so
// nothing here has to care which kind this one is.

import Quickshell
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    readonly property bool present: SystemStats.bat.status !== undefined
    readonly property int percent: Number(SystemStats.bat.capacity) || 0

    title: "Power"
    subtitle: !present ? "No battery — this machine runs on mains only"
        : (SystemStats.batCharging ? "Charging" : SystemStats.acOnline ? "On mains" : "On battery")
          + (SystemStats.batHours > 0
             ? "  ·  " + Format.duration(SystemStats.batHours * 3600)
               + (SystemStats.batCharging ? " to full" : " remaining") : "")

    FlyoutHeading { text: "NOW" }

    // the charge and what it's doing, with how long it lasts at this draw
    HeadCard {
        glyph: !page.present ? "󰚥"
            : SystemStats.batCharging ? "󰂄"
            : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.round(page.percent / 10)]
        glyphColor: page.present && !SystemStats.batCharging && page.percent <= 15 ? Theme.alert : Theme.textStrong
        title: !page.present ? "On mains" : page.percent + "% · "
            + (SystemStats.batCharging ? "charging" : SystemStats.acOnline ? "on mains" : "on battery")
        lines: !page.present ? ["No battery in this machine"] : [
            (SystemStats.batWatts > 0 ? SystemStats.batWatts.toFixed(1) + " W" : "")
                + (SystemStats.batHours > 0 ? (SystemStats.batWatts > 0 ? " · " : "")
                   + Format.duration(SystemStats.batHours * 3600) + (SystemStats.batCharging ? " to full" : " left") : ""),
            SystemStats.batHealth > 0 ? "Holds " + Format.pct(SystemStats.batHealth) + " of what it did new" : "",
        ]

        FlyoutChip {
            text: "Settings  󰅂"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "power"])
        }
    }

    // the charge as a level, full width, as the bar's battery chip has it
    Meter {
        visible: page.present
        width: parent.width
        fraction: page.percent / 100
        fillColor: !SystemStats.batCharging && page.percent <= 15 ? Theme.alert : Theme.meterFill
    }

    // --- right now ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "RIGHT NOW" }

    Grid {
        id: nowGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow {
            width: nowGrid.cell
            label: "State"
            value: page.present ? String(SystemStats.bat.status || "--") : "--"
        }
        InfoRow {
            width: nowGrid.cell
            label: "Mains"
            value: SystemStats.acOnline ? "connected" : "disconnected"
        }
        InfoRow {
            width: nowGrid.cell
            label: "Draw"
            value: SystemStats.batWatts > 0 ? SystemStats.batWatts.toFixed(1) + " W" : "--"
        }
        InfoRow {
            width: nowGrid.cell
            label: "Charge held"
            value: SystemStats.batNowWh > 0
                ? SystemStats.batNowWh.toFixed(1) + " of " + SystemStats.batFullWh.toFixed(1) + " Wh" : "--"
        }
        InfoRow {
            width: nowGrid.cell
            label: "Voltage"
            value: Number(SystemStats.bat.voltage_now) > 0
                ? (Number(SystemStats.bat.voltage_now) / 1e6).toFixed(2) + " V" : "--"
        }
        InfoRow {
            width: nowGrid.cell
            visible: Number(SystemStats.bat.temp) > 0
            label: "Pack temp"
            // sysfs reports this one in tenths of a degree
            value: (Number(SystemStats.bat.temp) / 10).toFixed(1) + "°C"
        }
    }

    // --- the pack -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "THE PACK" }

    // Wear is the headline of the pack, so it gets a level of its own: a
    // pack at 58% of design is a pack that will surprise you
    BarRow {
        visible: page.present
        label: "Capacity left"
        sublabel: SystemStats.batFullWh > 0 && SystemStats.batDesignWh > 0
            ? SystemStats.batFullWh.toFixed(1) + " of " + SystemStats.batDesignWh.toFixed(1) + " Wh designed" : ""
        value: SystemStats.batHealth > 0 ? Format.pct(SystemStats.batHealth) : "n/a"
        fraction: Math.max(0, SystemStats.batHealth)
        critical: SystemStats.batHealth > 0 && SystemStats.batHealth < 0.7
    }

    Grid {
        id: packGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow {
            width: packGrid.cell
            label: "Charge cycles"
            // plenty of packs never report this; 0 means "not counted", not
            // "never charged"
            value: Number(SystemStats.bat.cycle_count) > 0 ? String(SystemStats.bat.cycle_count) : "not reported"
        }
        InfoRow { width: packGrid.cell; label: "Reported health"; value: String(SystemStats.bat.health || "--") }
        InfoRow { width: packGrid.cell; label: "Manufacturer"; value: String(SystemStats.bat.manufacturer || "--") }
        InfoRow { width: packGrid.cell; label: "Model"; value: String(SystemStats.bat.model_name || "--") }
        InfoRow { width: packGrid.cell; label: "Chemistry"; value: String(SystemStats.bat.technology || "--") }
        InfoRow {
            width: packGrid.cell
            visible: SystemStats.bat.manufacture_year !== undefined
            label: "Made"
            value: SystemStats.bat.manufacture_year + "-"
                + String(SystemStats.bat.manufacture_month).padStart(2, "0") + "-"
                + String(SystemStats.bat.manufacture_day).padStart(2, "0")
        }
    }

    // --- profile ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "POWER PROFILE" }

    Item {
        width: parent.width
        height: Theme.rowHeightTall

        Text {
            anchors.left: parent.left
            anchors.right: profileSeg.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: "Battery life against sustained clocks"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        FlyoutSegmented {
            id: profileSeg
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            fill: false
            model: PpdProfile.choices
            current: PpdProfile.profile
            enabled: !PpdProfile.busy
            onPicked: v => PpdProfile.set(v)
        }
    }

    Grid {
        id: govGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow { width: govGrid.cell; label: "Governor"; value: SystemStats.governor || "--" }
        InfoRow {
            width: govGrid.cell
            visible: SystemStats.epp !== ""
            label: "Energy preference"
            value: SystemStats.epp
        }
    }

    // --- session ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SESSION" }

    Grid {
        id: sessGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow { width: sessGrid.cell; label: "Uptime"; value: Format.duration(SystemStats.uptimeSec) }
        InfoRow {
            width: sessGrid.cell
            label: "Booted"
            value: Qt.formatDateTime(SystemStats.bootTime, "ddd d MMM, HH:mm")
        }
    }
    // systemd-analyze's line is too long for half the width
    InfoRow { label: "Boot took"; value: SystemSpecs.bootLine || "--" }

    FlyoutRow {
        leadingIcon: "󰒲"
        label: "Idle and lid"
        note: "When the screen dims, locks and the machine sleeps"
        trailing: "Settings  󰅂"
        onActivated: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "power"])
    }
    // sleeping cuts whatever's running off, so it asks first
    property bool suspendArmed: false
    Timer { id: suspendDisarm; interval: 3000; onTriggered: page.suspendArmed = false }
    FlyoutRow {
        leadingIcon: "󰤄"
        label: page.suspendArmed ? "Suspend now?" : "Suspend"
        alert: page.suspendArmed
        note: "Sleep until a key or the lid wakes it"
        onActivated: {
            if (!page.suspendArmed) { page.suspendArmed = true; suspendDisarm.restart(); return }
            page.suspendArmed = false
            Quickshell.execDetached(["systemctl", "suspend"])
        }
    }
    FlyoutRow {
        leadingIcon: "󰄧"
        label: "Power history"
        note: "upower's record of charge and draw"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "command -v upower >/dev/null && upower -d || cat /sys/class/power_supply/BAT*/uevent; read -r _"])
    }
}
