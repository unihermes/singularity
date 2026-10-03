// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageCpu.qml
//
// The processor: what it is, how it's being scheduled, and what every
// thread is doing right now. The per-core bars are the point of the page --
// an average of 25% across eight threads is a very different machine from
// one thread pinned at 100%, and only the bars tell the two apart.

import Quickshell
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

    // the window, for the rows that open another page
    readonly property var win: {
        var p = page.parent
        while (p && p.currentPage === undefined) p = p.parent
        return p
    }
    function go(id) { if (win) win.select(id) }

    FlyoutHeading { text: "NOW" }

    // the total large, the clocks and the heat beside it, and its minute
    HeadCard {
        glyph: "󰻠"
        glyphColor: SystemStats.cpu >= 0.9 ? Theme.alert : Theme.textStrong
        title: SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) + " busy" : "--"
        lines: [
            SystemStats.cpuMhz > 0 ? (SystemStats.cpuMhz / 1000).toFixed(2) + " GHz average, "
                + (SystemStats.cpuMhzPeak / 1000).toFixed(2) + " GHz peak" : "",
            (SystemStats.tempC >= 0 ? Math.round(SystemStats.tempC) + "°C" : "")
                + (PpdProfile.profile !== "" ? (SystemStats.tempC >= 0 ? " · " : "") + PpdProfile.profile + " profile" : ""),
        ]
    }

    Spark {
        series: [{ values: SystemStats.cpuHistory, color: Theme.accent, fill: true }]
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
                    text: index
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
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
                    font.weight: Theme.weightBody
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
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    // --- scheduling ---------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SCHEDULING" }

    InfoRow {
        label: "Load (1, 5, 15 min)"
        // and what that is per thread, which is the figure that means
        // something: past 1.00, work is queueing
        value: SystemStats.load1.toFixed(2) + "  ·  " + SystemStats.load5.toFixed(2)
            + "  ·  " + SystemStats.load15.toFixed(2)
            + (SystemStats.cores.length > 0 ? ",  " + (SystemStats.load1 / SystemStats.cores.length).toFixed(2) + " a thread" : "")
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
    // the one thing here that can be changed, where it's changed
    FlyoutRow {
        label: "Power profile"
        note: PpdProfile.profile !== "" ? PpdProfile.profile : "not available"
        trailing: "Settings  󰅂"
        onActivated: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "power"])
    }
    InfoRow { label: "Scaling driver"; value: SystemSpecs.cpuDriver || "--" }

    // --- silicon ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SILICON" }

    // two columns, as the Overview's facts; the model is the page's
    // subtitle, and the clocks and heat are in the card
    Grid {
        id: silicon
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow { width: silicon.cell; label: "Vendor"; value: SystemSpecs.cpuVendor || "--" }
        InfoRow {
            width: silicon.cell
            label: "Topology"
            value: SystemSpecs.cpuCores > 0
                ? SystemSpecs.cpuCores + " cores · " + SystemSpecs.cpuThreads + " threads"
                : SystemStats.cores.length + " threads"
        }
        InfoRow {
            width: silicon.cell
            label: "Clock range"
            value: SystemSpecs.cpuMaxMhz > 0
                ? (SystemSpecs.cpuMinMhz / 1000).toFixed(2) + " – "
                  + (SystemSpecs.cpuMaxMhz / 1000).toFixed(2) + " GHz" : "--"
        }
        InfoRow { width: silicon.cell; label: "Cache"; value: SystemSpecs.cpuCache || "--" }
    }

    // --- heaviest -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    ProcessTable { heading: "HEAVIEST PROCESSES"; reserveRows: 5; machineShare: true }

    FlyoutRow {
        label: "All processes"
        trailing: "󰅂"
        onActivated: page.go("processes")
    }
}
