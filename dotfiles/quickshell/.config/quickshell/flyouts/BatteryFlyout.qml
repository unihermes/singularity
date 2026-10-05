// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BatteryFlyout.qml
//
// Split out of shell.qml.

import Quickshell.Services.UPower
import QtQuick
import "../services"
import "../services/Format.js" as Format

FlyoutPanel {
    id: batteryFlyout
    flyout: "battery"
    menuWidth: 240
    // last module in the bar -- run it into the right corner
    edgeMargin: 0

    readonly property int chargeState: Battery.present ? Battery.device.state : UPowerDeviceState.Unknown

    FlyoutHeading {
        text: "BATTERY  " + (Battery.present ? Battery.percent + "%" : "—")
    }

    // the state in the Power page's words, and the time UPower gives for it
    FlyoutRow {
        label: batteryFlyout.chargeState === UPowerDeviceState.Charging ? "Charging"
            : batteryFlyout.chargeState === UPowerDeviceState.Discharging ? "On battery"
            : batteryFlyout.chargeState === UPowerDeviceState.FullyCharged ? "Full"
            : "Not charging"
        trailing: {
            var d = Battery.device
            if (batteryFlyout.chargeState === UPowerDeviceState.Discharging && d.timeToEmpty > 0)
                return Format.duration(d.timeToEmpty) + " left"
            if (batteryFlyout.chargeState === UPowerDeviceState.Charging && d.timeToFull > 0)
                return Format.duration(d.timeToFull) + " to full"
            return ""
        }
        trailingIsValue: true
        enabled: false
    }

    FlyoutRow {
        label: "Draw"
        trailing: Battery.present && Battery.device.changeRate !== 0
            ? Math.abs(Battery.device.changeRate).toFixed(1) + " W" : "—"
        trailingIsValue: true
        enabled: false
    }

    FlyoutRow {
        visible: Battery.present && Battery.device.healthSupported
        label: "Health"
        trailing: visible ? Math.round(Battery.device.healthPercentage) + "%" : ""
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

    FlyoutDivider {}

    FlyoutRow {
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("power")
    }
}
