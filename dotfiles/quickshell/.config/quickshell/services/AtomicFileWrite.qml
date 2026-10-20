// Singularity - Quickshell
// ~/.config/quickshell/services/AtomicFileWrite.qml
//
// The one way the shell writes a config file. Writes queue one at a time;
// the transform runs on the file as it is when the write runs (and may
// refuse with null, so hand edits survive); optional syntax check (bash -n,
// luac -p); written beside the readlink-resolved target and renamed over it
// (stow links stay links); optional backup first and command after.
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
    // the new text, handed to the script on stdin once it starts: as an
    // argument it hit Linux's 128 KB limit on any one argument
    property string pendingText: ""

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
            // a transform that throws is a refusal, so report() still runs
            var out
            try { out = job.transform(src) }
            catch (e) {
                console.warn("AtomicFileWrite: transform for " + job.path + " failed: " + e)
                out = null
            }
            if (out === null || out === undefined) { report(job, "refused", job.refusal || ""); continue }
            if (out === src) { report(job, "unchanged", ""); continue }
            current = job
            pendingText = out
            proc.command = ["sh", "-c", script, "sh", job.path,
                job.check || "", job.backup || "", job.after || ""]
            proc.stdinEnabled = true
            proc.running = true
            return
        }
    }

    FileView {
        id: reader
        blockLoading: true
        printErrors: false
    }

    // first output line is a status word, the rest detail, all on stdout;
    // chmod --reference keeps the mode
    readonly property string script: `
        exec 2>&1
        t=$(readlink -m -- "$1") && mkdir -p -- "\${t%/*}" && cat > "$t.new" || { echo write; exit; }
        case $2 in
            bash) out=$(bash -n "$t.new" 2>&1) || { echo syntax; printf "%s\\n" "$out"; rm -f -- "$t.new"; exit; } ;;
            lua)  if command -v luac >/dev/null 2>&1; then
                      out=$(luac -p "$t.new" 2>&1) || { echo syntax; printf "%s\\n" "$out"; rm -f -- "$t.new"; exit; }
                  fi ;;
        esac
        if [ -e "$t" ]; then
            chmod --reference="$t" -- "$t.new" 2>/dev/null
            if [ -n "$3" ]; then
                { mkdir -p -- "\${3%/*}" && cp -- "$t" "$3"; } || { rm -f -- "$t.new"; echo write; exit; }
            fi
        fi
        mv -f -- "$t.new" "$t" || { rm -f -- "$t.new"; echo write; exit; }
        echo ok
        [ -z "$4" ] || eval "$4"`

    Process {
        id: proc
        command: ["true"]
        // written whole, then stdin closed so cat sees the end
        onStarted: {
            write(root.pendingText)
            root.pendingText = ""
            stdinEnabled = false
        }
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
