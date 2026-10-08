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

    // [{ status, id, label, detail, repairId, repairLabel, more }], in the
    // order the script emitted them; more is any further [{ id, label }]
    // repairs after the first. "ok" rows are kept: a page listing only
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

    // runs the check's first repair, or the one named by id
    function repair(check, id) {
        id = id || (check ? check.repairId : "")
        if (busyRepair !== "" || !check || !id) return
        var parts = String(id).split(":")
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
        // pacman lists them and asks before removing anything
        if (kind === "orphans") {
            terminal(check.id, "orphans=$(pacman -Qdtq); "
                + "if [ -n \"$orphans\" ]; then sudo pacman -Rns $orphans; else echo 'No orphaned packages'; fi")
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
        if (kind === "pacdiff") {
            // DIFFPROG follows $EDITOR; -f matches the scan, which finds
            // .pacsave files the pacman database doesn't list
            terminal(check.id, "pacdiff -f --sudo")
            return
        }
        if (kind === "firmware") {
            terminal(check.id, "rm -f \"${XDG_CACHE_HOME:-$HOME/.cache}/singularity/fwupd-updates\"; "
                + "fwupdmgr refresh; fwupdmgr update")
            return
        }
        // the log kinds carry a path, which can hold a colon in principle
        var issues = home + "/.config/quickshell/scripts/shell-log-issues.sh"
        var path = "'" + parts.slice(1).join(":") + "'"
        if (kind === "log") {
            // the lines the row counted, not the whole log of reloads around
            // them; paged from the end when they don't fit, where +G on a
            // short text scrolls it off the screen; -R draws the colours
            terminal(check.id, "out=$(" + issues + " " + path + "); "
                + "if [ $(printf '%s\\n' \"$out\" | wc -l) -lt $(tput lines) ]; then printf '%s\\n' \"$out\"; "
                + "else printf '%s\\n' \"$out\" | less -R +G; fi")
            return
        }
        if (kind === "log-dismiss") {
            busyRepair = check.id
            act.command = [issues, "--dismiss", parts.slice(1).join(":")]
            act.running = true
            return
        }
        if (kind === "log-fix") {
            // Claude Code in the repo, handed the lines without their colours
            if (repoPath === "") return
            terminal(check.id, "cd '" + repoPath + "' && claude \"These warnings and errors are in the "
                + "Quickshell log since the shell last loaded. Find their cause in "
                + "dotfiles/quickshell/.config/quickshell and fix it:\n\n$(" + issues + " " + path
                + " | sed 's/\\x1b\\[[0-9;]*m//g')\"")
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
                        more: [],
                    }
                    for (var j = 6; j + 1 < f.length; j += 2)
                        row.more.push({ id: f[j], label: f[j + 1] })
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
                root.lastScan = Qt.formatDateTime(new Date(), Theme.timeFormat)
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
