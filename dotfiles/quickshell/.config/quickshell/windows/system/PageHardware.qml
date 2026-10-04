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
import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../../flyouts"
import "../../settings"
// the page's own building blocks next door; QML needs the directory named
import "../system"

SystemPage {
    id: page

    title: "Hardware"
    subtitle: [SystemSpecs.board, SystemSpecs.chassis].filter(x => x).join("  ·  ")

    readonly property var win: {
        var p = page.parent
        while (p && p.currentPage === undefined) p = p.parent
        return p
    }
    function go(id) { if (win) win.select(id) }
    function grid2(w, spacing) { return (w - spacing) / 2 }

    // --- identity -----------------------------------------------------------

    FlyoutHeading { text: "MACHINE" }

    // what it is in two lines, and the one action worth having here
    HeadCard {
        glyph: /laptop|notebook|portable/i.test(SystemSpecs.chassis) ? "󰌢" : "󰇄"
        title: SystemSpecs.board || "This machine"
        lines: [
            [SystemSpecs.cpuModel, SystemStats.memTotalKb > 0 ? Format.kib(SystemStats.memTotalKb) + " RAM" : ""]
                .filter(x => x).join(" · "),
            SystemSpecs.gpuModel || "",
        ]

        FlyoutChip {
            text: SystemSpecs.copied ? "Copied" : "Copy specs"
            icon: SystemSpecs.copied ? "󰄬" : "󰆏"
            onClicked: SystemSpecs.copySummary()
        }
    }

    Grid {
        id: idGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: page.grid2(width, columnSpacing)

        InfoRow { width: idGrid.cell; label: "Chassis"; value: SystemSpecs.chassis || "--" }
        InfoRow {
            width: idGrid.cell
            label: "Firmware"
            value: [SystemSpecs.biosVendor, SystemSpecs.biosVersion].filter(x => x).join(" ") || "--"
        }
        InfoRow {
            width: idGrid.cell
            visible: SystemSpecs.biosDate !== ""
            label: "Firmware date"
            value: SystemSpecs.biosDate
        }
        InfoRow {
            width: idGrid.cell
            label: "Buses"
            value: SystemSpecs.pciCount < 0 ? "--"
                : SystemSpecs.pciCount + " PCI · " + SystemSpecs.usbCount + " USB"
        }
    }

    // --- graphics -----------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "GRAPHICS" }

    InfoRow { label: "GPU"; value: SystemSpecs.gpuModel || "--" }
    Grid {
        id: gpuGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        readonly property real cell: page.grid2(width, columnSpacing)

        InfoRow { width: gpuGrid.cell; label: "Driver"; value: SystemSpecs.gpuDriver || "--" }
        InfoRow { width: gpuGrid.cell; label: "Mesa"; value: SystemSpecs.mesaVersion || "--" }
    }

    // each display a row, into Settings › Display
    Repeater {
        model: SystemSpecs.monitors

        FlyoutRow {
            required property var modelData
            leadingIcon: "󰍹"
            label: modelData.description || modelData.name
            note: modelData.name
            trailing: modelData.width + "×" + modelData.height + " @ " + modelData.hz + " Hz"
                + (modelData.scale && modelData.scale !== 1 ? " · ×" + Number(modelData.scale).toFixed(2) : "")
                + "  󰅂"
            onActivated: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "display"])
        }
    }
    FlyoutRow { visible: SystemSpecs.monitors.length === 0; enabled: false; label: "No displays reported" }

    // --- sensors ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "SENSORS" }

    // the hottest ten, two columns, hottest first down the left; the rest
    // behind Show all, as the long lists in Settings
    property bool allSensors: false
    readonly property var shownSensors: allSensors ? SystemStats.sensors : SystemStats.sensors.slice(0, 10)

    Grid {
        id: sensorGrid
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl
        rowSpacing: Theme.spaceM
        flow: Grid.TopToBottom
        rows: Math.ceil(page.shownSensors.length / 2)

        Repeater {
            model: page.shownSensors

            BarRow {
                required property var modelData
                width: page.grid2(sensorGrid.width, sensorGrid.columnSpacing)
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

    FlyoutRow {
        visible: SystemStats.sensors.length > 10
        label: page.allSensors ? "Show fewer" : "Show all " + SystemStats.sensors.length
        trailing: page.allSensors ? "󰅀" : (SystemStats.sensors.length - 10) + " more  󰅂"
        onActivated: page.allSensors = !page.allSensors
    }

    SettingsNote {
        visible: SystemStats.sensors.length === 0
        text: "No hwmon temperature nodes are readable"
    }

    Repeater {
        model: SystemStats.fans

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: "󰈐"
            label: modelData.label
            note: modelData.chip
            trailing: modelData.rpm > 0 ? Math.round(modelData.rpm) + " rpm" : "stopped"
            trailingIsValue: true
        }
    }

    // --- audio --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "AUDIO" }

    FlyoutRow {
        leadingIcon: Audio.ready && Audio.muted ? "󰝟" : "󰕾"
        label: Audio.ready ? Audio.sink.nickname || Audio.sink.description || "No output" : "No output"
        note: Audio.ready ? Audio.percent + "%" + (Audio.muted ? " · muted" : "") : ""
        trailing: "Settings  󰅂"
        onActivated: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "audio"])
    }

    // --- input --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "INPUT" }

    SettingsNote { text: "Named as Hyprland matches them, for device rules" }

    Repeater {
        model: SystemSpecs.inputs

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: ({ Keyboard: "󰌌", Pointer: "󰍽", Touch: "󰆽", Tablet: "󰓷" })[modelData.kind] || "󰌌"
            label: modelData.name
            note: modelData.kind.toLowerCase() + (modelData.detail ? " · " + modelData.detail : "")
        }
    }
    FlyoutRow { visible: SystemSpecs.inputs.length === 0; enabled: false; label: "No input devices reported" }

    // --- tools --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceS }
    FlyoutHeading { text: "TOOLS" }

    FlyoutRow {
        leadingIcon: "󰘚"
        label: "PCI devices"
        note: "lspci -k: each card and the driver it uses"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "lspci -k; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰗮"
        label: "USB devices"
        note: "What's plugged in, as a tree"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "lsusb -t; lsusb; read -r _"])
    }
    FlyoutRow {
        leadingIcon: "󰏗"
        label: "Loaded modules"
        note: "lsmod: the kernel's drivers in use"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "lsmod | less"])
    }
    FlyoutRow {
        leadingIcon: "󰈙"
        label: "Kernel messages"
        note: "This boot's kernel log"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "journalctl -k -b -e"])
    }
    FlyoutRow {
        leadingIcon: "󰌌"
        label: "Hyprland devices"
        note: "hyprctl devices, with every name in full"
        onActivated: Quickshell.execDetached(["alacritty", "-e", "sh", "-c", "hyprctl devices; read -r _"])
    }
}
