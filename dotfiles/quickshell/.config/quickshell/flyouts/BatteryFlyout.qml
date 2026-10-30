// Singularity - Quickshell
// ~/.config/quickshell/flyouts/BatteryFlyout.qml
//
// The level large with the time left and the draw beside it, the charge
// through the day as a graph, then the power profile as one strip and the
// battery's health, then Settings.

import Quickshell.Services.UPower
import QtQuick
import "../services"
import "../services/Format.js" as Format

FlyoutPanel {
    id: batteryFlyout
    flyout: "battery"
    menuWidth: Theme.flyoutMenuWidth
    // last module in the bar -- run it into the right corner
    edgeMargin: 0

    readonly property int chargeState: Battery.present ? Battery.device.state : UPowerDeviceState.Unknown

    // the state in the Power page's words, and the time UPower gives for it
    readonly property string stateWords: chargeState === UPowerDeviceState.Charging ? "Charging"
        : chargeState === UPowerDeviceState.Discharging ? "On battery"
        : chargeState === UPowerDeviceState.FullyCharged ? "Full"
        : "Not charging"
    readonly property string timeWords: {
        var d = Battery.device
        if (chargeState === UPowerDeviceState.Discharging && d.timeToEmpty > 0)
            return Format.duration(d.timeToEmpty) + " left"
        if (chargeState === UPowerDeviceState.Charging && d.timeToFull > 0)
            return Format.duration(d.timeToFull) + " to full"
        return ""
    }

    FlyoutHeading { text: "BATTERY" }

    Item {
        width: parent.width
        implicitHeight: Math.max(level.implicitHeight, side.implicitHeight)

        Text {
            id: level
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.present ? Battery.percent + "%" : "—"
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontHero
        }
        Column {
            id: side
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.right: parent.right
                text: [batteryFlyout.stateWords, batteryFlyout.timeWords].filter(t => t !== "").join(" · ")
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Text {
                anchors.right: parent.right
                visible: Battery.present && Battery.device.changeRate !== 0
                text: visible ? Math.abs(Battery.device.changeRate).toFixed(1) + " W" : ""
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    // the charge since the oldest reading kept (a day at most), across the
    // whole width, charging stretches shaded
    TimeGraph {
        readonly property var h: Battery.history
        visible: h.length > 1
        height: Theme.row(64)
        from: visible ? h[0].t : 0
        to: visible ? h[h.length - 1].t : 1
        points: h
        lineColor: Theme.good
        spans: {
            var out = []
            for (var i = 0; i < h.length - 1; i++)
                if (h[i].c) out.push({ t0: h[i].t, t1: h[i + 1].t })
            return out
        }
    }

    FlyoutRow {
        visible: PpdProfile.profile === ""
        label: "power-profiles-daemon not answering"
        enabled: false
    }

    FlyoutSegmented {
        visible: PpdProfile.profile !== ""
        model: PpdProfile.choices
        current: PpdProfile.profile
        onPicked: v => PpdProfile.set(v)
    }

    FlyoutRow {
        visible: Battery.present && Battery.device.healthSupported
        label: "Health"
        trailing: visible ? Math.round(Battery.device.healthPercentage) + "%" : ""
        trailingIsValue: true
        enabled: false
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: scope.openSettings("power")
    }
}
