// Singularity - Quickshell
// ~/.config/quickshell/services/Brightness.qml
//
// Backlight level, 0..100. One instance for the whole shell rather than one
// per bar: the backlight is system-wide, and a copy per screen meant every
// monitor ran its own sysfs watcher and its own write debounce, each able to
// echo the other's writes back as stale values.
//
// Read straight from sysfs and *watched*, not polled: the backlight
// attribute emits change notifications, so the level follows the
// XF86MonBrightness keys (and anything else that writes to it) the same way
// the Pipewire-backed volume follows external changes. brightnessctl is
// still used to write, since sysfs isn't user-writable.

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

    // A drag or a fast scroll can call this dozens of times a second.
    // Spawning a brightnessctl process on every one made both jumpy: forking
    // that often is real overhead, and with several in flight there's no
    // guarantee they land in sysfs in launch order -- so the watched file
    // could echo back an *older* value after a newer one, snapping the level
    // backwards mid-drag. writeDebounce keeps one write in flight at a time;
    // `echo` tells the file reload to trust this optimistic value over a
    // stale echo while an adjustment is still active.
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

    // Cleared a little after the last set() call, not right after the
    // debounced write fires -- the write is detached, so there's no signal
    // for when it (and its resulting file event) has actually landed.
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
