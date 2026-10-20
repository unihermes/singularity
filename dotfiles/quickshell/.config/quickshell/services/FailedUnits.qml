// Singularity - Quickshell
// ~/.config/quickshell/services/FailedUnits.qml
//
// Failed systemd units, system and user, for a bar module shown only when
// there are any. Polled every 30s.

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

    // status and log in a terminal; the unit as an argument so escaped names
    // keep their backslashes
    function showLog(u) {
        var scope = u.user ? "--user " : ""
        Quickshell.execDetached([Settings.terminal, "--class", "singularity.unit-log", "-e", "bash", "-c",
            "systemctl " + scope + "status --no-pager -- \"$1\"; echo; "
            + "journalctl " + scope + "-u \"$1\" -n 40 --no-pager; echo; "
            + "read -rsn1 -p 'press any key to close'", "bash", u.name])
    }

    // System units go through polkit, so these prompt for a password there.
    function restart(u) { act(u, "restart") }
    function clear(u)   { act(u, "reset-failed") }

    // actions queued, one at a time (a running Process ignores a new command)
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

    // a unit newly failed also notifies, including on the first poll (a
    // compositor crash restarts the shell too)
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
