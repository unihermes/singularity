// Singularity - Quickshell
// ~/.config/quickshell/windows/system/HomeFigures.qml
//
// The four headline figures over System's Home: CPU, memory, temperature
// and the battery (the root disk on a machine without one), each with its
// last minute, each opening the page it summarises.

import QtQuick
import "../../services"
import "../../services/Format.js" as Format
import "../system"

Item {
    id: root

    signal activated(string id)

    width: parent ? parent.width : 0
    implicitHeight: row.implicitHeight

    Row {
        id: row
        width: parent.width
        spacing: Theme.spaceM

        readonly property int cellWidth: (width - spacing * 3) / 4

        StatCard {
            width: parent.cellWidth
            caption: "CPU"
            value: SystemStats.cpuHistory.length > 0 ? Format.pct(SystemStats.cpu) : "--"
            fraction: SystemStats.cpu
            critical: SystemStats.cpu >= 0.9
            history: SystemStats.cpuHistory
            detail: SystemStats.cpuMhz > 0
                ? (SystemStats.cpuMhz / 1000).toFixed(2) + " GHz · " + SystemStats.cores.length + "T"
                : SystemStats.cores.length + " threads"
            onActivated: root.activated("cpu")
        }

        StatCard {
            width: parent.cellWidth
            caption: "Memory"
            value: Format.pct(SystemStats.mem)
            fraction: SystemStats.mem
            critical: SystemStats.mem >= 0.9
            history: SystemStats.memHistory
            detail: Format.kib(SystemStats.memUsedKb) + " of " + Format.kib(SystemStats.memTotalKb)
            onActivated: root.activated("memory")
        }

        StatCard {
            width: parent.cellWidth
            caption: "Temp"
            available: SystemStats.tempC >= 0
            value: SystemStats.tempC >= 0 ? Math.round(SystemStats.tempC) + "°C" : "--"
            // 100C spans the bar: Intel mobile chips throttle in the high
            // 90s, so a full bar means what it looks like it means
            fraction: SystemStats.tempC / 100
            critical: SystemStats.tempC >= 90
            // the line from 30 °C, where an idle laptop sits, so a warm-up shows
            history: SystemStats.tempHistory
            historyFloor: 30
            historyCeiling: 100
            detail: SystemStats.sensors.length > 1
                ? "CPU · " + SystemStats.sensors.length + " sensors"
                : SystemStats.tempC >= 0 ? "CPU package" : "no sensor"
            onActivated: root.activated("hardware")
        }

        StatCard {
            width: parent.cellWidth
            caption: SystemStats.batNowWh > 0 ? "Battery" : "Disk"
            available: SystemStats.batNowWh > 0 || SystemStats.diskSize > 0
            value: SystemStats.batNowWh > 0
                ? (Number(SystemStats.bat.capacity) || 0) + "%"
                : SystemStats.diskSize > 0 ? Format.pct(SystemStats.diskUsed / SystemStats.diskSize) : "--"
            fraction: SystemStats.batNowWh > 0
                ? (Number(SystemStats.bat.capacity) || 0) / 100
                : SystemStats.diskSize > 0 ? SystemStats.diskUsed / SystemStats.diskSize : 0
            critical: SystemStats.batNowWh > 0
                ? !SystemStats.batCharging && Number(SystemStats.bat.capacity) <= 15
                : SystemStats.diskSize > 0 && SystemStats.diskUsed / SystemStats.diskSize >= 0.9
            history: SystemStats.batNowWh > 0 ? SystemStats.batHistory : []
            detail: SystemStats.batNowWh > 0
                // short enough for a quarter-width card: the time, then the draw
                ? (SystemStats.batHours > 0
                    ? Format.duration(SystemStats.batHours * 3600) + (SystemStats.batCharging ? " to full" : " left")
                    : SystemStats.batCharging ? "charging" : "on battery")
                  + (SystemStats.batWatts > 0 ? " · " + SystemStats.batWatts.toFixed(1) + " W" : "")
                : SystemStats.diskSize > 0
                    ? Format.bytes(SystemStats.diskSize - SystemStats.diskUsed) + " free" : "--"
            onActivated: root.activated(SystemStats.batNowWh > 0 ? "power" : "storage")
        }
    }
}
