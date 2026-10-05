// Singularity - Quickshell
// ~/.config/quickshell/services/HyprLuaWrite.qml
//
// The one write path into binds.lua, used by the Keybinds editor, and into
// the per-machine files the Hyprland config loads from the state directory:
// monitors.lua, the Display page's hl.monitor() rules, and hyprland.json,
// the hl.config tables the Input and Appearance pages change. Those two stay
// out of the repo; binds are meant to be committed.
//
// A singleton, so there is exactly one of it however many of those are open:
// as a per-page instance, each kept its own queue, and the standalone Keybinds
// window and Settings > Input could both read the file, and whichever wrote
// last threw away the other's change. It sits on AtomicFileWrite, whose queue
// is shared with every other config write in the shell.
//
// A write never goes straight at the config. The new text is syntax-checked
// with luac first, the current file is copied to a backup, and only then
// replaced -- followed by `hyprctl reload config-only` and a read of
// `hyprctl configerrors`, so a value Hyprland rejects is reported rather than
// silently doing nothing. Undo puts the backup back.
//
// write() takes a whole new binds.lua and leaves the staleness check to
// the caller (Keybinds, whose edits are offsets into the text it parsed).
// setLocal() sets fields by name in hyprland.json as it is on disk when the
// write runs, then reloads the same way.
//
// Each reports through a callback rather than a signal: with one shared
// instance, a signal would hand every open page every other page's result.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // hyprland.lua only runs these modules, one per part of the config; the
    // pages read the plain fields of the tables in input, looks and displays
    readonly property string hyprDir: home + "/.config/hypr/"
    readonly property string bindsPath: hyprDir + "binds.lua"
    readonly property string inputPath: hyprDir + "input.lua"
    readonly property string looksPath: hyprDir + "looks.lua"
    readonly property string displaysPath: hyprDir + "displays.lua"
    readonly property string backupPath: Settings.stateDir + "/binds.lua.bak"
    readonly property string monitorsPath: Settings.stateDir + "/monitors.lua"
    readonly property string localPath: Settings.stateDir + "/hyprland.json"

    // hyprland.json parsed: { input: { follow_mouse: 2, touchpad: {…} }, … }
    property var overrides: ({})

    // binds.lua and monitors.lua writes queued or running; pages hold off re-reading the
    // file on change notifications while their own write lands
    property int pending: 0
    readonly property bool busy: pending > 0

    readonly property string afterWrite:
        "hyprctl reload config-only >/dev/null; sleep 0.3; hyprctl configerrors"

    function enqueue(transform, backup, done, path) {
        pending++
        AtomicFileWrite.write({
            path: path || bindsPath,
            transform: transform,
            check: "lua",
            backup: backup ? (path ? path + ".bak" : backupPath) : "",
            after: afterWrite,
            done: (status, detail) => {
                pending--
                done(status, detail)
            }
        })
    }

    // the value hyprland.json sets for path + key, or undefined
    function override(path, key) {
        var t = overrides
        for (var i = 0; i < path.length && t; i++) t = t[path[i]]
        return t && typeof t === "object" ? t[key] : undefined
    }

    // sets: [[path, key, value]], written together so one reload applies
    // them; done(ok, message) gets one line for a status bar
    function setLocal(sets, message, done) {
        pending++
        AtomicFileWrite.write({
            path: localPath,
            transform: src => {
                var o = src.trim() === "" ? {} : JSON.parse(src)
                sets.forEach(s => {
                    var t = o
                    s[0].forEach(k => t = t[k] = (t[k] && typeof t[k] === "object") ? t[k] : {})
                    t[s[1]] = s[2]
                })
                return JSON.stringify(o, null, 2) + "\n"
            },
            after: afterWrite,
            done: (status, detail) => {
                pending--
                localFile.reload()
                reporter("hyprland.json", message, "hyprland.json doesn't parse, fix or delete it", done)(status, detail)
            }
        })
    }

    FileView {
        id: localFile
        path: root.localPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.overrides = JSON.parse(text()) || {} }
            catch (e) { root.overrides = {} }
        }
        onLoadFailed: root.overrides = {}
    }

    // The same for monitors.lua, which starts out missing: transform gets
    // seed() in its place.
    function patchMonitors(transform, seed, message, refusal, done) {
        enqueue(src => transform(src === "" ? seed() : src), true,
            reporter("monitors.lua", message, refusal, done), monitorsPath)
    }

    function reporter(file, message, refusal, done) {
        return (status, detail) => {
            if (status === "refused") done(false, refusal || "Not a plain value in " + file + ", edit it by hand")
            else if (status === "unchanged") done(true, message)
            else if (status === "syntax") done(false, syntaxMessage(detail))
            else if (status !== "ok") done(false, "Couldn't write " + file + (detail ? ": " + detail.split("\n")[0] : ""))
            else if (reloadComplaint(detail) !== "") done(false, "Written, but Hyprland reports: " + reloadComplaint(detail))
            else done(true, message)
        }
    }

    // done(status, detail): status "ok" | "syntax" | "write". detail: luac's
    // complaint for syntax, the first error for write, `hyprctl configerrors`
    // for ok.
    function write(newText, done) {
        enqueue(() => newText, true, (status, detail) => done(status === "unchanged" ? "ok" : status, detail))
    }

    function undo(done) {
        backupFile.reload()
        backupFile.waitForJob()
        var saved = backupFile.text()
        if (saved === "") { done("write", "No backup at " + backupPath); return }
        enqueue(() => saved, false, (status, detail) => done(status === "unchanged" ? "ok" : status, detail))
    }

    FileView {
        id: backupFile
        path: root.backupPath
        blockLoading: true
        printErrors: false
    }

    // "Written, but Hyprland reports: ..." or "" when the reload was clean
    function reloadComplaint(detail) {
        return detail !== "" && !/no errors/i.test(detail) ? detail.split("\n")[0] : ""
    }

    // luac names the temp file; only the line and message matter
    function syntaxMessage(detail) {
        var m = detail.match(/:(\d+):\s*(.*)/)
        return "Not written, Lua syntax error" + (m ? " on line " + m[1] + ": " + m[2] : "")
    }
}
