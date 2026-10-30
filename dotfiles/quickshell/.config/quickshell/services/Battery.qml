// Singularity - Quickshell
// ~/.config/quickshell/services/Battery.qml
//
// The machine's battery, shared by the bar, its flyout and the System
// window so they all agree on which device that is; and its level through
// the day, for the flyout.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "Format.js" as Format

Singleton {
    id: root

    // UPower's DisplayDevice is a synthetic aggregate: it reports a
    // percentage but not necessarily powerSupply, so isLaptopBattery is
    // false on it and it can't be used to decide whether this machine even
    // has a battery. Prefer the real one, fall back to the aggregate.
    readonly property UPowerDevice device: {
        var ds = UPower.devices ? UPower.devices.values : []
        for (var i = 0; i < ds.length; i++) {
            if (ds[i].isLaptopBattery) return ds[i]
        }
        return UPower.displayDevice
    }
    readonly property bool present: !!device && device.ready && device.isPresent
    readonly property int percent: device && device.ready ? Math.round(device.percentage * 100) : 0

    // --- low battery ---------------------------------------------------------

    // A notification at 15% and a critical one at 5%, once each per
    // discharge; plugging in re-arms them. Checked on every level change, so
    // waking from sleep already below one warns straight away.
    readonly property bool discharging: present && device.state === UPowerDeviceState.Discharging
    readonly property var warnLevels: [15, 5]
    // the lowest level warned about since the charger was last in
    property int warned: 101

    onPercentChanged: checkLow()
    onDischargingChanged: checkLow()

    function checkLow() {
        if (!discharging) { warned = 101; return }
        var hit = warnLevels.filter(l => percent <= l && l < warned)
        if (hit.length === 0) return
        warned = hit[hit.length - 1]
        var critical = warned <= 5
        var left = device.timeToEmpty > 0 ? ", about " + Format.duration(device.timeToEmpty) + " left" : ""
        var cmd = ["notify-send", "-a", "Battery", "-u", critical ? "critical" : "normal",
                   "-i", critical ? "battery-empty" : "battery-caution",
                   critical ? "Battery critically low" : "Battery low",
                   percent + "%" + left + (critical ? ". Plug in now." : "")]
        // -A waits for the notification to close and prints the action picked
        if (PpdProfile.profile !== "power-saver")
            cmd.push("-A", "saver=Power saver")
        var proc = critical ? criticalAlert : lowAlert
        proc.command = cmd
        proc.running = false
        proc.running = true
    }

    // One per level: restarting a shared one for the 5% warning killed the
    // 15% one's notify-send, which is what was waiting for its button.
    function picked(text) { if (text.trim() === "saver") PpdProfile.set("power-saver") }
    Process {
        id: lowAlert
        stdout: StdioCollector { onStreamFinished: root.picked(text) }
    }
    Process {
        id: criticalAlert
        stdout: StdioCollector { onStreamFinished: root.picked(text) }
    }

    // --- the charge over the day -------------------------------------------

    // [{ t (ms), v (0..1), c (charging) }] every five minutes and on each
    // plug or unplug, the last day of it, kept in the state dir so it
    // outlasts a restart or reboot; the flyout's graph
    readonly property real historyWindow: 24 * 3600000
    property var history: []
    readonly property bool charging: present && (device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.FullyCharged || device.state === UPowerDeviceState.PendingCharge)

    function sample() {
        if (!present || !historyFile.loadedOnce) return
        var now = Date.now()
        var kept = history.filter(p => p.t > now - historyWindow)
        kept.push({ t: now, v: percent / 100, c: charging })
        history = kept
        historyFile.setText(JSON.stringify(kept))
    }
    onChargingChanged: sample()
    onPresentChanged: sample()

    FileView {
        id: historyFile
        property bool loadedOnce: false
        path: Settings.stateDir + "/battery-history.json"
        preload: true
        // no file until the first sample
        printErrors: false
        onLoaded: {
            try { root.history = JSON.parse(text()) || [] } catch (e) { root.history = [] }
            loadedOnce = true
            root.sample()
        }
        onLoadFailed: {
            loadedOnce = true
            root.sample()
        }
    }
    Timer {
        interval: 300000
        repeat: true
        running: root.present
        onTriggered: root.sample()
    }
}
