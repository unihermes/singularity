// Singularity - Quickshell
// ~/.config/quickshell/desktop/DesktopSidebar.qml
//
// A conky-style column down the right edge of the primary display, on the
// wallpaper under the windows (Settings.deskSidebar). The time and date,
// then a section each under a ruled heading: the system, CPU (with a strip
// of its cores), GPU, memory, disks, network, the busiest processes, fans
// and the battery, as label/value rows with thin meters and the last
// minute as sparklines. A section the machine can't fill is left out.
// The desktop widgets keep clear of it (DesktopWidgets' area).

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
    readonly property int columnWidth: Theme.fit(300)
    readonly property int margin: Theme.sp(40)

    screen: scope.modelData
    visible: here
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop-widget"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; right: true }
    margins.top: (Theme.barPosition === "bottom" ? 0 : Theme.barExtent) + margin - pad
    margins.right: margin - pad
    implicitWidth: columnWidth + pad * 2
    implicitHeight: body.implicitHeight + pad * 2
    // room round the column for the shadow
    readonly property int pad: Theme.sp(24)
    // nothing on it takes the pointer
    mask: Region {}

    // the inks and type, as WidgetCard has them, for WidgetText
    Item {
        id: ink
        readonly property color fg: "#ffffff"
        readonly property color fgDim: Qt.rgba(1, 1, 1, 0.8)
        readonly property color track: Qt.rgba(1, 1, 1, 0.22)
        readonly property color accent: Qt.lighter(Theme.accent, 1.6)
        readonly property string font: Theme.fontText
        readonly property int textCaption: Theme.fit(13)
        readonly property int textBody: Theme.fit(14)
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

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // the real filesystems, largest first, three at most
    readonly property var disks: SystemStats.filesystems.filter(f => f.size >= 1073741824).slice(0, 3)
    readonly property bool hasGpu: Cooling.gpuLoad >= 0 || Cooling.gpuC >= 0
    // the network's sparklines share a scale: the busiest second shown
    readonly property real netPeak: Math.max(1024, ...SystemStats.rxHistory, ...SystemStats.txHistory)

    component Row2: Item {
        property alias label: l.text
        property alias value: r.text
        property bool dimLabel: false
        property bool dimValue: false
        width: parent.width
        height: Math.max(l.implicitHeight, r.implicitHeight)
        WidgetText { id: l; card: ink; width: parent.width - r.implicitWidth - Theme.spaceS; color: parent.dimLabel ? ink.fgDim : ink.fg }
        WidgetText { id: r; card: ink; anchors.right: parent.right; color: parent.dimValue ? ink.fgDim : ink.fg; font.features: { "tnum": 1 } }
    }
    component Meter: Rectangle {
        property real frac: 0
        width: parent.width
        height: Theme.fit(4)
        radius: height / 2
        color: ink.track
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.frac))
            height: parent.height
            radius: parent.radius
            color: parent.frac >= 0.85 ? Theme.alert : ink.fg
            Behavior on width { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease } }
        }
    }
    component Section: Column {
        property string title: ""
        width: parent.width
        spacing: Theme.fit(4)
        Item {
            width: parent.width
            height: heading.implicitHeight + Theme.fit(2)
            WidgetText {
                id: heading
                card: ink
                text: (Theme.headingPrefix !== "" ? Theme.headingPrefix + " " : "") + parent.parent.title
                font.weight: ink.weightStrong
                font.letterSpacing: 1
            }
            Rectangle {
                anchors.left: heading.right
                anchors.leftMargin: Theme.spaceS
                anchors.right: parent.right
                anchors.verticalCenter: heading.verticalCenter
                height: 1
                color: Qt.rgba(1, 1, 1, 0.4)
            }
        }
    }
    component Line: Spark {
        width: parent.width
        height: Theme.fit(24)
        bare: true
    }

    Column {
        id: body
        x: win.pad
        y: win.pad
        width: win.columnWidth
        spacing: Theme.fit(14)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 1)
            blurMax: 8
            shadowBlur: 0.6
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }

        Column {
            width: parent.width
            WidgetText {
                anchors.right: parent.right
                card: ink
                px: Theme.fit(46)
                font.weight: ink.weightStrong
                text: Qt.formatTime(clock.date, Theme.hours("HH:mm"))
            }
            WidgetText {
                anchors.right: parent.right
                card: ink
                color: ink.fgDim
                text: Qt.formatDate(clock.date, "dddd d MMMM")
            }
        }

        Section {
            title: "SYSTEM"
            Row2 { label: "host"; dimLabel: true; value: SystemSpecs.hostname }
            Row2 { label: "kernel"; dimLabel: true; value: SystemSpecs.kernel }
            Row2 { label: "uptime"; dimLabel: true; value: Format.duration(SystemStats.uptimeSec) }
        }

        Section {
            title: "CPU"
            Row2 { label: win.shortModel(SystemSpecs.cpuModel) || "CPU"; value: Format.pct(SystemStats.cpu) }
            Meter { frac: SystemStats.cpu }
            Row2 {
                dimLabel: true; dimValue: true
                label: SystemStats.cpuMhz > 0 ? (SystemStats.cpuMhz / 1000).toFixed(2) + " GHz" : ""
                value: win.temp(SystemStats.tempC)
            }
            // a bar per core, filling up from the foot
            Row {
                width: parent.width
                height: Theme.fit(16)
                spacing: 2
                Repeater {
                    model: SystemStats.cores.length
                    Rectangle {
                        required property int index
                        width: (parent.width - parent.spacing * (SystemStats.cores.length - 1)) / SystemStats.cores.length
                        height: parent.height
                        color: ink.track
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * Math.max(0, Math.min(1, SystemStats.cores[parent.index] || 0))
                            color: ink.fg
                        }
                    }
                }
            }
            Line { series: [{ values: SystemStats.cpuHistory, color: ink.fg, fill: true }] }
        }

        Section {
            visible: win.hasGpu
            title: "GPU"
            Row2 {
                label: win.shortModel(SystemSpecs.gpuModel) || "GPU"
                value: Cooling.gpuLoad >= 0 ? Cooling.gpuLoad + "%" : ""
            }
            Meter { visible: Cooling.gpuLoad >= 0; frac: Cooling.gpuLoad / 100 }
            Row2 {
                dimLabel: true; dimValue: true
                label: Cooling.gpuWatts >= 0 ? Math.round(Cooling.gpuWatts) + " W" : ""
                value: win.temp(Cooling.gpuC)
            }
            // its temperature over the last few minutes, 30 to 100 °C
            Line {
                visible: Cooling.gpuHistory.length > 1
                floor: 30
                ceiling: 100
                historyLength: Cooling.historyLength
                series: [{ values: Cooling.gpuHistory, color: ink.fg, fill: true }]
            }
        }

        Section {
            visible: SystemStats.memTotalKb > 0
            title: "MEMORY"
            Row2 {
                label: Format.bytes(SystemStats.memUsedKb * 1024) + " / " + Format.bytes(SystemStats.memTotalKb * 1024)
                value: Format.pct(SystemStats.mem)
            }
            Meter { frac: SystemStats.mem }
            Row2 {
                visible: SystemStats.swapTotalKb > 0
                label: "swap"; dimLabel: true; dimValue: true
                value: Format.bytes((SystemStats.swapTotalKb - SystemStats.swapFreeKb) * 1024)
            }
        }

        Section {
            visible: win.disks.length > 0
            title: "DISKS"
            Repeater {
                model: win.disks
                Column {
                    required property var modelData
                    width: parent.width
                    spacing: Theme.fit(3)
                    Row2 {
                        label: modelData.target
                        dimValue: true
                        value: Format.bytes(modelData.used) + " / " + Format.bytes(modelData.size)
                    }
                    Meter { frac: modelData.used / modelData.size }
                }
            }
            Row2 {
                visible: SystemStats.diskRead >= 0
                dimLabel: true
                label: "R " + Format.rate(SystemStats.diskRead) + " · W " + Format.rate(SystemStats.diskWrite)
            }
        }

        Section {
            visible: SystemStats.iface !== ""
            title: "NETWORK"
            Row2 { label: SystemStats.iface; value: SystemStats.ipAddr; dimValue: true }
            Row2 { label: "↓ " + Format.rate(SystemStats.rxRate); value: "↑ " + Format.rate(SystemStats.txRate) }
            Line {
                height: Theme.fit(20)
                ceiling: win.netPeak
                series: [{ values: SystemStats.rxHistory, color: ink.fg, fill: true },
                         { values: SystemStats.txHistory, color: ink.fgDim, fill: false }]
            }
        }

        Section {
            visible: SystemStats.procs.length > 0
            title: "PROCESSES"
            Repeater {
                model: SystemStats.procs.slice(0, 5)
                Item {
                    required property var modelData
                    width: parent.width
                    height: pname.implicitHeight
                    WidgetText { id: pname; card: ink; width: parent.width - Theme.fit(120); text: modelData.name }
                    WidgetText {
                        anchors.right: pmem.left
                        anchors.rightMargin: Theme.spaceM
                        card: ink
                        font.features: { "tnum": 1 }
                        text: modelData.cpu.toFixed(1) + "%"
                    }
                    WidgetText {
                        id: pmem
                        anchors.right: parent.right
                        width: Theme.fit(44)
                        horizontalAlignment: Text.AlignRight
                        card: ink
                        color: ink.fgDim
                        font.features: { "tnum": 1 }
                        text: modelData.memKb > 0 ? Format.kib(modelData.memKb) : ""
                    }
                }
            }
        }

        Section {
            visible: Cooling.fans.length > 0
            title: "FANS"
            Repeater {
                model: Cooling.fans
                Row2 {
                    required property var modelData
                    label: modelData.name; dimLabel: true
                    value: modelData.rpm + " rpm"
                }
            }
        }

        Section {
            visible: Battery.present
            title: "BATTERY"
            Row2 {
                label: Battery.charging ? "Charging" : "On battery"
                value: Battery.percent + "%"
            }
            Meter { frac: Battery.percent / 100 }
        }
    }
}
