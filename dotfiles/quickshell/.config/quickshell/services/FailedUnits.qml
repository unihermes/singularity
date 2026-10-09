// Singularity - Quickshell
// ~/.config/quickshell/services/FailedUnits.qml
//
// systemd units in the failed state, system and user, for a bar module that
// only appears when there are any. It exists because a failed unit is
// otherwise invisible: on 2026-09-12 the polkit agent sat failed for over an
// hour after a compositor crash, and nothing on screen said so.
//
// Polled every 30s. systemctl answers in milliseconds, and failures are
// rare enough that half a minute's delay in noticing one doesn't matter.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ name, user }]
    property var units: []
    readonly property int count: units.length

    function refresh() { if (!probe.running) probe.running = true }

    // Status and recent log in a terminal, held open until a key is pressed.
    // The unit goes in as an argument, not into the script: escaped names
    // (systemd-fsck@dev-disk-by\x2duuid-….service) lose their backslashes
    // to the shell otherwise.
    function showLog(u) {
        var scope = u.user ? "--user " : ""
        Quickshell.execDetached(["alacritty", "--class", "singularity-unit-log", "-e", "bash", "-c",
            "systemctl " + scope + "status --no-pager -- \"$1\"; echo; "
            + "journalctl " + scope + "-u \"$1\" -n 40 --no-pager; echo; "
            + "read -rsn1 -p 'press any key to close'", "bash", u.name])
    }

    // System units go through polkit, so these prompt for a password there.
    function restart(u) { act(u, "restart") }
    function clear(u)   { act(u, "reset-failed") }

    // Queued, one at a time: assigning a new command to a Process that is
    // still running does nothing, so a second click before the first action
    // finished (a polkit prompt can hold one open for a while) used to be
    // dropped without a word.
    property var pending: []

    function act(u, verb) {
        var cmd = ["systemctl"]
        if (u.user) cmd.push("--user")
        cmd.push(verb, u.name)
        pending.push(cmd)
        next()
    }

    function next() {
        if (actProc.running || pending.length === 0) return
        actProc.command = pending.shift()
        actProc.running = true
    }

    Process {
        id: actProc
        command: ["true"]
        onExited: {
            root.refresh()
            root.next()
        }
    }

    // A bar glyph alone is easy to miss -- screen off, a fullscreen app, away
    // from the desk -- so a unit that wasn't failed on the last poll also gets
    // a notification. Includes the first poll after the shell starts, since a
    // compositor crash (which restarts the shell) is what took polkit down.
    function notifyNew(out) {
        var seen = {}
        for (var i = 0; i < units.length; i++) seen[(units[i].user ? "u:" : "s:") + units[i].name] = true
        for (var j = 0; j < out.length; j++) {
            var u = out[j]
            if (seen[(u.user ? "u:" : "s:") + u.name]) continue
            Quickshell.execDetached(["notify-send", "-a", "systemd", "-u", "critical",
                "Unit failed", (u.user ? "User unit " : "System unit ") + u.name + " has failed"])
        }
    }

    Process {
        id: probe
        // the user units follow a "--user" line
        command: ["sh", "-c",
            "systemctl --failed --plain --no-legend 2>/dev/null; echo --user; "
            + "systemctl --user --failed --plain --no-legend 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var user = false
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var name = lines[i].trim().split(/\s+/)[0]
                    if (name === "--user") user = true
                    else if (name !== "") out.push({ name: name, user: user })
                }
                root.notifyNew(out)
                // only on a change: a new array rebuilds the flyout's rows,
                // and with them any half-confirmed button
                if (JSON.stringify(out) !== JSON.stringify(root.units)) root.units = out
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
