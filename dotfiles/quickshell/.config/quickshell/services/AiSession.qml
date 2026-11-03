// Shared transcript and conversation state for the CLI adapters.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root
    // Invalidates asynchronous history reads when a conversation is replaced.
    property int generation: 0
    property string cwd: ""
    property string modelPick: ""
    property string reasoningPick: ""
    property string mode: "default"
    property bool busy: false
    property string sessionId: ""
    property string activity: ""
    property string modelName: ""
    property var slashCommands: []
    property int contextUsed: 0
    property int contextWindow: 0
    property bool unseen: false
    // [{ id, tool, input, title, detail, suggestions }]
    property var asks: []
    // [{ kind: "image" | "text", label, path, media, data, text }]
    property var attachments: []

    readonly property alias entries: rows
    readonly property alias transcript: rows
    readonly property bool empty: rows.count === 0
    signal rateLimit(var info)
    signal turnEnded()
    signal asked(string title)

    ListModel { id: rows }

    readonly property bool commandRunning: commandProc.running
    property int commandRow: -1
    property string commandOutput: ""
    property string commandText: ""
    property string shellContext: ""
    property bool commandStopped: false

    function runCommand(text) {
        var command = text.slice(1).trim()
        if (!command || busy || commandRunning) return false
        commandText = command
        commandOutput = ""
        commandStopped = false
        commandRow = add({ kind: "tool", name: "Bash", detail: oneLine(command), body: command, phase: "running" })
        busy = true
        activity = oneLine(command)
        commandProc.command = ["python3", Quickshell.shellPath("scripts/ai-command.py"), command]
        commandProc.running = true
        return true
    }

    function commandLine(line) {
        commandOutput = clip(commandOutput + line + "\n")
        if (commandRow >= 0) setRow(commandRow, { result: commandOutput })
    }

    function stopCommand() {
        if (!commandRunning) return false
        commandStopped = true
        commandProc.signal(15)
        return true
    }

    function resetCommands() {
        generation++
        commandRow = -1
        shellContext = ""
        stopCommand()
    }

    function withCommandContext(text) {
        if (!shellContext) return text
        var context = shellContext
        shellContext = ""
        return "Commands run by the user in " + cwd + ":\n" + context + "\nUser message:\n" + text
    }

    Process {
        id: commandProc
        workingDirectory: root.cwd
        stdout: SplitParser { onRead: line => root.commandLine(line) }
        stderr: SplitParser { onRead: line => root.commandLine(line) }
        onExited: (code, status) => {
            if (root.commandRow < 0) return
            var result = root.commandOutput + (root.commandStopped ? "\nStopped" : "\nExit code: " + code)
            root.setRow(root.commandRow, { phase: root.commandStopped ? "stopped" : code === 0 && status === 0 ? "done" : "error", result: result })
            root.shellContext = root.clip(root.shellContext + "$ " + root.commandText + "\n" + result + "\n")
            root.commandRow = -1
            root.busy = false
            root.activity = ""
            root.unseen = true
            root.turnEnded()
        }
    }

    function attach(a) { if (a) attachments = attachments.concat([a]) }
    function unattach(i) {
        var a = attachments.slice()
        a.splice(i, 1)
        attachments = a
    }

    function lastReply() {
        for (var i = rows.count - 1; i >= 0; i--) {
            var r = rows.get(i)
            if (r.kind === "user") return ""
            if (r.kind === "assistant" || r.kind === "error") return r.text
        }
        return ""
    }

    // Rows retain every role and their index for the lifetime of a conversation.
    function add(o) {
        rows.append({
            kind: o.kind, text: o.text || "", note: o.note || "", images: o.images || "",
            name: o.name || "", detail: o.detail || "", body: o.body || "", result: o.result || "",
            toolId: o.toolId || "", phase: o.phase || "", streaming: !!o.streaming,
            final: !!o.final, open: false
        })
        return rows.count - 1
    }
    function setRow(i, o) { for (var k in o) rows.setProperty(i, k, o[k]) }
    function markFinal(since) {
        for (var i = rows.count - 1; i >= (since || 0); i--) {
            var row = rows.get(i)
            if (row.kind === "user") break
            if (row.kind === "assistant" && row.text.trim() !== "") {
                setRow(i, { final: true })
                break
            }
        }
    }
    // a multi-line command as its first line, for a row or the status line
    function oneLine(t) {
        var l = String(t).trim().split("\n")
        return l.length > 1 ? l[0].trim() + " …" : l[0]
    }
    function clip(t) { return t.length > 4000 ? t.slice(0, 4000) + "\n…" : t }
    function rel(p) {
        p = String(p || "")
        return cwd !== "" && p.indexOf(cwd + "/") === 0 ? p.slice(cwd.length + 1) : p
    }
}
