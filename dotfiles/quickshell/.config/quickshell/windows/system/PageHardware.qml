// Singularity - Quickshell
// ~/.config/quickshell/windows/system/PageHardware.qml
//
// What this machine physically is: board and firmware, graphics, the
// displays and the input devices attached to it, and every temperature and
// fan the kernel exposes.
//
// The device names under INPUT are Hyprland's own, which is the reason to
// print them: a device rule in hyprland.lua has to match one of these
// strings exactly, and guessing it is the usual way that goes wrong.

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

    title: "Hardware"
    subtitle: [SystemSpecs.board, SystemSpecs.chassis].filter(x => x).join("  ·  ")

    // --- identity -----------------------------------------------------------

    Item {
        width: parent.width
        height: Theme.controlSize

        FlyoutHeading {
            anchors.left: parent.left
            anchors.right: copyBtn.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "MACHINE"
        }

        Rectangle {
            id: copyBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: copyLabel.implicitWidth + Theme.spaceXxl
            height: Theme.controlSize
            radius: Theme.radiusInner
            color: copyMouse.containsMouse ? Theme.hoverFill : "transparent"
            border.width: Theme.borderWidth
            border.color: Theme.stroke

            Text {
                id: copyLabel
                anchors.centerIn: parent
                text: SystemSpecs.copied ? "Copied" : "Copy specs"
                color: SystemSpecs.copied ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemSpecs.copySummary()
            }
        }
    }

    InfoRow { label: "Board";    value: SystemSpecs.board || "--" }
    InfoRow { label: "Chassis";  value: SystemSpecs.chassis || "--" }
    InfoRow {
        label: "Firmware"
        value: [SystemSpecs.biosVendor, SystemSpecs.biosVersion].filter(x => x).join(" ") || "--"
    }
    InfoRow {
        visible: SystemSpecs.biosDate !== ""
        label: "Firmware date"
        value: SystemSpecs.biosDate
    }
    InfoRow { label: "CPU"; value: SystemSpecs.cpuModel || "--" }
    InfoRow {
        label: "Memory"
        value: SystemStats.memTotalKb > 0 ? Format.kib(SystemStats.memTotalKb) : "--"
    }
    InfoRow {
        label: "Buses"
        value: SystemSpecs.pciCount < 0 ? "--"
            : SystemSpecs.pciCount + " PCI devices  ·  " + SystemSpecs.usbCount + " USB devices"
    }

    // --- graphics -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "GRAPHICS" }

    InfoRow { label: "GPU";    value: SystemSpecs.gpuModel || "--" }
    InfoRow { label: "Driver"; value: SystemSpecs.gpuDriver || "--" }
    InfoRow { label: "Mesa";   value: SystemSpecs.mesaVersion || "--" }

    Repeater {
        model: SystemSpecs.monitors

        Column {
            required property var modelData
            width: parent.width
            spacing: 0

            InfoRow {
                label: SystemSpecs.monitors.length > 1 ? "Display " + modelData.name : "Display"
                value: modelData.width + " × " + modelData.height + " @ " + modelData.hz + " Hz"
                    + (modelData.scale && modelData.scale !== 1
                        ? "  ·  ×" + Number(modelData.scale).toFixed(2) : "")
            }
            InfoRow {
                visible: modelData.description !== ""
                label: "  " + modelData.name
                value: modelData.description
            }
        }
    }
    InfoRow { visible: SystemSpecs.monitors.length === 0; label: "Display"; value: "--" }

    // --- sensors ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SENSORS" }

    // two columns, hottest first down the left, as the CPU page's threads
    Grid {
        id: sensorGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        rowSpacing: Theme.spaceM
        flow: Grid.TopToBottom
        rows: Math.ceil(SystemStats.sensors.length / 2)

        Repeater {
            model: SystemStats.sensors

            BarRow {
                required property var modelData
                width: (sensorGrid.width - sensorGrid.columnSpacing) / 2
                label: modelData.label
                sublabel: modelData.chip
                value: Math.round(modelData.c) + "°C"
                // the same 100C full scale the CPU tile uses, so two sensors
                // side by side are comparable at a glance
                fraction: modelData.c / 100
                critical: modelData.c >= 90
            }
        }
    }

    Text {
        width: parent.width
        visible: SystemStats.sensors.length === 0
        text: "No hwmon temperature nodes are readable."
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        model: SystemStats.fans

        InfoRow {
            required property var modelData
            label: modelData.label + "  (" + modelData.chip + ")"
            value: modelData.rpm > 0 ? Math.round(modelData.rpm) + " rpm" : "stopped"
        }
    }

    // --- audio --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "AUDIO" }

    InfoRow {
        label: "Output"
        value: Audio.ready && Audio.sink.description ? Audio.sink.description : "--"
    }
    InfoRow {
        label: "Volume"
        value: Audio.ready ? Audio.percent + "%" + (Audio.muted ? "  ·  muted" : "") : "--"
    }

    // --- input --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "INPUT" }

    Repeater {
        model: SystemSpecs.inputs

        InfoRow {
            required property var modelData
            label: modelData.kind
            value: modelData.name + (modelData.detail ? "  ·  " + modelData.detail : "")
        }
    }
    InfoRow { visible: SystemSpecs.inputs.length === 0; label: "Devices"; value: "--" }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    Flow {
        width: parent.width
        spacing: Theme.spaceM

        FlyoutChip {
            text: "PCI devices"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "lspci -k; read -r _"])
        }
        FlyoutChip {
            text: "USB devices"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "lsusb -t; lsusb; read -r _"])
        }
        FlyoutChip {
            text: "Loaded modules"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "lsmod | less"])
        }
        FlyoutChip {
            text: "Kernel messages"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "journalctl -k -b -e"])
        }
        FlyoutChip {
            text: "Hyprland devices"
            onClicked: Quickshell.execDetached(["alacritty", "-e", "sh", "-c",
                "hyprctl devices; read -r _"])
        }
    }
}
