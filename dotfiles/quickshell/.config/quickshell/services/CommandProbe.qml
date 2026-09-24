// Singularity - Quickshell
// ~/.config/quickshell/services/CommandProbe.qml
//
// Whether a command is on PATH, for the services that only work when an
// optional tool is installed (cava, claude, checkupdates).
//
// Checked once at startup, then again after each pacman transaction for as
// long as it's missing -- these tools tend to be installed while the bar is
// already up, and a one-off check would leave their feature dead until the
// next login. What used to do that was a `command -v` every 10s, forever, on
// any machine without the tool. This instead follows pacman's log with tail,
// which blocks on inotify: no wakeups until something is installed, and no
// process at all once the command is found. A tool installed some other way
// (npm, a copy into ~/.local/bin) shows up on the next shell reload.

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
