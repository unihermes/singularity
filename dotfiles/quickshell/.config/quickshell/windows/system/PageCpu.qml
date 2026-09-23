// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageCpu.qml
//
// The processor: what it is, how it's being scheduled, and what every
// thread is doing right now. The per-core bars are the point of the page --
// an average of 25% across eight threads is a very different machine from
// one thread pinned at 100%, and only the bars tell the two apart.

import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "CPU"
    subtitle: SystemSpecs.cpuModel || "--"

    Gauge {
        label: "Total"
        fraction: SystemStats.cpu
        value: SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--"
        critical: SystemStats.cpu >= 0.9
    }

    Spark {
        series: [{ values: SystemStats.cpuHistory, color: Theme.text, fill: true }]
        ceiling: 1
        caption: "60s · peak " + (SystemStats.cpuHistory.length > 0
            ? Format.pct(Math.max.apply(null, SystemStats.cpuHistory)) : "--")
    }

    // --- per core ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "THREADS" }

    // A grid of one bar per thread rather than the single strip the old
    // window had: with a label and a clock against each, a pinned thread
    // can be named instead of just counted.
    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        rowSpacing: Theme.spaceXs

        readonly property int cellWidth: (width - columnSpacing) / 2

        Repeater {
            model: SystemStats.cores

            Item {
                required property int index
                required property var modelData

                width: parent.cellWidth
                height: Theme.rowHeight

                Text {
                    id: coreLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fs(34)
                    text: "#" + index
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }

                Meter {
                    anchors.left: coreLabel.right
                    anchors.right: corePct.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    fraction: modelData
                    fillColor: modelData >= 0.9 ? Theme.alert : Theme.meterFill
                }

                Text {
                    id: corePct
                    anchors.right: coreMhz.left
                    anchors.rightMargin: Theme.spaceL
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fs(38)
                    horizontalAlignment: Text.AlignRight
                    text: Format.pct(modelData)
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }

                Text {
                    id: coreMhz
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fs(56)
                    horizontalAlignment: Text.AlignRight
                    text: SystemStats.coreMhz[index] !== undefined
                        ? (SystemStats.coreMhz[index] / 1000).toFixed(2) + "G" : ""
                    color: Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    // --- scheduling ---------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SCHEDULING" }

    InfoRow {
        label: "Load average"
        value: SystemStats.load1.toFixed(2) + "  ·  " + SystemStats.load5.toFixed(2)
            + "  ·  " + SystemStats.load15.toFixed(2) + "   (1 · 5 · 15 min)"
        valueColor: SystemStats.cores.length > 0 && SystemStats.load1 > SystemStats.cores.length
            ? Theme.alert : undefined
    }
    InfoRow {
        label: "Runnable"
        value: SystemStats.procRunning + " of " + SystemStats.threadTotal + " threads"
    }
    InfoRow { label: "Governor"; value: SystemStats.governor || "--" }
    InfoRow {
        visible: SystemStats.epp !== ""
        label: "Energy preference"
        value: SystemStats.epp
    }
    InfoRow {
        label: "Power profile"
        value: PpdProfile.profile !== "" ? PpdProfile.profile : "not available"
    }
    InfoRow { label: "Scaling driver"; value: SystemSpecs.cpuDriver || "--" }

    // --- silicon ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SILICON" }

    InfoRow { label: "Model";  value: SystemSpecs.cpuModel || "--" }
    InfoRow { label: "Vendor"; value: SystemSpecs.cpuVendor || "--" }
    InfoRow {
        label: "Topology"
        value: SystemSpecs.cpuCores > 0
            ? SystemSpecs.cpuCores + " cores  ·  " + SystemSpecs.cpuThreads + " threads"
            : SystemStats.cores.length + " threads"
    }
    InfoRow {
        label: "Clock range"
        value: SystemSpecs.cpuMaxMhz > 0
            ? (SystemSpecs.cpuMinMhz / 1000).toFixed(2) + " – "
              + (SystemSpecs.cpuMaxMhz / 1000).toFixed(2) + " GHz" : "--"
    }
    InfoRow {
        label: "Clock now"
        value: SystemStats.cpuMhz > 0
            ? (SystemStats.cpuMhz / 1000).toFixed(2) + " GHz avg  ·  "
              + (SystemStats.cpuMhzPeak / 1000).toFixed(2) + " GHz peak" : "--"
    }
    InfoRow { label: "Cache"; value: SystemSpecs.cpuCache || "--" }
    InfoRow {
        label: "Package temp"
        value: SystemStats.tempC >= 0 ? Math.round(SystemStats.tempC) + "°C" : "no sensor"
        valueColor: SystemStats.tempC >= 90 ? Theme.alert : undefined
    }

    // --- heaviest -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "HEAVIEST PROCESSES" }

    ProcessTable { reserveRows: 5 }
}
