// Neutrino - Quickshell
// ~/.config/quickshell/HyprLuaWrite.qml
//
// The one write path into hyprland.lua, shared by the Keybinds editor and the
// Settings window's Input and Display pages.
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
// Two ways in. write() takes a whole new file and leaves the staleness
// check to the caller (Keybinds, whose edits are offsets into the text it
// parsed). patch() takes a function of the current text instead -- for the
// Settings pages, which set one field by name and so can always be applied
// to whatever is on disk at the moment the write runs.
//
// Both report through a callback rather than a signal: with one shared
// instance, a signal would hand every open page every other page's result.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string confPath: home + "/.config/hypr/hyprland.lua"
    readonly property string backupPath:
        (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/neutrino/hyprland.lua.bak"

    // hyprland.lua writes queued or running; pages hold off re-reading the
    // file on change notifications while their own write lands
    property int pending: 0
    readonly property bool busy: pending > 0

    readonly property string afterWrite:
        "hyprctl reload config-only >/dev/null; sleep 0.3; hyprctl configerrors"

    function enqueue(transform, backup, done) {
        pending++
        AtomicFileWrite.write({
            path: confPath,
            transform: transform,
            check: "lua",
            backup: backup ? backupPath : "",
            after: afterWrite,
            done: (status, detail) => {
                pending--
                done(status, detail)
            }
        })
    }

    // transform(text) returns the new text, or null when it can't make the
    // change (the field isn't a plain value); refusal is the message given.
    // done(ok, message) gets one line for a status bar.
    function patch(transform, message, refusal, done) {
        enqueue(src => src === "" ? null : transform(src), true, (status, detail) => {
            if (status === "refused") done(false, refusal || "Not a plain value in hyprland.lua, edit it by hand")
            else if (status === "unchanged") done(true, message)
            else if (status === "syntax") done(false, syntaxMessage(detail))
            else if (status !== "ok") done(false, "Couldn't write hyprland.lua" + (detail ? ": " + detail.split("\n")[0] : ""))
            else if (reloadComplaint(detail) !== "") done(false, "Written, but Hyprland reports: " + reloadComplaint(detail))
            else done(true, message)
        })
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
