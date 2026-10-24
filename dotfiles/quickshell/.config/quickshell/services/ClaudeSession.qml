// Singularity - Quickshell
// ~/.config/quickshell/services/ClaudeSession.qml
//
// One conversation with Claude Code: `claude -p` kept running with
// stream-json both ways, so follow-ups, Stop, a model or mode change and the
// answers to its permission prompts all go in over stdin. It starts on the
// first message; if it dies, the next one resumes the session.
//
// The transcript is a ListModel whose rows are only ever appended, so a
// row's index stays its id. Every row has every role:
//   kind     user | assistant | tool | error | note
//   text     what was said (markdown for the assistant)
//   note     a user row's attachments
//   images   a user row's screenshots, one path a line
//   name     a tool's name; detail its one-line summary; body its input
//            (a diff for edits); result what came back
//   toolId   the tool call's id
//   phase    a tool's: running | done | error | stopped
//   streaming  an assistant row still being written
//   open     a tool row unfolded in the sidebar

import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    // how it runs; a change applies from the next start, but for the model
    // and the mode, which a running session takes at once
    property string cwd: ""
    // --tools: null for Claude Code's own, "" for none
    property var tools: null
    property string appendPrompt: ""
    property var extraArgs: []
    property var env: ({})
    // a model alias, "" for the CLI's default
    property string modelPick: ""
    // --permission-mode
    property string mode: "default"

    readonly property bool alive: proc.running
    // a turn is under way
    property bool busy: false
    property string sessionId: ""
    // what it's doing now, for the status line and the bar
    property string activity: ""
    // the model the CLI says it's using
    property string modelName: ""
    property int contextUsed: 0
    property int contextWindow: 0
    // a turn ended or a prompt came while the sidebar wasn't on this tab
    property bool unseen: false
    // permission prompts waiting:
    // [{ id, tool, input, title, detail, suggestions }]
    property var asks: []
    // what goes with the next message:
    // [{ kind: "image" | "text", label, path, media, data, text }]
    property var attachments: []

    readonly property alias entries: rows
    readonly property bool empty: rows.count === 0

    // a file tool finished (the Desktop tab re-reads its diff)
    signal edited()
    // the CLI's rate_limit_event, for the subscription's usage
    signal rateLimit(var info)

    ListModel { id: rows }

    // --- sending ---------------------------------------------------------

    function send(text) {
        text = (text || "").trim()
        if (busy || (text === "" && attachments.length === 0)) return false
        var content = [], labels = [], images = []
        attachments.forEach(a => {
            if (a.kind === "image") {
                content.push({ type: "image", source: { type: "base64", media_type: a.media, data: a.data } })
                images.push(a.path)
            } else {
                content.push({ type: "text", text: a.label + ":\n```\n" + a.text + "\n```" })
            }
            labels.push(a.label)
        })
        if (text !== "") content.push({ type: "text", text: text })
        add({ kind: "user", text: text, note: labels.join("  ·  "), images: images.join("\n") })
        attachments = []
        busy = true
        activity = "Thinking"
        write({ type: "user", message: { role: "user", content: content },
                parent_tool_use_id: null, session_id: "" })
        return true
    }

    function attach(a) {
        if (a) attachments = attachments.concat([a])
    }

    function unattach(i) {
        var a = attachments.slice()
        a.splice(i, 1)
        attachments = a
    }

    // Stop: the turn ends with its result, like any other
    function stop() {
        if (!busy || !proc.running) return
        stopping = true
        control({ subtype: "interrupt" })
    }

    // how = "allow" | "always" | "deny"; `input` replaces the tool's own
    // (AskUserQuestion's answers), `message` is what a deny tells Claude
    function answer(id, how, input, message) {
        var a = asks.find(x => x.id === id)
        if (!a) return
        var r = how === "deny"
            ? { behavior: "deny", message: message || "The user said no." }
            : { behavior: "allow", updatedInput: input || a.input }
        if (how === "always" && a.suggestions.length > 0) r.updatedPermissions = a.suggestions
        write({ type: "control_response", response: { subtype: "success", request_id: id, response: r } })
        asks = asks.filter(x => x.id !== id)
        if (asks.length === 0 && busy) activity = "Working"
    }

    // A fresh conversation: the process goes, and the next message starts
    // a new one.
    function reset() {
        if (proc.running) {
            killing = true
            proc.signal(15)
        }
        queue = []
        rows.clear()
        toolRows = {}
        streamed = {}
        sessionId = ""
        busy = false
        stopping = false
        activity = ""
        asks = []
        attachments = []
        contextUsed = 0
        unseen = false
    }

    // A past session, shown from its saved rows (ai.py history); the next
    // message resumes it.
    function resume(id, saved) {
        reset()
        sessionId = id
        ;(saved || []).forEach(r => {
            if (r.kind === "user") add({ kind: "user", text: r.text, note: r.note || "" })
            else if (r.kind === "assistant") add({ kind: "assistant", text: r.text })
            else if (r.kind === "tool") addTool(r.toolId, r.name, r.input, true)
            else if (r.kind === "result") toolResult(r.toolId, r.content, r.isError, true)
        })
        for (var i = 0; i < rows.count; i++)
            if (rows.get(i).phase === "running") setRow(i, { phase: "done" })
    }

    // --- the process -----------------------------------------------------

    // lines waiting for the process to start
    property var queue: []
    property bool killing: false
    property bool stopping: false
    // tool id -> row
    property var toolRows: ({})
    // message id -> the rows its text streamed into, oldest first
    property var streamed: ({})
    // the mode as the CLI last reported it; a change from there isn't sent back
    property string cliMode: ""
    property int nextRequest: 0

    function write(obj) {
        var line = JSON.stringify(obj) + "\n"
        if (proc.running && proc.ready && !killing) proc.write(line)
        else {
            queue = queue.concat([line])
            // one on its way out starts again once it's gone
            if (!proc.running) start()
        }
    }

    function control(request) {
        if (!proc.running) return
        write({ type: "control_request", request_id: "sb" + (++nextRequest), request: request })
    }

    function start() {
        var c = ["claude", "-p", "--input-format", "stream-json", "--output-format", "stream-json",
                 "--verbose", "--include-partial-messages", "--permission-prompt-tool", "stdio",
                 "--permission-mode", mode]
        if (modelPick !== "") c.push("--model", modelPick)
        if (tools !== null) c.push("--tools", tools)
        if (appendPrompt !== "") c.push("--append-system-prompt", appendPrompt)
        if (sessionId !== "") c.push("--resume", sessionId)
        proc.command = c.concat(extraArgs)
        proc.ready = false
        proc.running = true
    }

    onModelPickChanged: if (proc.running) control({ subtype: "set_model", model: modelPick || "default" })
    onModeChanged: if (proc.running && mode !== cliMode) control({ subtype: "set_permission_mode", mode: mode })

    Process {
        id: proc
        property bool ready: false
        stdinEnabled: true
        workingDirectory: root.cwd
        environment: root.env

        onStarted: {
            ready = true
            var q = root.queue
            root.queue = []
            q.forEach(l => proc.write(l))
        }

        stdout: SplitParser {
            onRead: line => {
                // what a process on its way out still says belongs to the
                // conversation just dropped
                if (root.killing) return
                var ev
                try { ev = JSON.parse(line) } catch (e) { return }
                root.handle(ev)
            }
        }
        stderr: StdioCollector { id: errors }

        onExited: code => {
            ready = false
            if (root.killing) {
                root.killing = false
                if (root.queue.length > 0) root.start()
                return
            }
            if (root.busy) {
                root.add({ kind: "error", text: errors.text.trim().split("\n").slice(-3).join("\n")
                    || "claude stopped (exit code " + code + ")" })
                root.endTurn()
            }
        }
    }

    // --- reading ---------------------------------------------------------

    function handle(ev) {
        switch (ev.type) {
        case "system":
            if (ev.session_id) sessionId = ev.session_id
            if (ev.subtype === "init") {
                modelName = ev.model || ""
                takeMode(ev.permissionMode)
            } else if (ev.subtype === "status" && ev.permissionMode) {
                takeMode(ev.permissionMode)
            } else if (ev.subtype === "compact_boundary") {
                add({ kind: "note", text: "Earlier messages summarised" })
            }
            break
        case "stream_event":
            if (!ev.parent_tool_use_id) stream(ev.event)
            break
        case "assistant":
            if (ev.parent_tool_use_id) activity = "A subagent is working"
            else assistant(ev.message)
            break
        case "user":
            if (ev.parent_tool_use_id || !ev.message || typeof ev.message.content === "string") break
            ev.message.content.forEach(b => {
                if (b.type === "tool_result") toolResult(b.tool_use_id, b.content, b.is_error, false)
            })
            break
        case "control_request":
            request(ev)
            break
        case "result":
            result(ev)
            break
        case "rate_limit_event":
            rateLimit(ev.rate_limit_info || {})
            break
        }
    }

    function takeMode(m) {
        if (!m) return
        cliMode = m
        mode = m
    }

    function stream(e) {
        if (e.type === "message_start") {
            streamed[e.message.id] = []
            streamMsg = e.message.id
            streamIndex = {}
        } else if (e.type === "content_block_start") {
            var b = e.content_block
            if (b.type === "text") {
                var row = add({ kind: "assistant", text: "", streaming: true })
                streamIndex[e.index] = row
                streamed[streamMsg].push(row)
            } else if (b.type === "thinking") {
                activity = "Thinking"
            } else if (b.type === "tool_use") {
                activity = describe(b.name, {})
            }
        } else if (e.type === "content_block_delta" && e.delta.type === "text_delta") {
            var r = streamIndex[e.index]
            if (r === undefined) return
            setRow(r, { text: rows.get(r).text + e.delta.text })
            activity = "Writing"
        }
    }
    property string streamMsg: ""
    property var streamIndex: ({})

    function assistant(msg) {
        var u = msg.usage
        if (u) contextUsed = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0)
            + (u.cache_creation_input_tokens || 0) + (u.output_tokens || 0)
        ;(msg.content || []).forEach(b => {
            if (b.type === "text") {
                // the whole text, over what streamed in
                var q = streamed[msg.id] || []
                if (q.length > 0) setRow(q.shift(), { text: b.text, streaming: false })
                else if (b.text.trim() !== "") add({ kind: "assistant", text: b.text })
            } else if (b.type === "tool_use") {
                addTool(b.id, b.name, b.input, false)
            }
        })
    }

    function request(ev) {
        var r = ev.request || {}
        if (r.subtype !== "can_use_tool") {
            write({ type: "control_response",
                    response: { subtype: "error", request_id: ev.request_id, error: "Not supported" } })
            return
        }
        asks = asks.concat([{
            id: ev.request_id, tool: r.tool_name, input: r.input || {},
            title: describe(r.tool_name, r.input || {}),
            detail: askDetail(r.tool_name, r.input || {}, r.description || ""),
            suggestions: r.permission_suggestions || []
        }])
        activity = "Waiting for you"
        unseen = true
    }

    function result(ev) {
        var mu = ev.modelUsage || {}
        Object.keys(mu).forEach(k => { if (mu[k].contextWindow) contextWindow = mu[k].contextWindow })
        if (stopping) add({ kind: "note", text: "Stopped" })
        else if (ev.is_error || (ev.subtype && ev.subtype !== "success"))
            add({ kind: "error", text: ev.result || errorText(ev.subtype) })
        endTurn()
    }

    function errorText(subtype) {
        return subtype === "error_max_turns" ? "Stopped at the turn limit"
            : subtype === "error_during_execution" ? "Claude stopped with an error"
            : String(subtype || "Claude stopped with an error")
    }

    function endTurn() {
        for (var i = 0; i < rows.count; i++) {
            var r = rows.get(i)
            if (r.kind === "tool" && r.phase === "running") setRow(i, { phase: "stopped" })
            if (r.streaming) setRow(i, { streaming: false })
        }
        busy = false
        stopping = false
        activity = ""
        asks = []
        unseen = true
    }

    // --- rows ------------------------------------------------------------

    function add(o) {
        rows.append({
            kind: o.kind, text: o.text || "", note: o.note || "", images: o.images || "",
            name: o.name || "", detail: o.detail || "", body: o.body || "", result: "",
            toolId: o.toolId || "", phase: o.phase || "", streaming: !!o.streaming, open: false
        })
        return rows.count - 1
    }

    function setRow(i, o) {
        for (var k in o) rows.setProperty(i, k, o[k])
    }

    function addTool(id, name, input, quiet) {
        input = input || {}
        if (toolRows[id] !== undefined) return
        if (name === "TodoWrite") {
            toolRows[id] = add({ kind: "tool", name: name, toolId: id, phase: "running",
                                 detail: "To-do list", body: todos(input.todos) })
            return
        }
        toolRows[id] = add({ kind: "tool", name: name, toolId: id, phase: "running",
                             detail: describe(name, input), body: bodyOf(name, input) })
        if (!quiet) activity = describe(name, input)
    }

    function toolResult(id, content, isError, quiet) {
        var i = toolRows[id]
        if (i === undefined) return
        var text = typeof content === "string" ? content
            : (content || []).map(b => b.type === "text" ? b.text : b.type === "image" ? "[image]" : "").join("\n")
        if (text.length > 4000) text = text.slice(0, 4000) + "\n…"
        setRow(i, { result: text, phase: isError ? "error" : "done" })
        var name = rows.get(i).name
        if (!quiet && !isError && ["Edit", "Write", "MultiEdit", "NotebookEdit"].indexOf(name) !== -1) edited()
    }

    // a path under the working directory, without it
    function rel(p) {
        p = String(p || "")
        return cwd !== "" && p.indexOf(cwd + "/") === 0 ? p.slice(cwd.length + 1) : p
    }

    function describe(name, input) {
        input = input || {}
        switch (name) {
        case "Read":         return "Read " + rel(input.file_path)
        case "Edit":
        case "MultiEdit":    return "Edit " + rel(input.file_path)
        case "Write":        return "Write " + rel(input.file_path)
        case "NotebookEdit": return "Edit " + rel(input.notebook_path)
        case "Glob":         return "Find " + (input.pattern || "")
        case "Grep":         return "Search for " + (input.pattern || "")
        case "Bash":         return input.description || input.command || "Run a command"
        case "WebFetch":     return "Fetch " + (input.url || "")
        case "WebSearch":    return "Search the web for " + (input.query || "")
        case "Task":
        case "Agent":        return "Agent: " + (input.description || "")
        case "ExitPlanMode": return "The plan"
        case "AskUserQuestion": return "A question for you"
        default:             return name
        }
    }

    // the input worth reading: a diff for an edit, the command for Bash
    function bodyOf(name, input) {
        function lines(s, mark) {
            return String(s || "").split("\n").map(l => mark + l).join("\n")
        }
        switch (name) {
        case "Edit":
            return lines(input.old_string, "-") + "\n" + lines(input.new_string, "+")
        case "MultiEdit":
            return (input.edits || []).map(e => lines(e.old_string, "-") + "\n" + lines(e.new_string, "+")).join("\n@@\n")
        case "Write": {
            var w = String(input.content || "").replace(/\n$/, "").split("\n")
            return w.slice(0, 60).map(l => "+" + l).join("\n") + (w.length > 60 ? "\n… " + (w.length - 60) + " more lines" : "")
        }
        case "Bash":         return "$ " + (input.command || "")
        case "ExitPlanMode": return input.plan || ""
        case "Task":
        case "Agent":        return input.prompt || ""
        default: {
            var s = JSON.stringify(input, null, 2)
            return s === "{}" ? "" : s
        }
        }
    }

    function askDetail(name, input, description) {
        if (name === "Bash") return input.command || description
        if (name === "ExitPlanMode") return input.plan || ""
        return description !== rel(input.file_path) ? description : ""
    }

    function todos(list) {
        return (list || []).map(t => (t.status === "completed" ? "󰄬 " : t.status === "in_progress" ? "󰐊 " : "󰄱 ")
            + (t.status === "in_progress" && t.activeForm ? t.activeForm : t.content)).join("\n")
    }
}
