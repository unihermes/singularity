// Singularity - Quickshell
// ~/.config/quickshell/services/ClaudeShell.qml
//
// Claude Code, driven from the bar (bar module "claude", ClaudeFlyout.qml).
// Ask for a change to the desktop and Claude makes it in a staging copy of
// this repo; the flyout shows the diff, and nothing is live until it's
// applied. The staging, diffing and applying are scripts/claude-shell.sh --
// see its header for why Claude never touches the live files directly.
//
// One conversation at a time. Follow-ups resume the same Claude session and
// keep building on the same staging copy, so the diff is always everything
// asked for since the last apply or discard.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/claude-shell.sh")
    // the shell's own settings file, which rides along in the staging copy
    readonly property var env: ({ SINGULARITY_SETTINGS: Settings.stateDir + "/appearance.json" })

    readonly property bool available: availProbe.found      // the claude CLI is installed
    property bool running: false
    property string sessionId: ""
    // [{ kind: "user" | "assistant" | "tool" | "error", text }]
    property var transcript: []
    // what Claude is doing right now, for the bar and the flyout's status line
    property string activity: ""
    property real cost: 0
    // a reply landed while the flyout was closed; the bar module shows a dot
    property bool unseen: false
    // an apply is out; the next diff read says whether it went through
    property bool applying: false

    property string diff: ""
    // [{ path, added, removed }], parsed out of the diff
    readonly property var files: parseFiles(diff)
    readonly property bool hasChanges: files.length > 0

    function ask(prompt) {
        prompt = prompt.trim()
        if (!available || running || prompt === "") return
        say("user", prompt)
        activity = "Thinking"
        runProc.stderrText = ""
        runProc.gotResult = false
        runProc.stopped = false
        runProc.command = [script, "run", prompt, sessionId]
        running = true
        runProc.running = true
    }

    function stop() {
        if (!runProc.running) return
        runProc.stopped = true
        runProc.signal(15)
    }

    // Detached: applying rewrites files Quickshell is watching, and the
    // reload that follows would take a child process down with it. The
    // script reports the outcome itself, with a notification. If the shell
    // didn't reload (only Hyprland files changed), re-reading the diff shows
    // whether it went through -- a failed apply leaves the staging copy be.
    function apply() {
        if (running || !hasChanges) return
        Quickshell.execDetached({ command: [script, "apply"], environment: env })
        applying = true
        afterApply.restart()
    }

    function discard() {
        stop()
        Quickshell.execDetached({ command: [script, "discard"], environment: env })
        reset()
    }

    function reset() {
        sessionId = ""
        transcript = []
        activity = ""
        diff = ""
        cost = 0
        unseen = false
    }

    // A read already under way may have snapshotted before the latest edit,
    // so one asked for meanwhile runs again once it's done.
    function refreshDiff() {
        if (diffProc.running) diffProc.again = true
        else diffProc.running = true
    }

    function say(kind, text) {
        transcript = transcript.concat([{ kind: kind, text: text }])
    }

    // "work/dotfiles/hypr/.config/hypr/hyprland.lua" -> the repo-relative path
    function relPath(p) {
        var i = (p || "").indexOf("/claude-shell/work/")
        return i < 0 ? (p || "") : p.slice(i + "/claude-shell/work/".length)
    }

    function describeTool(name, input) {
        input = input || {}
        switch (name) {
        case "Read":  return "Reading " + relPath(input.file_path)
        case "Edit":  return "Editing " + relPath(input.file_path)
        case "Write": return "Writing " + relPath(input.file_path)
        case "Glob":  return "Finding " + (input.pattern || "")
        case "Grep":  return "Searching for " + (input.pattern || "")
        default:      return name
        }
    }

    function handleEvent(ev) {
        if (ev.session_id) sessionId = ev.session_id
        if (ev.type === "assistant" && ev.message && ev.message.content) {
            var blocks = ev.message.content
            for (var i = 0; i < blocks.length; i++) {
                var b = blocks[i]
                if (b.type === "text" && b.text.trim() !== "") {
                    say("assistant", b.text.trim())
                    activity = "Writing reply"
                } else if (b.type === "tool_use") {
                    activity = describeTool(b.name, b.input)
                    say("tool", activity)
                    // each edit shows up in the diff as it happens
                    if (b.name === "Edit" || b.name === "Write") refreshDiff()
                }
            }
        } else if (ev.type === "result") {
            runProc.gotResult = true
            cost += ev.total_cost_usd || 0
            if (ev.is_error)
                say("error", ev.result || ev.subtype || "Claude stopped with an error")
        }
    }

    function parseFiles(d) {
        var out = [], cur = null
        var lines = d.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i]
            if (l.indexOf("diff --git ") === 0) {
                var m = l.match(/ b\/(.*)$/)
                cur = { path: m ? m[1] : l, added: 0, removed: 0 }
                out.push(cur)
            } else if (!cur || l.indexOf("+++") === 0 || l.indexOf("---") === 0) {
                continue
            } else if (l[0] === "+") {
                cur.added++
            } else if (l[0] === "-") {
                cur.removed++
            }
        }
        return out
    }

    CommandProbe { id: availProbe; name: "claude" }

    // a previous shell may have left a staging copy with changes in it
    Component.onCompleted: refreshDiff()

    Process {
        id: runProc
        property string stderrText: ""
        property bool gotResult: false
        property bool stopped: false
        environment: root.env

        stdout: SplitParser {
            onRead: line => {
                var ev
                try { ev = JSON.parse(line) } catch (e) { return }
                root.handleEvent(ev)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: runProc.stderrText = text.trim()
        }
        onExited: (code, status) => {
            if (!gotResult)
                root.say("error", stopped ? "Stopped"
                    : (stderrText || "claude exited with code " + code))
            root.running = false
            root.activity = ""
            root.unseen = true
            root.refreshDiff()
        }
    }

    Process {
        id: diffProc
        property bool again: false
        command: [root.script, "diff"]
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                root.diff = text
                // staging copy gone means the apply went through
                if (root.applying && text === "") root.reset()
                root.applying = false
            }
        }
        onExited: if (again) { again = false; running = true }
    }

    Timer {
        id: afterApply
        interval: 1500
        onTriggered: root.refreshDiff()
    }
}
