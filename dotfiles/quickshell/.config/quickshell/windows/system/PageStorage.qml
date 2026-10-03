// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageStorage.qml
//
// Every mounted filesystem, the disks under them, and what is being read
// and written right now. The old window showed one bar for / and nothing
// else, which answers the wrong question on a machine with a separate home,
// a boot partition and whatever is currently plugged in.

import Quickshell
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
import "../../settings"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Storage"
    subtitle: SystemStats.filesystems.length > 0
        ? SystemStats.filesystems.length + " mounted filesystems  ·  "
          + Format.bytes(SystemStats.filesystems.reduce((a, f) => a + f.size, 0)) + " total"
        : "reading…"

    readonly property var root_: SystemStats.filesystems.find(f => f.target === "/") || null
    readonly property var reclaim: Health.checks.find(c => c.id === "reclaim") || null
    readonly property var orphans: Health.checks.find(c => c.id === "orphans") || null
    // the two upkeep rows come from Health's scan; run one if none has
    Component.onCompleted: if (Health.lastScan === "" && !Health.scanning) Health.scan()

    FlyoutHeading { text: "NOW" }

    // room on / first, then what the disks are doing
    HeadCard {
        glyph: "󰋊"
        glyphColor: page.root_ && page.root_.used / page.root_.size >= 0.9 ? Theme.alert : Theme.textStrong
        title: page.root_ ? Format.bytes(page.root_.size - page.root_.used) + " free on /" : "--"
        lines: [
            page.root_ ? Format.pct(page.root_.used / page.root_.size) + " of " + Format.bytes(page.root_.size) + " used" : "",
            "Reading " + Format.rate(Math.max(0, SystemStats.diskRead)) + " · writing " + Format.rate(Math.max(0, SystemStats.diskWrite)),
        ]
    }

    Spark {
        // reads bright and filled, writes dimmer on top -- the same
        // convention the network graph uses for down and up
        readonly property real peak: Math.max(1048576,
            Math.max.apply(null, SystemStats.diskReadHistory.concat(SystemStats.diskWriteHistory, [0])))
        series: [
            { values: SystemStats.diskReadHistory, color: Theme.accent, fill: true },
            { values: SystemStats.diskWriteHistory, color: Theme.subtext, fill: false },
        ]
        ceiling: peak * 1.15
        caption: "60s · read · write · peak " + Format.rate(peak)
    }

    // --- filesystems --------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "FILESYSTEMS" }

    Repeater {
        model: SystemStats.filesystems

        BarRow {
            required property var modelData
            readonly property real frac: modelData.size > 0 ? modelData.used / modelData.size : 0

            label: modelData.target
            sublabel: modelData.source + "  ·  " + modelData.fstype
            value: Format.bytes(modelData.size - modelData.used) + " free  ·  " + Format.pct(frac)
            fraction: frac
            // 90% is where a copy starts failing and where btrfs and ext4
            // both start fragmenting badly
            critical: frac >= 0.9
        }
    }

    FlyoutRow {
        visible: SystemStats.filesystems.length === 0
        enabled: false
        label: "No filesystems reported yet"
    }

    // --- disks --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "DISKS" }

    Repeater {
        model: SystemSpecs.storage

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: modelData.rota ? "󰋊" : "󰨆"
            label: modelData.model || modelData.name
            note: "/dev/" + modelData.name + " · " + modelData.tran + " · " + (modelData.rota ? "spinning" : "solid state")
            trailing: modelData.size
            trailingIsValue: true
        }
    }
    FlyoutRow { visible: SystemSpecs.storage.length === 0; enabled: false; label: "No disks reported" }

    // --- upkeep -------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "UPKEEP" }

    FlyoutRow {
        visible: !page.reclaim && !page.orphans
        enabled: false
        label: Health.scanning ? "Looking…" : "pacman isn't available"
    }

    SettingsField {
        visible: page.orphans !== null
        labelWidth: Theme.fit(440)
        label: "Orphaned packages"
        hint: !page.orphans ? "" : page.orphans.status === "ok" ? "None: every dependency is still used" : page.orphans.detail

        FlyoutChip {
            anchors.right: parent.right
            visible: !!page.orphans && page.orphans.status !== "ok" && !!page.orphans.repairId
            text: page.orphans ? page.orphans.repairLabel || "Remove" : ""
            confirmText: "Remove them?"
            enabled: Health.busyRepair === ""
            onClicked: Health.repair(page.orphans)
        }
    }

    // "About 380 MB: AUR builds 337 MB, old packages 37 MB" -> "380 MB in AUR builds, old packages"
    SettingsField {
        id: reclaimField
        readonly property string size: {
            var m = page.reclaim ? /^About ([\d.]+ [KMGT]?B)/.exec(page.reclaim.detail) : null
            return m ? m[1] : ""
        }
        visible: page.reclaim !== null
        labelWidth: Theme.fit(440)
        label: "Reclaimable space"
        hint: {
            if (Health.busyRepair === "reclaim") return "Cleaning…"
            if (!page.reclaim) return ""
            var m = /^About ([^:]+): (.*)$/.exec(page.reclaim.detail)
            return m ? m[1] + " in " + m[2].split(", ").map(s => s.replace(/ [\d.]+ [KMGT]?B$/, "")).join(", ")
                : page.reclaim.detail
        }

        FlyoutChip {
            anchors.right: parent.right
            text: "Clean up"
            icon: "󰃢"
            confirmText: reclaimField.size !== "" ? "Clean up " + reclaimField.size + "?" : "Clean up?"
            enabled: Health.busyRepair === "" && reclaimField.size !== ""
            onClicked: Health.repair(page.reclaim)
        }
    }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    FlyoutRow {
        leadingIcon: "󰆍"
        label: "Disk usage"
        note: "ncdu over /, to find what's taking the room"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "command -v ncdu >/dev/null && ncdu / || { echo 'ncdu is not installed'; read -r _; }"])
    }
    FlyoutRow {
        leadingIcon: "󰋊"
        label: "Block devices"
        note: "lsblk: every partition, its filesystem and where it's mounted"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
            "lsblk -o NAME,SIZE,FSTYPE,FSUSE%,MOUNTPOINTS,MODEL; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰩹"
        label: "Trash"
        note: "Opens it in the file manager"
        onActivated: Quickshell.execDetached([Quickshell.env("HOME")
            + "/.config/quickshell/scripts/open-file.sh",
            Quickshell.env("HOME") + "/.local/share/Trash/files"])
    }
}
