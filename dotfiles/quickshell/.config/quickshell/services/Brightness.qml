// Singularity - Quickshell
// ~/.config/quickshell/services/Brightness.qml
//
// Backlight level, 0..100, once for the whole shell. Read from sysfs and
// watched (so the brightness keys show); written with brightnessctl.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int level: 0
    readonly property bool available: backlightDir !== "" && maxRaw > 0

    property string backlightDir: ""
    property int maxRaw: 0

    // one write in flight at a time (writeDebounce), as many brightnessctl
    // runs could land out of order and snap the level back; `echo` trusts
    // this value over a stale file echo while adjusting
    property int pendingWrite: -1
    property bool echo: false

    function set(pct) {
        // clamped at 1, not 0: brightnessctl will happily set a laptop panel
        // to fully black and leave you guessing
        var v = Math.max(1, Math.min(100, Math.round(pct)))
        level = v
        echo = true
        echoGuard.restart()
        pendingWrite = v
        writeDebounce.restart()
    }

    Timer {
        id: writeDebounce
        interval: 35
        onTriggered: {
            if (root.pendingWrite < 0) return
            Quickshell.execDetached(["brightnessctl", "set", root.pendingWrite + "%"])
            root.pendingWrite = -1
        }
    }

    // cleared a little after the last set() (the write is detached, so
    // there's no signal for when it lands)
    Timer {
        id: echoGuard
        interval: 350
        onTriggered: root.echo = false
    }

    Process {
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.backlightDir = text.trim().replace(/\/$/, "")
        }
    }

    FileView {
        path: root.backlightDir !== "" ? root.backlightDir + "/max_brightness" : ""
        onLoaded: {
            var v = parseInt(text().trim())
            if (!isNaN(v) && v > 0) {
                root.maxRaw = v
                levelFile.reload()
            }
        }
    }

    FileView {
        id: levelFile
        path: root.backlightDir !== "" ? root.backlightDir + "/brightness" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            if (root.echo) return
            var raw = parseInt(text().trim())
            if (!isNaN(raw) && root.maxRaw > 0)
                root.level = Math.round(raw / root.maxRaw * 100)
        }
    }
}
