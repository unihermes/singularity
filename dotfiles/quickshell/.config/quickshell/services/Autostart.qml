// Singularity - Quickshell
// ~/.config/quickshell/services/Autostart.qml
//
// What starts at login, from ~/.config/autostart. Reading is autostart.sh's
// `list` (the same code that runs them, so the two can't drift); writing goes
// through AtomicFileWrite, deleting is a plain rm. System entries are opt-in
// (see autostart.sh).

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ scope, file, name, exec, enabled, runnable, comment, icon, only }];
    // scope "user", or "system" for one not copied across yet
    property var entries: []
    property bool loaded: false

    readonly property var userEntries: entries.filter(e => e.scope === "user")
    readonly property var systemEntries: entries.filter(e => e.scope === "system")

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string userDir: configHome + "/autostart"
    readonly property string systemDir: "/etc/xdg/autostart"
    readonly property string script: configHome + "/singularity/autostart.sh"

    signal wrote(string message, bool isError)

    // A refresh asked for while one runs is run again after it: the one
    // running may have read the files before the write that asked.
    property bool refreshAgain: false
    function refresh() {
        if (lister.running) refreshAgain = true
        else lister.running = true
    }

    Component.onCompleted: refresh()

    Process {
        id: lister
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("\t")
                    if (f.length < 6 || f[0] === "") continue
                    out.push({
                        scope: f[0],
                        file: f[1],
                        // an entry with no Name= is legal and does happen;
                        // the filename is what a person would recognise it by
                        name: f[2] !== "" ? f[2] : f[1].replace(/\.desktop$/, ""),
                        exec: f[3],
                        enabled: f[4] === "yes",
                        runnable: f[5] === "yes",
                        comment: f[6] || "",
                        // a theme icon name or a path, "" for none
                        icon: f[7] || "",
                        // the desktops it's limited to, "GNOME, Unity", or ""
                        only: (f[8] || "").split(";").filter(d => d !== "").join(", "),
                    })
                }
                root.entries = out
                root.loaded = true
            }
        }
        onExited: if (root.refreshAgain) {
            root.refreshAgain = false
            running = true
        }
    }

    // --- writing -----------------------------------------------------------

    // sets a key in the [Desktop Entry] group (not in action groups)
    function withKey(text, key, value) {
        var lines = text.split("\n")
        var inEntry = false
        var insertAt = -1
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (line.indexOf("[") === 0) {
                if (inEntry) break            // end of the group we care about
                inEntry = line.trim() === "[Desktop Entry]"
                if (inEntry) insertAt = i + 1
                continue
            }
            if (!inEntry) continue
            if (line.indexOf(key + "=") === 0) {
                lines[i] = key + "=" + value
                return lines.join("\n")
            }
        }
        if (insertAt < 0) return null         // not a desktop entry at all
        lines.splice(insertAt, 0, key + "=" + value)
        return lines.join("\n")
    }

    // a user entry on or off, as Hidden=true (what apps read back), never
    // deleting a hand-written file
    function setEnabled(entry, on) {
        if (entry.scope === "system") {
            if (on) adopt(entry)
            return
        }
        AtomicFileWrite.write({
            path: userDir + "/" + entry.file,
            transform: text => root.withKey(text, "Hidden", on ? "false" : "true"),
            refusal: entry.file + " isn't a desktop entry",
            done: (status, detail) => root.report(status, detail,
                entry.name + (on ? " starts at login" : " won't start at login")),
        })
    }

    // opts into a system entry by copying the whole file (a user file
    // replaces the system one outright)
    function adopt(entry) {
        source.path = systemDir + "/" + entry.file
        source.reload()
        source.waitForJob()
        var text = source.text()
        if (text === "") {
            wrote("Couldn't read " + entry.file, true)
            return
        }
        var next = withKey(text, "Hidden", "false")
        if (next === null) {
            wrote(entry.file + " isn't a desktop entry", true)
            return
        }
        AtomicFileWrite.write({
            path: userDir + "/" + entry.file,
            transform: () => next,
            refusal: "Couldn't write the copy",
            done: (status, detail) => root.report(status, detail,
                entry.name + " starts at login"),
        })
    }

    // one Exec argument, quoted as the spec and `sh -c` read it
    function execArg(a) {
        a = String(a).replace(/%/g, "%%")
        if (a !== "" && !/[\s"'\\><~|&;$*?#()`]/.test(a)) return a
        return '"' + a.replace(/(["`$\\])/g, "\\$1") + '"'
    }

    // a desktop entry picked in Settings as a new autostart file, Exec
    // rebuilt from the parsed command (no field codes)
    function add(app) {
        if (!app) return
        var cmd = []
        for (var i = 0; i < app.command.length; i++) cmd.push(app.command[i])
        // a terminal application has no terminal at login; give it one, the
        // same way the launcher does
        if (app.runInTerminal) cmd = [Settings.terminal, "-e"].concat(cmd)

        var file = app.id.replace(/\.desktop$/, "") + ".desktop"
        var text = "[Desktop Entry]\n"
            + "Type=Application\n"
            + "Name=" + app.name + "\n"
            + (app.icon ? "Icon=" + app.icon + "\n" : "")
            + "Exec=" + cmd.map(execArg).join(" ") + "\n"
            + "Hidden=false\n"
            + "X-Singularity-Added=true\n"

        AtomicFileWrite.write({
            path: userDir + "/" + file,
            // an entry for this app already there is replaced, which is what
            // adding it again is asking for
            transform: () => text,
            refusal: "Couldn't write the entry",
            done: (status, detail) => root.report(status, detail,
                app.name + " added to startup"),
        })
    }

    // removes a user file (a system one falls back to off), queued
    function remove(entry) {
        if (entry.scope !== "user") return
        rm.pending.push({ file: userDir + "/" + entry.file, message: entry.name + " removed from startup" })
        nextRemove()
    }

    function nextRemove() {
        if (rm.running || rm.pending.length === 0) return
        var job = rm.pending.shift()
        rm.command = ["rm", "-f", "--", job.file]
        rm.pendingMessage = job.message
        rm.running = true
    }

    function report(status, detail, message) {
        if (status === "ok" || status === "unchanged") wrote(message, false)
        else wrote(status === "refused" ? detail : "Couldn't write the entry", true)
        refresh()
    }

    FileView {
        id: source
        blockLoading: true
        printErrors: false
    }

    Process {
        id: rm
        property var pending: []
        property string pendingMessage: ""
        command: ["true"]
        onExited: (code) => {
            root.wrote(code === 0 ? pendingMessage : "Couldn't remove the entry", code !== 0)
            root.refresh()
            root.nextRemove()
        }
    }
}
