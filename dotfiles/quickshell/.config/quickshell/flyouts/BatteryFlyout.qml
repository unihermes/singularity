// Neutrino - Quickshell
// ~/.config/quickshell/BatteryFlyout.qml
//
// Split out of shell.qml. Needs bar's battery readouts.

import Quickshell.Services.UPower
import QtQuick
import "../services"

FlyoutPanel {
    id: batteryFlyout
    flyout: "battery"
    menuWidth: 240
    // last module in the bar -- run it into the right corner
    edgeMargin: 0

    required property var bar

    function fmtSeconds(s) {
        if (!s || s <= 0) return "--"
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    FlyoutHeading {
        text: "BATTERY  " + (bar.hasBattery ? bar.batteryPercent() + "%" : "--")
    }

    FlyoutRow {
        label: UPower.onBattery ? "Discharging" : "Charging"
        trailing: UPower.onBattery
            ? batteryFlyout.fmtSeconds(bar.batt ? bar.batt.timeToEmpty : 0) + " left"
            : batteryFlyout.fmtSeconds(bar.batt ? bar.batt.timeToFull : 0) + " to full"
        enabled: false
    }

    FlyoutRow {
        label: "Draw"
        trailing: bar.batt ? Math.abs(bar.batt.changeRate).toFixed(1) + " W" : "--"
        enabled: false
    }

    FlyoutRow {
        label: "Health"
        trailing: (bar.batt && bar.batt.healthSupported)
            ? Math.round(bar.batt.healthPercentage) + "%"
            : "n/a"
        enabled: false
    }

    FlyoutHeading { text: "POWER PROFILE" }

    FlyoutRow {
        visible: PpdProfile.profile === ""
        label: "power-profiles-daemon not answering"
        enabled: false
    }

    Repeater {
        model: [
            { name: "power-saver", label: "Power Saver" },
            { name: "balanced",    label: "Balanced" },
            { name: "performance", label: "Performance" },
        ]

        FlyoutRow {
            required property var modelData
            visible: PpdProfile.profile !== ""
            label: modelData.label
            highlighted: PpdProfile.profile === modelData.name
            trailing: highlighted ? "" : ""
            onActivated: PpdProfile.set(modelData.name)
        }
    }
}
