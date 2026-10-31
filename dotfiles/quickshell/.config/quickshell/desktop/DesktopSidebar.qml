// Singularity - Quickshell
// ~/.config/quickshell/desktop/DesktopSidebar.qml
//
// A conky-style column down the right edge of the primary display, on the
// wallpaper under the windows (Settings.deskSidebar). A section each under
// the shell's section heading, as label and value lines, the shell's
// meters beside their labels and "used / total [ n% ]" under them: Info
// (OS, kernel, uptime, host), CPU (model, clock, temperature, each core,
// the last minute, the busiest processes), GPU (model, clocks,
// temperature, power, use, video memory), RAM (with the processes holding
// most), Drives, Network (address, rates, totals, the last minute), Fans
// and Battery. A section or line the machine can't fill is left out. Flush
// with the screen's right edge on a panel framed as the style has it, kept
// see-through, filling the height under the bar. The desktop widgets keep
// clear of it (DesktopWidgets' area).

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

PanelWindow {
    id: win

    required property var scope

    readonly property bool here: Settings.deskSidebar && Notifications.popupScreen === scope.modelData.name
    // the column's width, which DesktopWidgets leaves free
    readonly property int columnWidth: Theme.fit(340)
    // from its edges in to the readings
    readonly property int inset: Theme.fit(20)

    screen: scope.modelData
    visible: here
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop-widget"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // flush with the right edge, from the bar to the other end
    anchors { top: true; right: true; bottom: true }
    margins.top: Theme.barPosition === "bottom" ? 0 : Theme.barExtent
    margins.bottom: Theme.barPosition === "bottom" ? Theme.barExtent : 0
    implicitWidth: columnWidth
    // nothing on it takes the pointer
    mask: Region {}

    // rounded only on the side away from the edge
    PanelFrame {
        anchors.fill: parent
        ground: Theme.deskFill(0.55)
        topRightRadius: 0
        bottomRightRadius: 0
    }

    // the inks and type, as WidgetCard has them, for WidgetText
    Item {
        id: ink
        readonly property color fg: Theme.textStrong
        readonly property color fgDim: Theme.text
        readonly property color accent: Theme.isLight ? Theme.accent : Qt.lighter(Theme.accent, 1.4)
        readonly property string font: Theme.fontText
        readonly property int textCaption: Theme.fit(14)
        readonly property int textBody: Theme.fit(16)
        readonly property int weightBody: Font.Medium
        readonly property int weightStrong: Font.Bold
    }

    // "AMD Ryzen 7 7700X 8-Core Processor" -> "Ryzen 7 7700X"; lspci's
    // "NVIDIA Corporation AD104 [GeForce RTX 4070] (rev a1)" -> "RTX 4070"
    function shortModel(s) {
        var m = String(s).match(/\[(.+?)\]/)
        return (m ? m[1] : String(s)).replace(/\((R|TM)\)/g, "").replace(/^(AMD|Intel|NVIDIA)\s+/, "")
            .replace(/^GeForce\s+/, "").replace(/\s+\d+-Core Processor$/, "").replace(/\s+Processor$/, "")
            .replace(/\s+CPU @.*$/, "").trim()
    }
    function temp(c) { return c >= 0 ? Math.round(c) + "°C" : "" }
    // "171G / 246G  [ 69% ]"
    function ofTotal(used, total) {
        return Format.bytes(used) + " / " + Format.bytes(total) + "  [ " + Math.round(used / Math.max(1, total) * 100) + "% ]"
    }

    // the real filesystems, largest first, three at most
    readonly property var disks: SystemStats.filesystems.filter(f => f.size >= 1073741824).slice(0, 3)
    readonly property bool hasGpu: Cooling.gpuLoad >= 0 || Cooling.gpuC >= 0
    // the network's sparklines share a scale: the busiest second shown
    readonly property real netPeak: Math.max(1024, ...SystemStats.rxHistory, ...SystemStats.txHistory)

    // a label on the left, dimmed, and its value on the right (InfoRow's
    // layout, at the column's tighter line)
    component KeyValue: Item {
        id: kv
        property string label: ""
        property string value: ""
        width: parent.width
        height: k.implicitHeight
        WidgetText { id: k; card: ink; color: ink.fgDim; text: kv.label }
        WidgetText {
            anchors.left: k.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            card: ink
            text: kv.value
            font.features: ({ "tnum": 1 })
        }
    }
    // a name to the left, a figure to the right (process lists)
    component Pair: Item {
        id: pair
        property string label: ""
        property string value: ""
        width: parent.width
        height: r.implicitHeight
        WidgetText { card: ink; width: parent.width - r.implicitWidth - Theme.spaceS; text: pair.label }
        WidgetText { id: r; card: ink; anchors.right: parent.right; text: pair.value; font.features: ({ "tnum": 1 }) }
    }
    // a label with its meter filling the rest of the line
    component Bar: Item {
        id: bar
        property string label: ""
        property real frac: 0
        property int labelWidth: bl.implicitWidth
        width: parent.width
        height: bl.implicitHeight
        WidgetText { id: bl; card: ink; color: ink.fgDim; text: bar.label; font.features: ({ "tnum": 1 }) }
        Meter {
            x: parent.labelWidth + Theme.spaceS
            width: parent.width - x
            anchors.verticalCenter: parent.verticalCenter
            fraction: bar.frac
            fillColor: bar.frac >= 0.85 ? Theme.alert : Theme.meterFill
        }
    }
    // a "used / total [ n% ]" line, to the right
    component Caption: Item {
        id: cap
        property string text: ""
        width: parent.width
        height: c.implicitHeight
        WidgetText { id: c; card: ink; anchors.right: parent.right; text: cap.text; font.features: ({ "tnum": 1 }) }
    }
    component Section: Column {
        property string title: ""
        width: parent.width
        spacing: Theme.fit(4)
        FlyoutHeading { text: parent.title }
    }
    component Line: Spark {
        width: parent.width
        height: Theme.fit(24)
        bare: true
    }

    // Fits the height whatever shows: the sections spread out to fill it,
    // or the whole column scales down when they'd run past the foot.
    readonly property real room: height - inset * 2
    readonly property int baseGap: Theme.fit(14)
    readonly property var shownParts: body.children.filter(c => c.visible)
    readonly property real partsHeight: shownParts.reduce((h, c) => h + c.height, 0)
    readonly property real natural: partsHeight + baseGap * Math.max(0, shownParts.length - 1)
    readonly property real fit: natural > room && natural > 0 ? room / natural : 1

    Column {
        id: body
        x: win.inset
        y: win.inset
        transformOrigin: Item.TopLeft
        scale: win.fit
        width: (win.columnWidth - win.inset * 2) / win.fit
        spacing: win.fit < 1 || win.shownParts.length < 2 ? win.baseGap
            : (win.room - win.partsHeight) / (win.shownParts.length - 1)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.base
            blurMax: 8
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        Section {
            title: "INFO"
            KeyValue { label: "OS"; value: SystemSpecs.distro + (SystemSpecs.arch ? " " + SystemSpecs.arch : "") }
            KeyValue { label: "Kernel"; value: SystemSpecs.kernel }
            KeyValue { label: "Uptime"; value: Format.duration(SystemStats.uptimeSec) }
            KeyValue { label: "Hostname"; value: SystemSpecs.hostname }
        }

        Section {
            title: "CPU"
            KeyValue { label: "CPU"; value: win.shortModel(SystemSpecs.cpuModel) }
            KeyValue { visible: SystemStats.cpuMhz > 0; label: "Frequency"; value: Math.round(SystemStats.cpuMhz) + " MHz" }
            KeyValue { visible: SystemStats.tempC >= 0; label: "Temperature"; value: win.temp(SystemStats.tempC) }
            Bar { label: "Usage " + Format.pct(SystemStats.cpu); frac: SystemStats.cpu }
            // each core, two columns
            Grid {
                id: coreGrid
                width: parent.width
                columns: 2
                columnSpacing: Theme.spaceL
                rowSpacing: Theme.fit(2)
                Repeater {
                    model: SystemStats.cores.length
                    Bar {
                        required property int index
                        width: (coreGrid.width - coreGrid.columnSpacing) / 2
                        labelWidth: Theme.fit(68)
                        label: (index + 1) + "  " + Math.round((SystemStats.cores[index] || 0) * 100) + "%"
                        frac: SystemStats.cores[index] || 0
                    }
                }
            }
            Line { series: [{ values: SystemStats.cpuHistory, color: Theme.meterFill, fill: true }] }
            Repeater {
                model: SystemStats.procs.slice(0, 4)
                Pair {
                    required property var modelData
                    label: modelData.name
                    value: modelData.cpu.toFixed(1) + " %"
                }
            }
        }

        Section {
            visible: win.hasGpu
            title: "GPU"
            KeyValue { label: "Model"; value: win.shortModel(SystemSpecs.gpuModel) }
            KeyValue { visible: Cooling.gpuClock >= 0; label: "Core clock"; value: Cooling.gpuClock + " MHz" }
            KeyValue { visible: Cooling.gpuMemClock >= 0; label: "Mem clock"; value: Cooling.gpuMemClock + " MHz" }
            KeyValue { visible: Cooling.gpuC >= 0; label: "Temperature"; value: win.temp(Cooling.gpuC) }
            KeyValue { visible: Cooling.gpuWatts >= 0; label: "Power"; value: Math.round(Cooling.gpuWatts) + " W" }
            Bar { visible: Cooling.gpuLoad >= 0; label: "Usage " + Cooling.gpuLoad + "%"; frac: Cooling.gpuLoad / 100 }
            Bar {
                visible: Cooling.gpuMemTotal > 0
                label: "VRAM"
                frac: Cooling.gpuMemUsed / Math.max(1, Cooling.gpuMemTotal)
            }
            Caption {
                visible: Cooling.gpuMemTotal > 0
                text: win.ofTotal(Cooling.gpuMemUsed * 1048576, Cooling.gpuMemTotal * 1048576)
            }
            // its temperature over the last few minutes, 30 to 100 °C
            Line {
                visible: Cooling.gpuHistory.length > 1
                floor: 30
                ceiling: 100
                historyLength: Cooling.historyLength
                series: [{ values: Cooling.gpuHistory, color: Theme.meterFill, fill: true }]
            }
        }

        Section {
            visible: SystemStats.memTotalKb > 0
            title: "RAM"
            Bar { label: "RAM"; frac: SystemStats.mem }
            Caption { text: win.ofTotal(SystemStats.memUsedKb * 1024, SystemStats.memTotalKb * 1024) }
            Bar {
                visible: SystemStats.swapTotalKb > 0
                label: "Swap"
                frac: 1 - SystemStats.swapFreeKb / Math.max(1, SystemStats.swapTotalKb)
            }
            Repeater {
                model: SystemStats.procsByMem
                Pair {
                    required property var modelData
                    label: modelData.name
                    value: Format.kib(modelData.memKb)
                }
            }
        }

        Section {
            visible: win.disks.length > 0
            title: "DRIVES"
            Repeater {
                model: win.disks
                Column {
                    required property var modelData
                    width: parent.width
                    spacing: Theme.fit(2)
                    Bar { label: modelData.target; frac: modelData.used / modelData.size }
                    Caption { text: win.ofTotal(modelData.used, modelData.size) }
                }
            }
            KeyValue {
                visible: SystemStats.diskRead >= 0
                label: "Read / write"
                value: Format.rate(SystemStats.diskRead) + " / " + Format.rate(SystemStats.diskWrite)
            }
        }

        Section {
            visible: SystemStats.iface !== ""
            title: "NETWORK"
            KeyValue { label: "IP"; value: SystemStats.ipAddr + " (" + SystemStats.iface + ")" }
            KeyValue { label: "Up"; value: Format.rate(SystemStats.txRate) }
            KeyValue { label: "Down"; value: Format.rate(SystemStats.rxRate) }
            KeyValue { label: "Total up"; value: Format.bytes(SystemStats.txTotal) }
            KeyValue { label: "Total down"; value: Format.bytes(SystemStats.rxTotal) }
            Line {
                height: Theme.fit(20)
                ceiling: win.netPeak
                series: [{ values: SystemStats.rxHistory, color: Theme.meterFill, fill: true },
                         { values: SystemStats.txHistory, color: Theme.subtext, fill: false }]
            }
        }

        Section {
            visible: Cooling.fans.length > 0
            title: "FANS"
            Repeater {
                model: Cooling.fans
                KeyValue {
                    required property var modelData
                    label: modelData.name
                    value: modelData.rpm + " rpm"
                }
            }
        }

        Section {
            visible: Battery.present
            title: "BATTERY"
            Bar {
                label: (Battery.charging ? "Charging " : "On battery ") + Battery.percent + "%"
                frac: Battery.percent / 100
            }
        }
    }
}
