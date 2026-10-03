// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageMemory.qml
//
// RAM, broken down the way the kernel actually accounts for it. The one
// figure people get wrong is "used": free memory looks alarmingly low on a
// healthy machine because the page cache holds everything it can, and the
// kernel hands that back the instant anything asks. So the gauge is built
// on MemAvailable, and the breakdown below shows where the rest went.

import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
import "../../settings"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Memory"
    subtitle: SystemStats.memTotalKb > 0
        ? Format.kib(SystemStats.memTotalKb) + " installed"
        + (SystemStats.swapTotalKb > 0 ? "  ·  " + Format.kib(SystemStats.swapTotalKb) + " swap"
                                       : "  ·  no swap")
        : ""

    // the window, for the row that opens Processes
    readonly property var win: {
        var p = page.parent
        while (p && p.currentPage === undefined) p = p.parent
        return p
    }
    function go(id) { if (win) win.select(id) }
    // the largest by memory, on the memory page
    Component.onCompleted: SystemStats.procSort = "mem"

    FlyoutHeading { text: "NOW" }

    // in use against what's installed, and what the kernel could hand out
    HeadCard {
        glyph: "󰘚"
        glyphColor: SystemStats.mem >= 0.9 ? Theme.alert : Theme.textStrong
        title: Format.kib(SystemStats.memUsedKb) + " in use"
        lines: [
            Format.pct(SystemStats.mem) + " of " + Format.kib(SystemStats.memTotalKb)
                + " · " + Format.kib(SystemStats.memAvailKb) + " available",
            SystemStats.swapTotalKb > 0
                ? "Swap " + Format.kib(SystemStats.swapTotalKb - SystemStats.swapFreeKb) + " of "
                  + Format.kib(SystemStats.swapTotalKb) + " used"
                : "No swap",
        ]
    }

    Spark {
        series: [{ values: SystemStats.memHistory, color: Theme.accent, fill: true }]
        ceiling: 1
        caption: "60s · RAM in use"
    }

    // --- breakdown ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "BREAKDOWN" }

    // A single stacked strip of the whole of RAM: applications, then the
    // reclaimable cache, then what is genuinely free. It is the one picture
    // that makes "90% used" and "nothing is wrong" sit together.
    Item {
        width: parent.width
        height: Theme.meterHeight + 4

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, Theme.radius)
            color: Theme.meterTrack
            border.width: Theme.borderWidth
            border.color: Theme.meterStroke
            clip: true

            readonly property real total: Math.max(1, SystemStats.memTotalKb)

            Rectangle {
                id: usedBand
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width * SystemStats.memUsedKb / parent.total
                radius: parent.radius
                color: SystemStats.mem >= 0.9 ? Theme.alert : Theme.meterFill
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: usedBand.right
                width: parent.width * (SystemStats.cachedKb + SystemStats.buffersKb) / parent.total
                color: Theme.muted
            }
        }
    }

    Text {
        width: parent.width
        text: "■ applications   ■ cache and buffers   □ free"
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontSmall
    }

    // two across, so the breakdown reads beside the strip it explains
    Grid {
        id: parts
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow {
            width: parts.cell
            label: "Applications"
            value: Format.kib(SystemStats.memUsedKb) + "  " + Format.pct(SystemStats.mem)
        }
        InfoRow {
            width: parts.cell
            label: "Available"
            value: Format.kib(SystemStats.memAvailKb) + "  "
                + Format.pct(SystemStats.memTotalKb > 0 ? SystemStats.memAvailKb / SystemStats.memTotalKb : 0)
        }
        InfoRow { width: parts.cell; label: "Page cache"; value: Format.kib(SystemStats.cachedKb) }
        InfoRow { width: parts.cell; label: "Buffers"; value: Format.kib(SystemStats.buffersKb) }
        InfoRow { width: parts.cell; label: "Shared (tmpfs)"; value: Format.kib(SystemStats.shmemKb) }
        InfoRow { width: parts.cell; label: "Kernel slab"; value: Format.kib(SystemStats.slabKb) }
        InfoRow { width: parts.cell; label: "Truly free"; value: Format.kib(SystemStats.memFreeKb) }
    }

    // --- swap and writeback ---------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SWAP AND WRITEBACK" }

    Grid {
        id: more
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: (width - columnSpacing) / 2

        InfoRow {
            width: more.cell
            label: "Swap"
            value: SystemStats.swapTotalKb > 0
                ? Format.kib(SystemStats.swapTotalKb - SystemStats.swapFreeKb) + " of " + Format.kib(SystemStats.swapTotalKb)
                : "none configured"
            // swap in use at all isn't a problem; swap mostly full is
            valueColor: SystemStats.swapTotalKb > 0 && SystemStats.swap >= 0.8 ? Theme.alert : undefined
        }
        InfoRow {
            width: more.cell
            label: "Swap free"
            value: SystemStats.swapTotalKb > 0 ? Format.kib(SystemStats.swapFreeKb) : "--"
        }
        // changed in memory, not yet on disk
        InfoRow { width: more.cell; label: "Dirty"; value: Format.kib(SystemStats.dirtyKb) }
        InfoRow { width: more.cell; label: "Writing now"; value: Format.kib(SystemStats.writebackKb) }
    }
    SettingsNote { text: "Dirty: changed in memory, not yet written to disk" }

    // --- heaviest -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    ProcessTable { heading: "LARGEST PROCESSES"; reserveRows: 5; showSort: true; machineShare: true }

    FlyoutRow {
        label: "All processes"
        trailing: "󰅂"
        onActivated: page.go("processes")
    }
}
