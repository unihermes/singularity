// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BatteryFlyout.qml
//
// Split out of shell.qml.

import Quickshell.Services.UPower
import QtQuick
import "../services"

FlyoutPanel {
    id: batteryFlyout
    flyout: "battery"
    menuWidth: 240
    // last module in the bar -- run it into the right corner
    edgeMargin: 0

    function fmtSeconds(s) {
        if (!s || s <= 0) return "--"
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    FlyoutHeading {
        text: "BATTERY  " + (Battery.present ? Battery.percent + "%" : "--")
    }

    FlyoutRow {
        label: UPower.onBattery ? "Discharging" : "Charging"
        trailing: UPower.onBattery
            ? batteryFlyout.fmtSeconds(Battery.device ? Battery.device.timeToEmpty : 0) + " left"
            : batteryFlyout.fmtSeconds(Battery.device ? Battery.device.timeToFull : 0) + " to full"
        trailingIsValue: true
        enabled: false
    }

    FlyoutRow {
        label: "Draw"
        trailing: Battery.device ? Math.abs(Battery.device.changeRate).toFixed(1) + " W" : "--"
        trailingIsValue: true
        enabled: false
    }

    FlyoutRow {
        label: "Health"
        trailing: (Battery.device && Battery.device.healthSupported)
            ? Math.round(Battery.device.healthPercentage) + "%"
            : "n/a"
        trailingIsValue: true
        enabled: false
    }

    FlyoutHeading { text: "POWER PROFILE" }

    FlyoutRow {
        visible: PpdProfile.profile === ""
        label: "power-profiles-daemon not answering"
        enabled: false
    }

    Repeater {
        model: PpdProfile.profile !== "" ? PpdProfile.choices : []

        FlyoutRow {
            required property var modelData
            label: modelData.text
            highlighted: PpdProfile.profile === modelData.value
            onActivated: PpdProfile.set(modelData.value)
        }
    }
}
