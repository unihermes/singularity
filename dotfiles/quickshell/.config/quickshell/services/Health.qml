// Singularity - Quickshell
// ~/.config/quickshell/services/Health.qml
//
// What's wrong with this desktop and the command that fixes it. The checks
// are scripts/health-scan.sh (runnable while the shell is down); this runs
// the repairs: systemctl directly (polkit prompts), anything else in a
// terminal. Scans only while the Health page is open and after a repair.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ status, id, label, detail, repairId, repairLabel, more }] in the
    // script's order, "ok" rows kept; `more`: further [{ id, label }] repairs
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

    // the clone this desktop is stowed from (what precedes /dotfiles/ in a
    // dotfile link); empty when the config isn't a link, so no relink offered
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
            // only the lines counted, paged from the end; -R for colours
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

    // a terminal held open after the command; the scan follows its closing
    function terminal(id, script) {
        busyRepair = id
        term.command = [Settings.terminal, "--class", "singularity.repair", "-e", "sh", "-c",
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
                    // a failed unit's record (second) replaces its
                    // enabled-but-inactive twin
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
