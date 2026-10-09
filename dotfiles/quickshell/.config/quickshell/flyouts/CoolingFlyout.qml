// Singularity - Quickshell
// ~/.config/quickshell/flyouts/CoolingFlyout.qml
//
// Temperatures and fans, from the Cooling singleton: the last three minutes
// of CPU and GPU as one graph, each reading as a row, then every fan.

import QtQuick
import "../services"

FlyoutPanel {
    id: coolingFlyout
    flyout: "cooling"
    menuWidth: 260

    // the System window, for More in System
    required property var systemWin

    function degrees(c) { return c < 0 ? "—" : Math.round(c) + "°C" }

    FlyoutHeading { text: "COOLING  " + coolingFlyout.degrees(Cooling.hottest) }

    Spark {
        visible: Cooling.cpuHistory.length > 1
        height: Theme.row(40)
        floor: 30
        ceiling: 100
        historyLength: Cooling.historyLength
        series: [
            { values: Cooling.gpuHistory, color: Theme.subtext, fill: false },
            { values: Cooling.cpuHistory, color: Theme.text, fill: true },
        ]
    }

    FlyoutRow {
        visible: Cooling.cpuC >= 0
        label: "CPU"
        trailing: coolingFlyout.degrees(Cooling.cpuC)
        trailingIsValue: true
        alert: Cooling.cpuC >= Cooling.hotC
        enabled: false
    }
    FlyoutRow {
        visible: Cooling.gpuC >= 0
        label: "GPU"
        note: [Cooling.gpuLoad >= 0 ? Cooling.gpuLoad + "%" : "",
               Cooling.gpuWatts >= 0 ? Math.round(Cooling.gpuWatts) + " W" : ""]
            .filter(s => s !== "").join(" · ")
        trailing: coolingFlyout.degrees(Cooling.gpuC)
        trailingIsValue: true
        alert: Cooling.gpuC >= Cooling.hotC
        enabled: false
    }
    FlyoutRow {
        visible: Cooling.driveC >= 0
        label: "Drive"
        trailing: coolingFlyout.degrees(Cooling.driveC)
        trailingIsValue: true
        enabled: false
    }

    FlyoutHeading { text: "FANS" }

    FlyoutRow {
        visible: Cooling.fans.length === 0 && Cooling.gpuFan < 0
        label: "No fan is reporting its speed"
        enabled: false
    }

    Repeater {
        model: Cooling.fans

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
        visible: Cooling.gpuFan >= 0
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
