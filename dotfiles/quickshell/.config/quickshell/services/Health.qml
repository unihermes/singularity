// Singularity - Quickshell
// ~/.config/quickshell/services/Health.qml
//
// What is wrong with this desktop right now, and -- where there is one -- the
// single command that fixes it.
//
// The checks themselves are scripts/health-scan.sh, which reads the machine
// and prints one TSV record per finding; see its header for the list and for
// what each repair id means. Keeping them in a script rather than here is
// what makes them runnable (and testable) while the shell is down, which is
// when a desktop is most likely to be broken.
//
// This half does two things the script can't: it runs the repair a record
// names, and it decides how. systemctl runs directly -- a system unit prompts
// through the polkit agent, which is already running. Everything else opens a
// terminal, because those repairs either ask questions (pacman) or print a
// wall of output (the log), and a visible terminal is also the honest way to
// show what is about to run as root.
//
// Scanning only happens while the Health page is open, and again after any
// repair. Nothing polls: FailedUnits already watches the one signal urgent
// enough to interrupt someone, and a scan forks a couple of dozen processes,
// which is not a thing to do every thirty seconds for a page nobody has open.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ status, id, label, detail, repairId, repairLabel }], in the order
    // the script emitted them. "ok" rows are kept: a page listing only
    // problems says nothing on a healthy machine, which looks the same as a
    // page that failed to run.
    property var checks: []
    property bool scanning: false
    // "" until the first scan finishes
    property string lastScan: ""
    // the repair currently running, "" for none -- one at a time, so a second
    // click while polkit is waiting can't start another
    property string busyRepair: ""

    readonly property int problems: checks.filter(c => c.status === "bad").length
    readonly property int warnings: checks.filter(c => c.status === "warn").length
    readonly property bool healthy: !scanning && lastScan !== "" && problems === 0 && warnings === 0

    // set by the Health page while it is on screen
    property bool active: false
    onActiveChanged: if (active) scan()

    readonly property string home: Quickshell.env("HOME")

    function scan() {
        if (probe.running) return
        scanning = true
        probe.running = true
    }

    // --- repairs -----------------------------------------------------------

    // The clone this desktop is stowed from, found by following a link we
    // know is one of its own: every dotfile lands as a symlink into
    // <repo>/dotfiles/<package>/..., so what precedes /dotfiles/ is the repo,
    // wherever it was cloned. Empty when the config is a real file rather
    // than a link, which is exactly the case where relinking is the wrong
    // thing to offer.
    property string repoPath: ""

    function repair(check) {
        if (busyRepair !== "" || !check || !check.repairId) return
        var parts = String(check.repairId).split(":")
        var kind = parts[0]

        if (kind === "restart" || kind === "disable") {
            var cmd = ["systemctl"]
            if (parts[1] === "user") cmd.push("--user")
            cmd.push(kind, parts[2])
            busyRepair = check.id
            act.command = cmd
            act.running = true
            return
        }
        if (kind === "install") {
            // the tools arrive space-separated, which is what pacman wants
            terminal(check.id, "yay -S --needed " + parts.slice(1).join(":"))
            return
        }
        if (kind === "clean") {
            terminal(check.id, home + "/.config/singularity/clean.sh")
            return
        }
        if (kind === "relink") {
            if (repoPath === "") return
            terminal(check.id, "cd '" + repoPath + "' && ./link.sh")
            return
        }
        if (kind === "log") {
            // the id carries a path, which can hold a colon in principle
            terminal(check.id, "less +G '" + parts.slice(1).join(":") + "'")
        }
    }

    // A terminal held open after the command finishes: half of these print
    // their answer and exit, and a window that closes on the last line shows
    // nothing. The scan follows it closing, by which time the repair has run.
    function terminal(id, script) {
        busyRepair = id
        term.command = ["alacritty", "--class", "singularity-repair", "-e", "sh", "-c",
            script + "; echo; read -rsn1 -p 'press any key to close'"]
        term.running = true
    }

    Process {
        id: act
        command: ["true"]
        onExited: {
            root.busyRepair = ""
            root.scan()
        }
    }

    Process {
        id: term
        command: ["true"]
        onExited: {
            root.busyRepair = ""
            root.scan()
        }
    }

    // --- the scan ----------------------------------------------------------

    Process {
        id: probe
        command: [root.home + "/.config/quickshell/scripts/health-scan.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var seen = {}
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("\t")
                    if (f.length < 4 || f[0] === "") continue
                    var row = {
                        status: f[0],
                        id: f[1],
                        label: f[2],
                        detail: f[3],
                        repairId: f[4] || "",
                        repairLabel: f[5] || "",
                    }
                    // A unit can be both enabled-but-inactive and failed. The
                    // failed record is the one worth showing and is emitted
                    // second, so it replaces its twin rather than doubling it.
                    var key = row.id.replace(/^(unit|failed):/, "")
                    if (seen[key] !== undefined) out[seen[key]] = row
                    else {
                        seen[key] = out.length
                        out.push(row)
                    }
                }
                root.checks = out
                root.scanning = false
                root.lastScan = Qt.formatDateTime(new Date(), "HH:mm")
            }
        }
    }

    // Resolved once at startup: the clone doesn't move while the shell runs.
    Process {
        running: true
        command: ["sh", "-c",
            'p=$(readlink -f "$HOME/.config/quickshell/shell.qml" 2>/dev/null); '
            + 'case "$p" in */dotfiles/*) printf "%s" "${p%%/dotfiles/*}" ;; esac']
        stdout: StdioCollector {
            onStreamFinished: root.repoPath = text.trim()
        }
    }
}
