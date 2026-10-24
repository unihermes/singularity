// Singularity - Quickshell
// ~/.config/quickshell/desktop/StatsWidget.qml
//
// A ring each for the CPU, the GPU (NVIDIA's load, from Cooling, on
// desktops), memory and the CPU's temperature: two by two when small, in a
// row when medium, and over the last minute of CPU and the memory in use
// when large. A reading the machine can't give is left out.

import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

GlassCard {
    id: root

    readonly property var readings: [
        { label: "CPU", frac: SystemStats.cpu, value: Format.pct(SystemStats.cpu), shown: true },
        { label: "GPU", frac: Cooling.gpuLoad / 100, value: Cooling.gpuLoad + "%", shown: Cooling.gpuLoad >= 0 },
        { label: "RAM", frac: SystemStats.mem, value: Format.pct(SystemStats.mem), shown: SystemStats.memTotalKb > 0 },
        { label: "TEMP", frac: SystemStats.tempC / 100, value: Math.round(SystemStats.tempC) + "°", shown: SystemStats.tempC >= 0 }
    ].filter(r => r.shown)
    // which rings show, apart from their readings, so the rings aren't
    // rebuilt each second
    readonly property string shownKey: readings.map(r => r.label).join(",")
    readonly property var labels: shownKey.split(",")

    Grid {
        id: rings
        columns: root.small ? 2 : root.labels.length
        readonly property real ring: root.small
            ? Math.floor((parent.height - Theme.fit(8)) / 2)
            : Math.min(Theme.fit(76), (parent.width - (columns - 1) * Theme.fit(12)) / columns)
        spacing: root.small ? Theme.fit(8) : (parent.width - columns * ring) / Math.max(1, columns - 1)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: root.large ? undefined : parent.verticalCenter

        Repeater {
            model: root.labels
            Ring {
                required property string modelData
                required property int index
                readonly property var reading: root.readings[index] || { frac: 0, value: "" }
                width: rings.ring
                fraction: reading.frac
                value: reading.value
                label: modelData
                fill: root.accent
                track: root.track
                ink: root.fg
                inkDim: root.fgDim
                font: root.font
            }
        }
    }

    Column {
        id: history
        visible: root.large
        anchors.top: rings.bottom
        anchors.topMargin: Theme.fit(16)
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Theme.fit(6)

        GlassText {
            id: caption
            card: root
            px: Theme.fit(12)
            text: "CPU · LAST MINUTE"
            color: root.fgDim
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        Spark {
            width: parent.width
            height: history.height - caption.height - memRow.height - history.spacing * 2
            bare: true
            series: [{ values: SystemStats.cpuHistory, color: root.accent, fill: true }]
            ceiling: 1
        }
        Item {
            id: memRow
            width: parent.width
            height: mem.height
            GlassText {
                id: mem
                card: root
                px: Theme.fit(13)
                text: "Memory"
                color: root.fgDim
            }
            GlassText {
                anchors.right: parent.right
                card: root
                px: Theme.fit(13)
                text: Format.bytes(SystemStats.memUsedKb * 1024) + " of " + Format.bytes(SystemStats.memTotalKb * 1024)
            }
        }
    }
}
