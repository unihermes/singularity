// Singularity - Quickshell
// ~/.config/quickshell/flyouts/CoolingFlyout.qml
//
// Temperatures and fans, from the Cooling singleton: CPU and GPU as two
// tiles with their reading large, the last three minutes of both as one
// graph, the drive under it, then the fans folded into one line that
// opens in place.

import QtQuick
import "../services"

FlyoutPanel {
    id: coolingFlyout
    flyout: "cooling"
    menuWidth: Theme.flyoutMenuWidth

    // the System window, for More in System
    required property var systemWin

    property bool fansOpen: false
    onOpenChanged: fansOpen = false

    function degrees(c) { return c < 0 ? "—" : Math.round(c) + "°C" }
    // 30 °C empty, 100 °C full
    function level(c) { return c < 0 ? 0 : Math.max(0, Math.min(1, (c - 30) / 70)) }

    FlyoutHeading { text: "COOLING  " + coolingFlyout.degrees(Cooling.hottest) }

    TileGrid {
        visible: Cooling.cpuC >= 0 || Cooling.gpuC >= 0
        columns: 2

        FlyoutTile {
            width: parent.cell
            title: coolingFlyout.degrees(Cooling.cpuC)
            big: true
            caption: "CPU"
            Meter {
                width: parent.width
                fraction: coolingFlyout.level(Cooling.cpuC)
                fillColor: Cooling.cpuC >= Cooling.hotC ? Theme.alert : Theme.meterFill
            }
        }
        FlyoutTile {
            width: parent.cell
            title: coolingFlyout.degrees(Cooling.gpuC)
            big: true
            caption: ["GPU", Cooling.gpuLoad >= 0 ? Cooling.gpuLoad + "%" : "",
                      Cooling.gpuWatts >= 0 ? Math.round(Cooling.gpuWatts) + " W" : ""]
                .filter(s => s !== "").join(" · ")
            Meter {
                width: parent.width
                fraction: coolingFlyout.level(Cooling.gpuC)
                fillColor: Cooling.gpuC >= Cooling.hotC ? Theme.alert : Theme.meterFill
            }
        }
    }

    Spark {
        visible: Cooling.cpuHistory.length > 1
        height: Theme.row(56)
        floor: 30
        ceiling: 100
        historyLength: Cooling.historyLength
        series: [
            { values: Cooling.gpuHistory, color: Theme.subtext, fill: false },
            { values: Cooling.cpuHistory, color: Theme.text, fill: true },
        ]
    }

    // the graph's time axis, with the drive in the middle
    Item {
        visible: Cooling.cpuHistory.length > 1
        width: parent.width
        implicitHeight: axisLeft.implicitHeight
        Text {
            id: axisLeft
            anchors.left: parent.left
            text: "3 min ago"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Cooling.driveC >= 0
            text: "Drive " + coolingFlyout.degrees(Cooling.driveC)
            color: Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
        Text {
            anchors.right: parent.right
            text: "now"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    FlyoutDivider {}

    // the fans as one line; a click opens them in place
    readonly property var spinning: Cooling.fans.filter(f => f.rpm > 0)
    FlyoutRow {
        label: "Fans"
        enabled: Cooling.fans.length > 0 || Cooling.gpuFan >= 0
        trailing: Cooling.fans.length === 0 && Cooling.gpuFan < 0 ? "None reporting"
            : (spinning.length > 0 ? spinning.length + " spinning" : "All stopped")
              + "  " + (coolingFlyout.fansOpen ? "󰅀" : "󰅂")
        onActivated: coolingFlyout.fansOpen = !coolingFlyout.fansOpen
    }

    Repeater {
        model: coolingFlyout.fansOpen ? Cooling.fans : []

        FlyoutRow {
            required property var modelData
            label: modelData.name
            note: modelData.duty >= 0 ? modelData.duty + "%" : ""
            trailing: modelData.rpm > 0 ? modelData.rpm + " rpm" : "Stopped"
            trailingIsValue: true
            enabled: false
        }
    }

    // the card's own fans, which stop below about 60 °C
    FlyoutRow {
        visible: coolingFlyout.fansOpen && Cooling.gpuFan >= 0
        label: "GPU fans"
        trailing: Cooling.gpuFan > 0 ? Cooling.gpuFan + "%" : "Stopped"
        trailingIsValue: true
        enabled: false
    }

    FlyoutDivider {}

    FlyoutRow {
        visible: Cooling.coolerControl
        label: "Fan curves in CoolerControl"
        trailing: "󰁔"
        onActivated: {
            scope.openFlyout = ""
            Cooling.openCoolerControl()
        }
    }

    FlyoutRow {
        label: "More in System"
        trailing: "󰁔"
        onActivated: {
            scope.openFlyout = ""
            coolingFlyout.systemWin.open("hardware")
        }
    }
}
