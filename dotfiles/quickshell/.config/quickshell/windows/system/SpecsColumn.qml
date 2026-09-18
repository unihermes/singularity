// Singularity - Quickshell
// ~/.config/quickshell/system/SpecsColumn.qml
//
// The System window's right column: kernel, uptime and packages, hardware
// specs with a copy-to-clipboard summary, and quick links.

import Quickshell
import Quickshell.Io
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"

Column {
    id: column

    required property var stats

    spacing: 6

    FlyoutHeading { text: "SYSTEM" }

    InfoRow { label: "Kernel";   value: column.stats.specs.kernel }
    InfoRow { label: "Uptime";   value: Format.duration(column.stats.uptimeSec) }
    InfoRow { label: "Hostname"; value: column.stats.specs.hostname }
    InfoRow {
        label: "Packages"
        value: column.stats.specs.pkgCount < 0 ? "--" : column.stats.specs.pkgCount + "  (" + column.stats.specs.aurCount + " AUR)"
    }

    Item { width: 1; height: 4 }
    Item {
        width: parent.width
        height: 18

        FlyoutHeading {
            anchors.left: parent.left
            anchors.right: copyBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "SPECS"
        }

        Rectangle {
            id: copyBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: copyLabel.implicitWidth + 16
            height: 18
            radius: Theme.radiusInner
            color: copyMouse.containsMouse ? Theme.overlay : "transparent"
            border.width: 1
            border.color: Theme.border

            Text {
                id: copyLabel
                anchors.centerIn: parent
                text: column.stats.specs.copied ? "Copied" : "Copy"
                color: column.stats.specs.copied ? Theme.bright : Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: column.stats.specs.copySummary()
            }
        }
    }

    InfoRow { label: "CPU";   value: column.stats.specs.cpuModel || "--" }
    InfoRow {
        label: "GPU"
        value: (column.stats.specs.gpuModel || "--") + (column.stats.specs.gpuDriver ? "  ·  " + column.stats.specs.gpuDriver : "")
            + (column.stats.specs.mesaVersion ? "  ·  mesa " + column.stats.specs.mesaVersion : "")
    }
    InfoRow { label: "RAM";   value: column.stats.memTotalKb > 0 ? Format.kib(column.stats.memTotalKb) : "--" }
    InfoRow { label: "Board"; value: column.stats.specs.board || "--" }

    Repeater {
        model: column.stats.specs.monitors
        InfoRow {
            required property var modelData
            label: column.stats.specs.monitors.length > 1 ? "Display " + modelData.name : "Display"
            value: modelData.width + " × " + modelData.height + "  @" + modelData.hz + "Hz"
        }
    }
    InfoRow { visible: column.stats.specs.monitors.length === 0; label: "Display"; value: "--" }

    Repeater {
        model: column.stats.specs.storage
        InfoRow {
            required property var modelData
            label: modelData.tran ? modelData.name + " (" + modelData.tran + ")" : modelData.name
            value: modelData.model + "  ·  " + modelData.size
        }
    }
    InfoRow { visible: column.stats.specs.storage.length === 0; label: "Storage"; value: "--" }

    Item { width: 1; height: 4 }
    FlyoutHeading { text: "QUICK LINKS" }

    Row {
        width: parent.width
        spacing: 6

        FlyoutChip {
            text: "hyprland.lua"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "nvim",
                Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"])
        }
        FlyoutChip {
            text: "shell.qml"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "nvim",
                Quickshell.env("HOME") + "/.config/quickshell/shell.qml"])
        }
    }
}
