// Singularity - Quickshell
// ~/.config/quickshell/services/CommandProbe.qml
//
// Whether a command is on PATH (cava, claude, checkupdates): checked at
// startup, then after each pacman transaction (tailing pacman's log) while
// missing. Installed another way: seen on the next reload.

import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    required property string name
    property bool found: false

    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v " + root.name]
        onExited: code => root.found = (code === 0)
    }

    Process {
        running: !root.found
        command: ["tail", "-n0", "-F", "/var/log/pacman.log"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("transaction completed") !== -1 && !probe.running)
                    probe.running = true
            }
        }
    }
}
