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

    Gauge {
        label: "In use"
        fraction: SystemStats.mem
        value: Format.pct(SystemStats.mem)
        critical: SystemStats.mem >= 0.9
    }

    Gauge {
        label: "Swap"
        fraction: SystemStats.swap
        available: SystemStats.swapTotalKb > 0
        value: SystemStats.swapTotalKb > 0 ? Format.pct(SystemStats.swap) : "none"
        // swap in use at all isn't a problem; swap mostly full is
        critical: SystemStats.swapTotalKb > 0 && SystemStats.swap >= 0.8
    }

    Spark {
        series: [{ values: SystemStats.memHistory, color: Theme.text, fill: true }]
        ceiling: 1
        caption: "RAM · 60s"
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
        font.pixelSize: Theme.fontSmall
    }

    InfoRow {
        label: "Applications"
        value: Format.kib(SystemStats.memUsedKb) + "   " + Format.pct(SystemStats.mem)
    }
    InfoRow {
        label: "Available"
        value: Format.kib(SystemStats.memAvailKb)
            + "   " + Format.pct(SystemStats.memTotalKb > 0 ? SystemStats.memAvailKb / SystemStats.memTotalKb : 0)
    }
    InfoRow { label: "Page cache";  value: Format.kib(SystemStats.cachedKb) }
    InfoRow { label: "Buffers";     value: Format.kib(SystemStats.buffersKb) }
    InfoRow { label: "Shared (tmpfs)"; value: Format.kib(SystemStats.shmemKb) }
    InfoRow { label: "Kernel slab"; value: Format.kib(SystemStats.slabKb) }
    InfoRow {
        label: "Truly free"
        value: Format.kib(SystemStats.memFreeKb)
    }

    // --- writeback ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "WRITEBACK" }

    Text {
        width: parent.width
        text: "Pages changed in memory but not yet on disk. A dirty figure that "
            + "stays large under load is the disk failing to keep up, not a memory problem."
        wrapMode: Text.WordWrap
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    InfoRow { label: "Dirty";      value: Format.kib(SystemStats.dirtyKb) }
    InfoRow { label: "In flight";  value: Format.kib(SystemStats.writebackKb) }

    // --- swap ---------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SWAP" }

    InfoRow {
        label: "Total"
        value: SystemStats.swapTotalKb > 0 ? Format.kib(SystemStats.swapTotalKb) : "none configured"
    }
    InfoRow {
        visible: SystemStats.swapTotalKb > 0
        label: "Used"
        value: Format.kib(SystemStats.swapTotalKb - SystemStats.swapFreeKb)
    }
    InfoRow {
        visible: SystemStats.swapTotalKb > 0
        label: "Free"
        value: Format.kib(SystemStats.swapFreeKb)
    }

    // --- heaviest -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "LARGEST PROCESSES" }

    ProcessTable { reserveRows: 5; showSort: true }
}
