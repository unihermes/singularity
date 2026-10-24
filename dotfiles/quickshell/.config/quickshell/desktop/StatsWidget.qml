// Singularity - Quickshell
// ~/.config/quickshell/desktop/StatsWidget.qml
//
// The last minute of CPU as a graph, then a meter each for the CPU, the
// GPU (NVIDIA's load, from Cooling, on desktops), memory and the CPU's
// temperature. A reading the machine can't give is left out.

import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

WidgetFrame {
    id: root

    FlyoutHeading {
        text: "SYSTEM"
        hints: ["1 min"]
    }

    Spark {
        width: parent.width
        height: Theme.fit(48)
        series: [{ values: SystemStats.cpuHistory, color: Theme.accent, fill: true }]
        ceiling: 1
    }

    Repeater {
        model: ["CPU", "GPU", "RAM", "Temp"]

        Item {
            required property string modelData
            readonly property var reading: modelData === "CPU"
                ? { frac: SystemStats.cpu, value: Format.pct(SystemStats.cpu), shown: true }
                : modelData === "GPU"
                ? { frac: Cooling.gpuLoad / 100, value: Cooling.gpuLoad + "%", shown: Cooling.gpuLoad >= 0 }
                : modelData === "RAM"
                ? { frac: SystemStats.mem, value: Format.bytes(SystemStats.memUsedKb * 1024), shown: SystemStats.memTotalKb > 0 }
                : { frac: SystemStats.tempC / 100, value: Math.round(SystemStats.tempC) + "°", shown: SystemStats.tempC >= 0 }
            visible: reading.shown
            width: parent.width
            height: Theme.rowHeightDense

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(48)
                text: modelData
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
            Meter {
                anchors.left: label.right
                anchors.right: value.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                fraction: parent.reading.frac
            }
            Text {
                id: value
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(72)
                horizontalAlignment: Text.AlignRight
                text: parent.reading.value
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
