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
import Quickshell.Io
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

    Gauge {
        label: "Charge"
        available: page.present
        fraction: page.percent / 100
        value: page.present ? page.percent + "%" : "--"
        critical: page.present && !SystemStats.batCharging && page.percent <= 15
    }

    // Wear is the headline of this page, so it gets a bar of its own rather
    // than a line in a list: a pack at 58% of design is a pack that will
    // surprise you, and a number in a table doesn't say that loudly enough.
    Gauge {
        label: "Health"
        available: page.present && SystemStats.batHealth > 0
        fraction: SystemStats.batHealth
        value: SystemStats.batHealth > 0 ? Format.pct(SystemStats.batHealth) : "n/a"
        critical: SystemStats.batHealth > 0 && SystemStats.batHealth < 0.7
    }

    // --- right now ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "RIGHT NOW" }

    InfoRow {
        label: "State"
        value: page.present ? String(SystemStats.bat.status || "--") : "--"
    }
    InfoRow {
        label: "Mains adapter"
        value: SystemStats.acOnline ? "connected" : "disconnected"
    }
    InfoRow {
        label: "Draw"
        value: SystemStats.batWatts > 0 ? SystemStats.batWatts.toFixed(1) + " W" : "--"
    }
    InfoRow {
        label: "Estimate"
        value: SystemStats.batHours > 0
            ? Format.duration(SystemStats.batHours * 3600)
              + (SystemStats.batCharging ? " to full" : " remaining")
            : "--"
    }
    InfoRow {
        label: "Charge held"
        value: SystemStats.batNowWh > 0
            ? SystemStats.batNowWh.toFixed(1) + " Wh  of  " + SystemStats.batFullWh.toFixed(1) + " Wh"
            : "--"
    }
    InfoRow {
        label: "Voltage"
        value: Number(SystemStats.bat.voltage_now) > 0
            ? (Number(SystemStats.bat.voltage_now) / 1e6).toFixed(2) + " V" : "--"
    }
    InfoRow {
        visible: Number(SystemStats.bat.temp) > 0
        label: "Pack temperature"
        // sysfs reports this one in tenths of a degree
        value: (Number(SystemStats.bat.temp) / 10).toFixed(1) + "°C"
    }

    // --- the pack -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "THE PACK" }

    InfoRow {
        label: "Design capacity"
        value: SystemStats.batDesignWh > 0 ? SystemStats.batDesignWh.toFixed(1) + " Wh" : "--"
    }
    InfoRow {
        label: "Capacity now"
        value: SystemStats.batFullWh > 0 ? SystemStats.batFullWh.toFixed(1) + " Wh" : "--"
    }
    InfoRow {
        label: "Wear"
        value: SystemStats.batHealth > 0
            ? Format.pct(1 - SystemStats.batHealth) + " lost since new" : "--"
        valueColor: SystemStats.batHealth > 0 && SystemStats.batHealth < 0.7 ? Theme.alert : undefined
    }
    InfoRow {
        label: "Charge cycles"
        // plenty of packs never report this; 0 means "not counted", not
        // "never charged"
        value: Number(SystemStats.bat.cycle_count) > 0
            ? String(SystemStats.bat.cycle_count) : "not reported"
    }
    InfoRow {
        label: "Manufacturer"
        value: String(SystemStats.bat.manufacturer || "--")
    }
    InfoRow { label: "Model";      value: String(SystemStats.bat.model_name || "--") }
    InfoRow { label: "Chemistry";  value: String(SystemStats.bat.technology || "--") }
    InfoRow {
        visible: SystemStats.bat.manufacture_year !== undefined
        label: "Manufactured"
        value: SystemStats.bat.manufacture_year + "-"
            + String(SystemStats.bat.manufacture_month).padStart(2, "0") + "-"
            + String(SystemStats.bat.manufacture_day).padStart(2, "0")
    }
    InfoRow {
        label: "Reported health"
        value: String(SystemStats.bat.health || "--")
    }

    // --- profile ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "POWER PROFILE" }

    Text {
        width: parent.width
        text: "The profile trades battery life against sustained clocks. It is the same "
            + "setting the Control Centre exposes; the CPU governor it drives is on the CPU page."
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    FlyoutSegmented {
        fill: false
        model: [{ value: "power-saver", text: "Power saver" }, { value: "balanced", text: "Balanced" },
            { value: "performance", text: "Performance" }]
        current: PpdProfile.profile
        enabled: !PpdProfile.busy
        onPicked: v => PpdProfile.set(v)
    }

    InfoRow { label: "Governor"; value: SystemStats.governor || "--" }
    InfoRow {
        visible: SystemStats.epp !== ""
        label: "Energy preference"
        value: SystemStats.epp
    }

    // --- session ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SESSION" }

    InfoRow { label: "Uptime"; value: Format.duration(SystemStats.uptimeSec) }
    InfoRow {
        label: "Booted"
        value: Qt.formatDateTime(SystemStats.bootTime, "ddd d MMM yyyy, HH:mm")
    }
    InfoRow {
        label: "Boot took"
        value: SystemSpecs.bootLine || "--"
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "Idle settings"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "power"])
        }
        FlyoutChip {
            text: "Suspend"
            onClicked: Quickshell.execDetached(["systemctl", "suspend"])
        }
        FlyoutChip {
            text: "Power history"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "command -v upower >/dev/null && upower -d || cat /sys/class/power_supply/BAT*/uevent; read -r _"])
        }
    }
}
