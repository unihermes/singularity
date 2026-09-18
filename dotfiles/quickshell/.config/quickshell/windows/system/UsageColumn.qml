// Singularity - Quickshell
// ~/.config/quickshell/windows/system/UsageColumn.qml
//
// The System window's left column: live usage gauges, per-core bars and
// the 60s CPU graph, then the network interface and throughput.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"

Column {
    id: column

    required property var stats

    spacing: Theme.spaceM

    FlyoutHeading { text: "USAGE" }

    Gauge {
        label: "CPU"
        fraction: column.stats.cpu
        value: column.stats.cpuHistory.length > 0 ? Format.pct(column.stats.cpu) : "--"
    }

    // one bar per core, under the CPU gauge's bar
    Item {
        width: parent.width
        height: Theme.rowHeightTall

        Row {
            id: coreRow
            x: Theme.fs(48)
            width: parent.width - Theme.fs(48) - Theme.fs(90) - Theme.spaceXl
            height: parent.height
            spacing: Theme.sp(3)
            readonly property int n: Math.max(1, column.stats.cores.length)

            Repeater {
                model: column.stats.cores

                Rectangle {
                    required property var modelData
                    width: (coreRow.width - (coreRow.n - 1) * coreRow.spacing) / coreRow.n
                    height: coreRow.height
                    radius: Math.min(2, Theme.radius)
                    color: Theme.meterTrack
                    border.width: Theme.borderWidth
                    border.color: Theme.meterStroke

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Math.max(modelData > 0 ? 2 : 0, parent.height * modelData)
                        radius: Math.min(2, Theme.radius)
                        color: Theme.meterFill


                        Behavior on height { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease } }
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(90)
            horizontalAlignment: Text.AlignRight
            // the busiest core, since an average hides a single
            // pinned thread
            text: column.stats.cores.length > 0
                ? "peak " + Format.pct(Math.max.apply(null, column.stats.cores)) : ""
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontSmall
        }
    }

    Spark {
        series: [{ values: column.stats.cpuHistory, color: Theme.text, fill: true }]
        ceiling: 1
        caption: "CPU · 60s"
    }

    Gauge {
        label: "RAM"
        fraction: column.stats.mem
        value: Format.pct(column.stats.mem)
        critical: column.stats.mem >= 0.9
    }

    Gauge {
        label: "Swap"
        fraction: column.stats.swap
        available: column.stats.swapTotalKb > 0
        value: column.stats.swapTotalKb > 0 ? Format.pct(column.stats.swap) : "none"
    }

    Gauge {
        label: "Disk"
        fraction: column.stats.diskSize > 0 ? column.stats.diskUsed / column.stats.diskSize : 0
        value: column.stats.diskSize > 0 ? Format.gib(column.stats.diskUsed) + " / " + Format.gib(column.stats.diskSize) : "--"
        critical: column.stats.diskSize > 0 && column.stats.diskUsed / column.stats.diskSize >= 0.9
    }

    Gauge {
        label: "Temp"
        // 100C spans the bar: Intel mobile chips throttle in the high
        // 90s, so a full bar means what it looks like it means
        fraction: column.stats.tempC / 100
        available: column.stats.tempC >= 0
        value: column.stats.tempC >= 0 ? Math.round(column.stats.tempC) + "°C" : "no sensor"
        critical: column.stats.tempC >= 90
    }

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "NETWORK" }

    InfoRow { label: "Interface"; value: column.stats.iface !== "" ? column.stats.iface : "offline" }
    InfoRow { label: "Type";      value: column.stats.connType !== "" ? column.stats.connType : "--" }
    InfoRow { label: "IP";        value: column.stats.ipAddr !== "" ? column.stats.ipAddr : "--" }
    InfoRow {
        visible: column.stats.connType === "Wi-Fi"
        label: "Signal"
        value: column.stats.signalDbm < 1000 ? column.stats.signalDbm + " dBm" : "--"
    }
    InfoRow { label: "Download";  value: "↓ " + Format.rate(column.stats.rxRate) }
    InfoRow { label: "Upload";    value: "↑ " + Format.rate(column.stats.txRate) }

    Spark {
        // Download bright and filled, upload dimmer on top. The
        // ceiling tracks the busiest second in view but never drops
        // below 64 KB/s, or an idle link would blow background chatter
        // up to full height and look like a transfer.
        readonly property real peak: Math.max(65536,
            Math.max.apply(null, column.stats.rxHistory.concat(column.stats.txHistory, [0])))
        series: [
            { values: column.stats.rxHistory, color: Theme.text, fill: true },
            { values: column.stats.txHistory, color: Theme.subtext, fill: false },
        ]
        // 15% headroom above the peak itself, or the peak sample
        // sits exactly on y=0 and its stroke bleeds into the
        // rounded border above the canvas margin.
        ceiling: peak * 1.15
        caption: "↓ ↑ · peak " + Format.rate(peak)
    }
}
