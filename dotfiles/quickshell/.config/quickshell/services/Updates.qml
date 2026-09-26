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

    function refresh() {
        if (!available || checkProc.running) return
        checking = true
        checkProc.running = true
    }

    // yay does repo and AUR in one pass, unattended after the one sudo
    // password prompt:
    //   --sudoloop       keeps sudo's timestamp fresh, so a long AUR build
    //                    doesn't ask again when pacman installs at the end
    //   --noconfirm      takes pacman's default at every [Y/n]
    //   --answer* None   skips yay's clean-build / diff / PKGBUILD-edit menus
    //   --removemake     drops build-only deps without asking
    // On success the terminal closes itself with a notification; on failure
    // it stays open so the error can be read. Either way the list is
    // re-checked once it closes.
    // --repo leaves the AUR alone when it's not included; --ignore takes
    // Settings.updateIgnore, which Settings has already limited to names.
    function update() {
        if (updateProc.running) return
        var flags = (Settings.updateAur ? "" : " --repo")
            + (Settings.updateIgnore.length > 0 ? " --ignore " + Settings.updateIgnore.join(",") : "")
        updateProc.command = ["alacritty", "--class", "neutrino-update", "-e", "sh", "-c",
            "yay -Syu" + flags + " --sudoloop --noconfirm --answerclean None --answerdiff None "
            + "--answeredit None --removemake; "
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
            }
        }
        onExited: {
            root.checking = false
            logProc.running = true
        }
    }

    Process {
        id: logProc
        command: ["sh", "-c", "grep 'starting full system upgrade' /var/log/pacman.log | tail -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = /^\[([^\]]+)\]/.exec(text.trim())
                root.lastUpgrade = m ? new Date(m[1].replace(/([+-]\d\d)(\d\d)$/, "$1:$2")) : null
            }
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

    Component.onCompleted: logProc.running = true
}
