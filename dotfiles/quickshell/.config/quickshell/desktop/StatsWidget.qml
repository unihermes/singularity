// Singularity - Quickshell
// ~/.config/quickshell/desktop/StatsWidget.qml
//
// A bar each for the CPU, the GPU (NVIDIA's load, from Cooling, on
// desktops), memory, the CPU's temperature and the root disk, with its
// label and value; large adds the last minute of CPU and the memory and
// disk in use under them. A reading the machine can't give is left out.

import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

WidgetCard {
    id: root

    readonly property real disk: SystemStats.diskSize > 0 ? SystemStats.diskUsed / SystemStats.diskSize : 0
    readonly property var readings: [
        { label: "CPU", frac: SystemStats.cpu, value: Format.pct(SystemStats.cpu), shown: true },
        { label: "GPU", frac: Cooling.gpuLoad / 100, value: Cooling.gpuLoad + "%", shown: Cooling.gpuLoad >= 0 },
        { label: "RAM", frac: SystemStats.mem, value: Format.pct(SystemStats.mem), shown: SystemStats.memTotalKb > 0 },
        { label: "TEMP", frac: SystemStats.tempC / 100, value: Math.round(SystemStats.tempC) + "°", shown: SystemStats.tempC >= 0 },
        { label: "DISK", frac: disk, value: Format.pct(disk), shown: SystemStats.diskSize > 0 }
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
        readonly property real rowHeight: root.small ? Theme.fit(24) : Theme.fit(20)

        Repeater {
            model: root.labels
            Item {
                required property string modelData
                required property int index
                readonly property var reading: root.readings[index] || { frac: 0, value: "" }
                width: rows.width
                height: rows.rowHeight

                WidgetCaption {
                    id: label
                    anchors.top: root.small ? parent.top : undefined
                    anchors.verticalCenter: root.small ? undefined : parent.verticalCenter
                    width: Theme.fit(48)
                    card: root
                    text: modelData
                    color: root.fgDim
                }
                WidgetText {
                    id: value
                    anchors.right: parent.right
                    anchors.top: root.small ? parent.top : undefined
                    anchors.verticalCenter: root.small ? undefined : parent.verticalCenter
                    card: root
                    px: root.textCaption
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

        WidgetCaption {
            id: caption
            card: root
            text: "CPU · last minute"
            color: root.fgDim
        }
        Spark {
            width: parent.width
            height: history.height - caption.height - history.spacing
                - [memRow, diskRow].reduce((h, r) => h + (r.visible ? r.height + history.spacing : 0), 0)
            bare: true
            series: [{ values: SystemStats.cpuHistory, color: root.accent, fill: true }]
            ceiling: 1
        }
        // what's in use, of how much
        Item {
            id: memRow
            visible: SystemStats.memTotalKb * 1024 > 0
            width: parent.width
            height: memRowUse.height
            WidgetText {
                card: root
                px: root.textCaption
                text: "Memory"
                color: root.fgDim
            }
            WidgetText {
                id: memRowUse
                anchors.right: parent.right
                card: root
                px: root.textCaption
                text: Format.bytes(SystemStats.memUsedKb * 1024) + " of " + Format.bytes(SystemStats.memTotalKb * 1024)
            }
        }
        Item {
            id: diskRow
            visible: SystemStats.diskSize > 0
            width: parent.width
            height: diskRowUse.height
            WidgetText {
                card: root
                px: root.textCaption
                text: "Disk"
                color: root.fgDim
            }
            WidgetText {
                id: diskRowUse
                anchors.right: parent.right
                card: root
                px: root.textCaption
                text: Format.bytes(SystemStats.diskUsed) + " of " + Format.bytes(SystemStats.diskSize)
            }
        }
    }
}
