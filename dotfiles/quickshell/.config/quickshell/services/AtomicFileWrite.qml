// Singularity - Quickshell
// ~/.config/quickshell/services/AtomicFileWrite.qml
//
// The one way the shell writes a config file. Every settings page and
// HyprLuaWrite go through it, so they all get the same guarantees:
//
//  - Writes queue and run one at a time, across every page and window. A
//    second change made while the first is still writing waits its turn
//    instead of being dropped.
//  - The file is read fresh when the write actually runs, and the caller's
//    transform is applied to that text -- not to whatever the page read when
//    it opened. A transform can refuse (return null) when the file changed in
//    a way it can't build on, which is how a hand-edit or a `git pull` made
//    while the page was open survives the next click.
//  - The new text is optionally syntax-checked (bash -n, luac -p) before
//    anything on disk changes.
//  - It's written beside the target and renamed over it, so a crash or a
//    full disk leaves the old file rather than half of the new one. The
//    target is resolved with readlink first: most of these files are stow
//    symlinks into the repo, and renaming over the link itself would replace
//    it with a plain file, quietly cutting it off from the copy git tracks.
//  - An optional backup copy is taken first, and an optional shell command
//    (a reload, usually) runs after a successful write.
//
// write(job) takes:
//   path       the file
//   transform  function(text) -> new text, or null to refuse. text is "" for
//              a file that doesn't exist yet.
//   refusal    the detail reported when transform refuses
//   check      "" | "bash" | "lua"
//   backup     path to copy the current file to first, or ""
//   after      shell command run after a successful write; its output is
//              the detail passed back for "ok"
//   done       function(status, detail), status one of
//              ok | unchanged | refused | syntax | write

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool busy: proc.running || current !== null || queue.length > 0

    property var queue: []
    property var current: null

    function write(job) {
        queue = queue.concat([job])
        next()
    }

    // A page can close while its write is still queued; its callback then
    // touches objects that are gone, which must not stall the queue.
    function report(job, status, detail) {
        if (!job.done) return
        try { job.done(status, detail) }
        catch (e) { console.warn("AtomicFileWrite: callback for " + job.path + " failed: " + e) }
    }

    // Runs from both ends of a write -- the output collected and the process
    // reaped arrive in either order -- and goes ahead once both have.
    function next() {
        if (proc.running || current !== null) return
        while (queue.length > 0) {
            var job = queue[0]
            queue = queue.slice(1)
            reader.path = job.path
            reader.reload()
            reader.waitForJob()
            var src = reader.text()
            // A transform that throws is a refusal too: the exception would
            // otherwise skip report(), and a caller counting its writes
            // (HyprLuaWrite.pending) would stay busy for good.
            var out
            try { out = job.transform(src) }
            catch (e) {
                console.warn("AtomicFileWrite: transform for " + job.path + " failed: " + e)
                out = null
            }
            if (out === null || out === undefined) { report(job, "refused", job.refusal || ""); continue }
            if (out === src) { report(job, "unchanged", ""); continue }
            current = job
            proc.command = ["sh", "-c", script, "sh", job.path, out,
                job.check || "", job.backup || "", job.after || ""]
            proc.running = true
            return
        }
    }

    FileView {
        id: reader
        blockLoading: true
        printErrors: false
    }

    // Output's first line is a status word and the rest is detail. Everything
    // goes to stdout so one collector sees it all in order. chmod --reference
    // keeps the file's mode, which a fresh temp file would otherwise reset.
    readonly property string script: `
        exec 2>&1
        t=$(readlink -m -- "$1") && mkdir -p -- "\${t%/*}" && printf %s "$2" > "$t.new" || { echo write; exit; }
        case $3 in
            bash) out=$(bash -n "$t.new" 2>&1) || { echo syntax; printf "%s\\n" "$out"; rm -f -- "$t.new"; exit; } ;;
            lua)  if command -v luac >/dev/null 2>&1; then
                      out=$(luac -p "$t.new" 2>&1) || { echo syntax; printf "%s\\n" "$out"; rm -f -- "$t.new"; exit; }
                  fi ;;
        esac
        if [ -e "$t" ]; then
            chmod --reference="$t" -- "$t.new" 2>/dev/null
            if [ -n "$4" ]; then
                { mkdir -p -- "\${4%/*}" && cp -- "$t" "$4"; } || { rm -f -- "$t.new"; echo write; exit; }
            fi
        fi
        mv -f -- "$t.new" "$t" || { rm -f -- "$t.new"; echo write; exit; }
        echo ok
        [ -z "$5" ] || eval "$5"`

    Process {
        id: proc
        command: ["true"]
        onRunningChanged: if (!running) root.next()
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                var status = lines.shift().trim()
                var job = root.current
                root.current = null
                if (job) root.report(job, status, lines.join("\n").trim())
                root.next()
            }
        }
    }
}
