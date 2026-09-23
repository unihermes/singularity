// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageStorage.qml
//
// Every mounted filesystem, the disks under them, and what is being read
// and written right now. The old window showed one bar for / and nothing
// else, which answers the wrong question on a machine with a separate home,
// a boot partition and whatever is currently plugged in.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Storage"
    subtitle: SystemStats.filesystems.length > 0
        ? SystemStats.filesystems.length + " mounted filesystems  ·  "
          + Format.bytes(SystemStats.filesystems.reduce((a, f) => a + f.size, 0)) + " total"
        : "reading…"

    // --- throughput ---------------------------------------------------------

    Spark {
        // reads bright and filled, writes dimmer on top -- the same
        // convention the network graph uses for down and up
        readonly property real peak: Math.max(1048576,
            Math.max.apply(null, SystemStats.diskReadHistory.concat(SystemStats.diskWriteHistory, [0])))
        series: [
            { values: SystemStats.diskReadHistory, color: Theme.text, fill: true },
            { values: SystemStats.diskWriteHistory, color: Theme.subtext, fill: false },
        ]
        ceiling: peak * 1.15
        caption: "read · write · peak " + Format.rate(peak)
    }

    InfoRow { label: "Reading"; value: Format.rate(SystemStats.diskRead) }
    InfoRow { label: "Writing"; value: Format.rate(SystemStats.diskWrite) }

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
            value: Format.bytes(modelData.size - modelData.used) + " free"
            fraction: frac
            // 90% is where a copy starts failing and where btrfs and ext4
            // both start fragmenting badly
            critical: frac >= 0.9
        }
    }

    Text {
        width: parent.width
        visible: SystemStats.filesystems.length === 0
        text: "No filesystems reported yet."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    // --- disks --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "DISKS" }

    Repeater {
        model: SystemSpecs.storage

        InfoRow {
            required property var modelData
            label: "/dev/" + modelData.name + "  (" + modelData.tran + ")"
            value: modelData.model + "  ·  " + modelData.size
                + "  ·  " + (modelData.rota ? "spinning" : "solid state")
        }
    }
    InfoRow { visible: SystemSpecs.storage.length === 0; label: "Disks"; value: "--" }

    // --- package cache ------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "RECLAIMABLE" }

    InfoRow {
        label: "Pacman cache"
        value: SystemSpecs.cacheSize || "--"
    }
    InfoRow {
        label: "Orphan packages"
        value: SystemSpecs.orphanCount < 0 ? "--"
            : SystemSpecs.orphanCount === 0 ? "none" : SystemSpecs.orphanCount + " installed"
    }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "Disk usage (ncdu)"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "command -v ncdu >/dev/null && ncdu / || { echo 'ncdu is not installed'; read -r _; }"])
        }
        FlyoutChip {
            text: "Block devices"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "lsblk -o NAME,SIZE,FSTYPE,FSUSE%,MOUNTPOINTS,MODEL; read -r _"])
        }
        FlyoutChip {
            text: "Trash"
            onClicked: Quickshell.execDetached([Quickshell.env("HOME")
                + "/.config/quickshell/scripts/open-file.sh",
                Quickshell.env("HOME") + "/.local/share/Trash/files"])
        }
    }
}
