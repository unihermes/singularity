// Singularity - Quickshell
// ~/.config/quickshell/desktop/StatsWidget.qml
//
// A bar each for the CPU, the GPU (NVIDIA's load, from Cooling, on
// desktops), memory and the CPU's temperature, with its label and value;
// large adds the last minute of CPU and the memory in use under them. A reading the machine can't give is left out.

import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

WidgetCard {
    id: root

    readonly property var readings: [
        { label: "CPU", frac: SystemStats.cpu, value: Format.pct(SystemStats.cpu), shown: true },
        { label: "GPU", frac: Cooling.gpuLoad / 100, value: Cooling.gpuLoad + "%", shown: Cooling.gpuLoad >= 0 },
        { label: "RAM", frac: SystemStats.mem, value: Format.pct(SystemStats.mem), shown: SystemStats.memTotalKb > 0 },
        { label: "TEMP", frac: SystemStats.tempC / 100, value: Math.round(SystemStats.tempC) + "°", shown: SystemStats.tempC >= 0 }
    ].filter(r => r.shown)
    // which bars show, apart from their readings, so the bars aren't
    // rebuilt each second
    readonly property string shownKey: readings.map(r => r.label).join(",")
    readonly property var labels: shownKey.split(",")

    // a bar each: label and value over the bar when small, all three on one
    // line otherwise; the rows share the top (large) or the whole widget
    Column {
        id: rows
        width: parent.width
        height: root.large ? implicitHeight : parent.height
        spacing: root.large ? Theme.fit(10)
            : (parent.height - root.labels.length * rowHeight) / Math.max(1, root.labels.length - 1)
        readonly property real rowHeight: root.small ? Theme.fit(26) : Theme.fit(20)

        Repeater {
            model: root.labels
            Item {
                required property string modelData
                required property int index
                readonly property var reading: root.readings[index] || { frac: 0, value: "" }
                width: rows.width
                height: rows.rowHeight

                WidgetText {
                    id: label
                    anchors.top: root.small ? parent.top : undefined
                    anchors.verticalCenter: root.small ? undefined : parent.verticalCenter
                    width: Theme.fit(48)
                    card: root
                    px: Theme.fit(13)
                    text: modelData
                    color: root.fgDim
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
                WidgetText {
                    id: value
                    anchors.right: parent.right
                    anchors.top: root.small ? parent.top : undefined
                    anchors.verticalCenter: root.small ? undefined : parent.verticalCenter
                    card: root
                    px: Theme.fit(13)
                    text: parent.reading.value
                }
                Rectangle {
                    x: root.small ? 0 : label.width
                    width: root.small ? parent.width : parent.width - label.width - Theme.fit(56)
                    y: root.small ? parent.height - height : (parent.height - height) / 2
                    height: Theme.fit(root.small ? 6 : 8)
                    radius: height / 2
                    color: root.track

                    Rectangle {
                        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, parent.parent.reading.frac)))
                        height: parent.height
                        radius: parent.radius
                        color: root.accent
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Column {
        id: history
        visible: root.large
        anchors.top: rows.bottom
        anchors.topMargin: Theme.fit(16)
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Theme.fit(6)

        WidgetText {
            id: caption
            card: root
            px: Theme.fit(13)
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
            WidgetText {
                id: mem
                card: root
                px: Theme.fit(13)
                text: "Memory"
                color: root.fgDim
            }
            WidgetText {
                anchors.right: parent.right
                card: root
                px: Theme.fit(13)
                text: Format.bytes(SystemStats.memUsedKb * 1024) + " of " + Format.bytes(SystemStats.memTotalKb * 1024)
            }
        }
    }
}
