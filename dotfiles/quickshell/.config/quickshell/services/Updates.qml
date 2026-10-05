// Singularity - Quickshell
// ~/.config/quickshell/services/Updates.qml
//
// Pending package updates, repo and AUR, for a bar module that only appears
// when there are some.
//
// checkupdates (pacman-contrib) rather than `pacman -Qu`: it syncs a
// throwaway copy of the database in /tmp, so it sees what's new without
// root and without touching the real sync db -- a `pacman -Sy` here would
// set up a partial upgrade. `yay -Qua` asks the AUR's RPC for the rest.
//
// First check one minute after startup, then every Settings.updateInterval
// minutes (Settings -> Software Update). Packages in Settings.updateIgnore
// are left out of the count and the upgrade, and the AUR only counts while
// Settings.updateAur is on.
//
// The same checks also fetch the Singularity clone the shell is stowed from
// and count the commits waiting upstream; updateRepo() runs its update.sh.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ name, from, to, aur }], everything the last check found
    property var found: []
    // what counts: the AUR's only while it's included, and nothing ignored
    readonly property var packages: found.filter(p =>
        (Settings.updateAur || !p.aur) && Settings.updateIgnore.indexOf(p.name) < 0)
    readonly property int count: packages.length
    readonly property int aurCount: packages.filter(p => p.aur).length
    readonly property bool available: availProbe.found      // checkupdates is installed
    property bool checking: false
    property var lastChecked: null
    // when pacman last ran a full upgrade, from its log; null if never
    property var lastUpgrade: null
    // how many packages that upgrade changed
    property int lastUpgradeCount: 0
    readonly property bool updating: updateProc.running
    // when the timer next checks: an interval after the last check, which
    // restarts it; null while checking only by hand
    readonly property var nextCheck: Settings.updateInterval > 0 && lastChecked !== null && every.running
        ? new Date(lastChecked.getTime() + Settings.updateInterval * 60000) : null

    // --- Singularity's own clone --------------------------------------------

    // the clone, found from where shell.qml links to; "" when it isn't a link
    property string repoPath: ""
    // "ok", "fetch" (counted against the last fetch), "noupstream", "none"
    property string repoState: ""
    property string repoUpstream: ""
    property int repoBehind: 0
    property int repoAhead: 0
    // [{ hash, time, subject }], newest first
    property var repoCommits: []
    // packages upstream's packages/*.txt list that aren't installed
    property var repoNewPackages: []
    property bool repoChecking: false
    // set when update.sh starts; it calls `updates finished` when it ends
    property bool repoUpdating: false

    function refreshRepo() {
        if (repoProc.running) return
        repoChecking = true
        repoProc.running = true
    }

    // In a detached terminal: a pull that changes the shell reloads it, and a
    // Process child would go down with the old one.
    function updateRepo() {
        if (repoUpdating || repoPath === "" || repoBehind === 0) return
        repoUpdating = true
        Quickshell.execDetached(["alacritty", "--class", "singularity-update", "-e", "bash", "-c",
            "trap 'qs ipc call updates finished >/dev/null 2>&1' EXIT; trap exit HUP TERM; cd \"$1\" && ./update.sh; "
            + "if [ $? -eq 0 ]; then notify-send -a Updates 'Singularity updated' 'Pulled, relinked and installed'; "
            + "else echo; echo 'Update failed -- see above.'; read -rsn1 -p 'press any key to close'; fi",
            "bash", repoPath])
    }

    function saveCache() {
        cache.save({
            found: root.found,
            lastChecked: root.lastChecked ? root.lastChecked.toISOString() : null,
            repo: { path: root.repoPath, state: root.repoState, upstream: root.repoUpstream,
                behind: root.repoBehind, ahead: root.repoAhead, commits: root.repoCommits,
                newPackages: root.repoNewPackages },
        })
    }

    function refresh() {
        refreshRepo()
        if (!available || checkProc.running) return
        checking = true
        checkProc.running = true
    }

    // yay does repo and AUR in one pass:
    //   --sudoloop       keeps sudo's timestamp fresh, so a long AUR build
    //                    doesn't ask again when pacman installs at the end
    //   --answerclean None, --answeredit None
    //                    skip yay's clean-build and PKGBUILD-edit menus
    //   --removemake     drops build-only deps without asking
    //   --noconfirm, --answerdiff None
    //                    no install prompt or PKGBUILD diffs, so after the
    //                    sudo prompt it runs unattended, AUR included
    // On success the terminal closes itself with a notification; on failure
    // it stays open so the error can be read. Either way the list is
    // re-checked once it closes.
    // --ignore takes Settings.updateIgnore, which Settings has already
    // limited to names.
    function update() {
        if (updateProc.running) return
        var flags = " --noconfirm --answerdiff None" + (Settings.updateAur ? "" : " --repo")
            + (Settings.updateIgnore.length > 0 ? " --ignore " + Settings.updateIgnore.join(",") : "")
        updateProc.command = ["alacritty", "--class", "singularity-update", "-e", "sh", "-c",
            "yay -Syu" + flags + " --sudoloop --answerclean None --answeredit None --removemake; "
            + "if [ $? -eq 0 ]; then notify-send -a Updates 'System updated' 'All packages are up to date'; "
            + "else echo; echo 'Update failed -- see above.'; read -rsn1 -p 'press any key to close'; fi"]
        updateProc.running = true
    }

    CommandProbe { id: availProbe; name: "checkupdates" }

    Process {
        id: checkProc
        // checkupdates exits 1 on failure (db sync lock contention, network
        // hiccup, ...) and 2 when there's simply nothing to update -- both
        // print nothing, so the exit code is the only way to tell "checked,
        // found none" from "check failed". yay -Qua exits 1 for both, like
        // pacman -Qu, so there a silent exit 1 means none and an exit 1 with
        // an error on stderr means failed; it's mapped to 2 / left at 1.
        // Report it per source and, on failure, keep that source's previous
        // results instead of silently wiping them to zero.
        command: ["sh", "-c",
            "out=$(checkupdates 2>/dev/null); rc=$?; "
            + "printf '%s\\n' \"$out\" | sed '/^$/d;s/^/repo /'; "
            + "echo \"REPO_STATUS $rc\"; "
            + "if [ \"$AUR\" = 1 ] && command -v yay >/dev/null; then "
            + "err=$(mktemp); out=$(yay -Qua 2>\"$err\"); rc=$?; "
            + "[ $rc -eq 1 ] && [ -z \"$out\" ] && [ ! -s \"$err\" ] && rc=2; rm -f \"$err\"; "
            + "printf '%s\\n' \"$out\" | sed '/^$/d;s/^/aur /'; "
            + "echo \"AUR_STATUS $rc\"; "
            + "else echo 'AUR_STATUS skip'; fi"]
        environment: ({ AUR: Settings.updateAur ? "1" : "0" })
        stdout: StdioCollector {
            onStreamFinished: {
                var repoStatus = null, aurStatus = null
                var repo = [], aur = []
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.indexOf("REPO_STATUS") === 0) { repoStatus = line.split(/\s+/)[1]; continue }
                    if (line.indexOf("AUR_STATUS") === 0) { aurStatus = line.split(/\s+/)[1]; continue }
                    // "repo name 1.0-1 -> 1.1-1"
                    var f = line.split(/\s+/)
                    if (f.length >= 5 && f[3] === "->") {
                        var pkg = { name: f[1], from: f[2], to: f[4], aur: f[0] === "aur" }
                        ;(pkg.aur ? aur : repo).push(pkg)
                    }
                }
                var out = []
                out = out.concat(repoStatus === "0" || repoStatus === "2"
                    ? repo : root.found.filter(p => !p.aur))
                out = out.concat(aurStatus === "0" || aurStatus === "2" || aurStatus === "skip"
                    ? aur : root.found.filter(p => p.aur))
                out.sort((a, b) => a.name.localeCompare(b.name))
                root.found = out
                root.lastChecked = new Date()
                root.saveCache()
            }
        }
        onExited: {
            root.checking = false
            if (every.running) every.restart()
            logProc.running = true
        }
    }

    Process {
        id: logProc
        // the last upgrade's start, then how many packages it upgraded
        command: ["sh", "-c", "awk '/starting full system upgrade/ { t = $1; n = 0 } "
            + "/\\[ALPM\\] upgraded / { n++ } END { if (t) print t, n }' /var/log/pacman.log"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = /^\[([^\]]+)\]\s+(\d+)/.exec(text.trim())
                root.lastUpgrade = m ? new Date(m[1].replace(/([+-]\d\d)(\d\d)$/, "$1:$2")) : null
                root.lastUpgradeCount = m ? Number(m[2]) : 0
            }
        }
    }

    // Fetches, then reports, one line each:
    //   PATH <clone>  STATE <state>  UPSTREAM origin/main  COUNT <ahead> <behind>
    //   COMMIT <hash> <unix time> <subject>  NEW <package>
    Process {
        id: repoProc
        command: ["sh", "-c",
            "p=$(readlink -f \"$HOME/.config/quickshell/shell.qml\" 2>/dev/null); "
            + "case \"$p\" in */dotfiles/*) r=${p%%/dotfiles/*} ;; *) echo 'STATE none'; exit ;; esac; "
            + "echo \"PATH $r\"; cd \"$r\" || exit; "
            + "u=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || { echo 'STATE noupstream'; exit; }; "
            + "echo \"UPSTREAM $u\"; "
            + "if GIT_TERMINAL_PROMPT=0 timeout 60 git fetch --quiet 2>/dev/null; then echo 'STATE ok'; else echo 'STATE fetch'; fi; "
            + "git rev-list --left-right --count 'HEAD...@{u}' | sed 's/^/COUNT /'; "
            + "git log --format='COMMIT %h %ct %s' 'HEAD..@{u}'; "
            + "for f in pacman aur; do git show \"@{u}:packages/$f.txt\" 2>/dev/null; done "
            + "| sed -e 's/#.*//' -e '/^[[:space:]]*$/d' | xargs -r pacman -T | sed 's/^/NEW /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var path = "", state = "", upstream = "", ahead = 0, behind = 0, commits = [], fresh = []
                text.split("\n").forEach(line => {
                    var m = /^(\S+) ?(.*)$/.exec(line)
                    if (!m) return
                    var v = m[2]
                    if (m[1] === "PATH") path = v
                    else if (m[1] === "STATE") state = v
                    else if (m[1] === "UPSTREAM") upstream = v
                    else if (m[1] === "COUNT") {
                        var n = v.split(/\s+/)
                        ahead = Number(n[0]) || 0
                        behind = Number(n[1]) || 0
                    } else if (m[1] === "COMMIT") {
                        var c = /^(\S+) (\d+) (.*)$/.exec(v)
                        if (c) commits.push({ hash: c[1], time: Number(c[2]) * 1000, subject: c[3] })
                    } else if (m[1] === "NEW") fresh.push(v)
                })
                root.repoPath = path
                root.repoState = state
                root.repoUpstream = upstream
                root.repoAhead = ahead
                root.repoBehind = behind
                root.repoCommits = commits
                root.repoNewPackages = fresh
                root.saveCache()
            }
        }
        onExited: root.repoChecking = false
    }

    IpcHandler {
        target: "updates"
        // `qs ipc call updates check`
        function check(): void { root.refresh() }
        function finished(): void {
            root.repoUpdating = false
            root.refresh()
        }
    }

    Process {
        id: updateProc
        onExited: root.refresh()
    }

    Timer {
        id: firstCheck
        interval: 60000
        running: root.available && Settings.updateInterval > 0
        onTriggered: root.refresh()
    }

    Timer {
        id: every
        interval: Math.max(1, Settings.updateInterval) * 60000
        repeat: true
        running: root.available && Settings.updateInterval > 0
        onTriggered: root.refresh()
    }

    // taking the AUR back in needs a check to know what it has
    Connections {
        target: Settings
        function onUpdateAurChanged() { if (Settings.updateAur) root.refresh() }
    }

    // the last check's results until this run's first check is in
    DiskCache {
        id: cache
        name: "updates"
        onRestored: data => {
            if (root.lastChecked === null && Array.isArray(data.found)) {
                root.found = data.found
                root.lastChecked = data.lastChecked ? new Date(data.lastChecked) : null
            }
            var r = data.repo
            if (root.repoState === "" && r && typeof r === "object") {
                root.repoPath = r.path || ""
                root.repoState = r.state || ""
                root.repoUpstream = r.upstream || ""
                root.repoBehind = r.behind || 0
                root.repoAhead = r.ahead || 0
                root.repoCommits = Array.isArray(r.commits) ? r.commits : []
                root.repoNewPackages = Array.isArray(r.newPackages) ? r.newPackages : []
            }
        }
    }

    Component.onCompleted: logProc.running = true
}
