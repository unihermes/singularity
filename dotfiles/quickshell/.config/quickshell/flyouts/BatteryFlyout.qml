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

    Column {
        id: historyChart
        width: parent.width
        spacing: Theme.spaceS
        visible: Battery.present
        property real now: Date.now()

        Timer {
            interval: 60000
            running: batteryFlyout.open
            repeat: true
            triggeredOnStart: true
            onTriggered: historyChart.now = Date.now()
        }

        Text {
            text: "Last 24 hours · shaded when plugged in"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }

        Item {
            width: parent.width
            height: Theme.row(80)

            Repeater {
                model: [100, 50, 0]
                Item {
                    required property int modelData
                    width: parent.width
                    y: chargeGraph.y + chargeGraph.height * (1 - modelData / 100)
                    Text {
                        anchors.verticalCenter: parent.top
                        text: modelData + "%"
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontCaption
                    }
                    Rectangle {
                        x: chargeGraph.x
                        width: chargeGraph.width
                        height: Theme.borderWidth
                        color: Theme.meterStroke
                    }
                }
            }

            TimeGraph {
                id: chargeGraph
                x: Theme.sp(36)
                y: Theme.fontCaption / 2
                width: parent.width - x
                height: parent.height - Theme.fontCaption
                bare: true
                showTicks: false
                fill: false
                from: historyChart.now - Battery.historyWindow
                to: historyChart.now
                points: Battery.history.filter(p => p.t >= from && p.t <= to)
                lineColor: Theme.good
                spans: {
                    var out = []
                    for (var i = 0; i < points.length - 1; i++) {
                        var a = points[i], b = points[i + 1]
                        if (a.c && b.t - a.t <= breakAfter)
                            out.push({ t0: a.t, t1: b.t })
                    }
                    return out
                }
            }

            Text {
                anchors.centerIn: chargeGraph
                visible: chargeGraph.points.length < 2
                text: "Collecting battery history…"
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontCaption
            }
        }

        Item {
            x: chargeGraph.x
            width: parent.width - x
            height: Theme.fontCaption + Theme.spaceXs
            Repeater {
                model: ["24h ago", "12h ago", "Now"]
                Text {
                    required property int index
                    required property string modelData
                    x: index === 0 ? 0 : index === 1 ? (parent.width - width) / 2 : parent.width - width
                    text: modelData
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }
            }
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
