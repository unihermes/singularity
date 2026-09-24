// Singularity - Quickshell
// ~/.config/quickshell/services/Autostart.qml
//
// What starts when you log in, from ~/.config/autostart.
//
// Hyprland runs no XDG autostart of its own, so before this existed a
// .desktop file in that directory -- dropped there by an application's own
// "run at login" checkbox as much as by hand -- did precisely nothing. The
// piece that runs them at login is ~/.config/singularity/autostart.sh, called
// from hyprland.lua; this service is the same script's `list` output plus the
// writes that turn an entry on and off. Its header documents the one place
// the behaviour deliberately differs from the spec: a /etc/xdg/autostart
// entry is opt-in here rather than on by default.
//
// Reading is the script's job, so that what Settings shows and what actually
// runs can never drift: both answer "is this enabled" with the same code.
//
// Writing is done here rather than in the script, through AtomicFileWrite, so
// these files get the same treatment as every other config the shell edits --
// queued behind other writes, applied to the file as it is on disk at that
// moment, and renamed into place rather than truncated. Deleting is the one
// exception: there is nothing to transform, so it is a plain rm.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ scope, file, name, exec, enabled, runnable, comment }]
    // scope is "user" (in ~/.config/autostart) or "system" (available in
    // /etc/xdg/autostart and not copied across yet)
    property var entries: []
    property bool loaded: false

    readonly property var userEntries: entries.filter(e => e.scope === "user")
    readonly property var systemEntries: entries.filter(e => e.scope === "system")
    readonly property int enabledCount: entries.filter(e => e.enabled).length

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string userDir: configHome + "/autostart"
    readonly property string systemDir: "/etc/xdg/autostart"
    readonly property string script: configHome + "/singularity/autostart.sh"

    signal wrote(string message, bool isError)

    function refresh() {
        if (!lister.running) lister.running = true
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
                    })
                }
                root.entries = out
                root.loaded = true
            }
        }
    }

    // --- writing -----------------------------------------------------------

    // Set a key in the [Desktop Entry] group, replacing the existing line if
    // there is one. A key set in a later group ([Desktop Action open]) is
    // left alone: it belongs to that action, not to the entry.
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

    // Turn a user entry on or off. Hidden=true is the spec's way of saying
    // "installed but don't run it", and is what an application's own settings
    // will read back, so it is used rather than deleting the file: deleting
    // would lose an entry the user may have written by hand.
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

    // Copying a system entry into ~/.config/autostart is what opts into it.
    // The copy is the whole file rather than a stub pointing at the original:
    // a user file replaces the system one outright, so anything left out of
    // it -- TryExec, OnlyShowIn -- would be lost rather than inherited.
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

    // A desktop entry picked in Settings, written as a new autostart file.
    // Exec is rebuilt from the parsed command rather than copied from the
    // application's own Exec line, which is where the field codes (%U, %f)
    // live -- nothing is being passed to these, and some programs treat a
    // literal %U as a file to open.
    function add(app) {
        if (!app) return
        var cmd = []
        for (var i = 0; i < app.command.length; i++) cmd.push(app.command[i])
        // a terminal application has no terminal at login; give it one, the
        // same way the launcher does
        if (app.runInTerminal) cmd = ["alacritty", "-e"].concat(cmd)

        var file = app.id.replace(/\.desktop$/, "") + ".desktop"
        var text = "[Desktop Entry]\n"
            + "Type=Application\n"
            + "Name=" + app.name + "\n"
            + (app.icon ? "Icon=" + app.icon + "\n" : "")
            + "Exec=" + cmd.join(" ") + "\n"
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

    // Only ever a file in ~/.config/autostart. Removing one that came from
    // /etc/xdg/autostart drops back to the system entry, which is off.
    function remove(entry) {
        if (entry.scope !== "user") return
        rm.command = ["rm", "-f", userDir + "/" + entry.file]
        rm.pendingMessage = entry.name + " removed from startup"
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
        property string pendingMessage: ""
        command: ["true"]
        onExited: (code) => {
            root.wrote(code === 0 ? pendingMessage : "Couldn't remove the entry", code !== 0)
            root.refresh()
        }
    }
}
