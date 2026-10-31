// Singularity - Quickshell
// ~/.config/quickshell/services/CodexSession.qml
//
// One conversation with Codex, the same shape as ClaudeSession so the
// sidebar draws either: `codex app-server` kept running, JSON-RPC a line
// each way. It starts on the first message (or a resume); a thread is made
// then and kept as sessionId, and turns go into it. Codex's approval
// requests for a command or a file change become asks, answered with
// accept, accept for the session or decline.
//
// The transcript rows are ClaudeSession's (kind, text, note, images, name,
// detail, body, result, toolId, phase, streaming, open), so AiTranscript
// reads both.
//
// mode, as the Code tab's chip sets it, picks the approval policy and the
// sandbox: default (and plan, which Codex lacks) asks before any write or
// command outside read-only, acceptEdits lets it write in the folder and
// asks to go further, auto never asks (it stays in the folder).

import Quickshell
import Quickshell.Io
import QtQuick

AiSession {
    id: root

    // added to Codex's instructions for a new thread
    property string instructions: ""
    // the Chat tab's: read-only, never asking
    property bool readOnly: false

    readonly property bool alive: proc.running
    property string turnId: ""
    // thread/list's answer, for the past sessions list
    signal listed(var threads)

    readonly property var rows: transcript

    readonly property string approval: readOnly || mode === "auto" ? "never" : "on-request"
    readonly property bool writes: !readOnly && (mode === "acceptEdits" || mode === "auto")
    readonly property string sandbox: writes ? "workspace-write" : "read-only"
    readonly property var sandboxPolicy: sandbox === "read-only" ? { type: "readOnly" }
        : { type: "workspaceWrite", writableRoots: [], networkAccess: false }

    // --- sending ---------------------------------------------------------

    function send(text) {
        text = (text || "").trim()
        if (busy || (text === "" && attachments.length === 0)) return false
        if (text === "/compact" && attachments.length === 0) {
            if (sessionId === "") return false
            add({ kind: "note", text: "Summarising the conversation…" })
            call("thread/compact/start", { threadId: sessionId })
            return true
        }
        var input = [], labels = [], images = []
        attachments.forEach(a => {
            if (a.kind === "image") {
                input.push({ type: "localImage", path: a.path })
                images.push(a.path)
            } else {
                input.push({ type: "text", text: a.label + ":\n```\n" + a.text + "\n```", text_elements: [] })
            }
            labels.push(a.label)
        })
        if (text !== "") input.push({ type: "text", text: text, text_elements: [] })
        add({ kind: "user", text: text, note: labels.join("  ·  "), images: images.join("\n") })
        attachments = []
        busy = true
        activity = "Thinking"
        whenThread(() => call("turn/start", {
            threadId: sessionId, input: input, model: modelPick !== "" ? modelPick : null,
            approvalPolicy: approval, sandboxPolicy: sandboxPolicy
        }, r => { if (r && r.turn) turnId = r.turn.id }, e => fail(e)))
        return true
    }

    function stop() {
        if (!busy || sessionId === "" || turnId === "") return
        stopping = true
        call("turn/interrupt", { threadId: sessionId, turnId: turnId })
    }

    // how = "allow" | "always" | "deny"
    function answer(id, how) {
        var a = asks.find(x => x.id === id)
        if (!a) return
        reply(id, { decision: how === "deny" ? "decline" : how === "always" ? "acceptForSession" : "accept" })
        asks = asks.filter(x => x.id !== id)
        if (asks.length === 0 && busy) activity = "Working"
    }

    function reset() {
        if (proc.running) {
            killing = true
            proc.signal(15)
        }
        pending = ({})
        waiting = []
        rows.clear()
        itemRows = {}
        sessionId = ""
        turnId = ""
        busy = false
        stopping = false
        activity = ""
        asks = []
        attachments = []
        contextUsed = 0
        unseen = false
    }

    // a past thread: thread/resume brings its turns back as rows
    function resume(id) {
        reset()
        sessionId = id
        resuming = true
        whenReady(() => call("thread/resume", threadArgs({ threadId: id }), r => {
            resuming = false
            var t = r && r.thread
            if (r && r.model) modelName = r.model
            ;((t && t.turns) || []).forEach(turn => (turn.items || []).forEach(it => item(it, true)))
        }, e => { resuming = false; sessionId = ""; add({ kind: "error", text: "Couldn't load that Codex conversation" }) }))
    }

    // this folder's threads, newest first (listed)
    function listPast() {
        whenReady(() => call("thread/list", { cwd: cwd, sortKey: "updated_at", limit: 50 },
            r => listed(((r && r.data) || []).map(t => ({
                id: t.id, title: t.name || t.preview || "Untitled", turns: -1, mtime: t.updatedAt || t.createdAt
            }))), () => listed([])))
    }

    // --- JSON-RPC ----------------------------------------------------------

    property bool killing: false
    property bool stopping: false
    property bool resuming: false
    property bool initialized: false
    property int nextId: 0
    // request id -> { ok, fail }
    property var pending: ({})
    // what waits for the server to be up
    property var waiting: []
    // item id -> row
    property var itemRows: ({})

    function write(obj) { proc.write(JSON.stringify(obj) + "\n") }
    function call(method, params, ok, bad) {
        var id = ++nextId
        pending[id] = { ok: ok || null, fail: bad || null }
        write({ id: id, method: method, params: params })
    }
    function reply(id, result) { write({ id: id, result: result }) }

    function whenReady(f) {
        if (proc.running && initialized && !killing) { f(); return }
        waiting = waiting.concat([f])
        if (!proc.running) start()
    }
    // a thread to send into: the one there is, else a new one
    function whenThread(f) {
        whenReady(() => {
            if (sessionId !== "") { f(); return }
            call("thread/start", threadArgs({ developerInstructions: instructions || null }), r => {
                sessionId = r.thread.id
                if (r.model) modelName = r.model
                f()
            }, e => fail(e))
        })
    }
    function threadArgs(o) {
        o.cwd = cwd
        o.approvalPolicy = approval
        o.sandbox = sandbox
        if (modelPick !== "") o.model = modelPick
        return o
    }

    function start() {
        initialized = false
        proc.running = true
    }

    function fail(e) {
        add({ kind: "error", text: (e && e.message) || "Codex stopped with an error" })
        endTurn(true)
    }

    Process {
        id: proc
        stdinEnabled: true
        workingDirectory: root.cwd
        command: ["codex", "app-server"]

        onStarted: {
            root.call("initialize", { clientInfo: { name: "singularity", title: "Singularity", version: "1" }, capabilities: null }, () => {
                root.write({ method: "initialized", params: {} })
                root.initialized = true
                var w = root.waiting
                root.waiting = []
                w.forEach(f => f())
            }, e => root.fail(e))
        }

        stdout: SplitParser {
            onRead: line => {
                if (root.killing) return
                var m
                try { m = JSON.parse(line) } catch (e) { return }
                root.handle(m)
            }
        }
        stderr: StdioCollector { id: errors }

        onExited: code => {
            root.initialized = false
            if (root.killing) {
                root.killing = false
                if (root.waiting.length > 0) root.start()
                return
            }
            if (root.busy) {
                root.add({ kind: "error", text: errors.text.trim().split("\n").slice(-3).join("\n")
                    || "codex stopped (exit code " + code + ")" })
                root.endTurn(true)
            }
        }
    }

    // --- reading ---------------------------------------------------------

    function handle(m) {
        // an answer to one of ours
        if (m.id !== undefined && m.method === undefined) {
            var p = pending[m.id]
            delete pending[m.id]
            if (!p) return
            if (m.error) { if (p.fail) p.fail(m.error) }
            else if (p.ok) p.ok(m.result)
            return
        }
        // a request of the server's: approvals; anything else is declined
        if (m.id !== undefined) {
            request(m)
            return
        }
        var q = m.params || {}
        if (q.threadId && q.threadId !== sessionId) return
        switch (m.method) {
        case "item/started": item(q.item, false, true); break
        case "item/completed": item(q.item, false, false); break
        case "item/agentMessage/delta": {
            var r = itemRows[q.itemId]
            if (r !== undefined) setRow(r, { text: rows.get(r).text + q.delta })
            activity = "Writing"
            break
        }
        case "item/reasoning/summaryTextDelta":
        case "item/reasoning/textDelta":
            activity = "Thinking"
            break
        case "turn/plan/updated":
            plan(q)
            break
        case "thread/tokenUsage/updated":
            if (q.tokenUsage) {
                contextUsed = (q.tokenUsage.last || {}).totalTokens || 0
                contextWindow = q.tokenUsage.modelContextWindow || 0
            }
            break
        case "account/rateLimits/updated":
            rateLimit(q.rateLimits || {})
            break
        case "thread/compacted":
            add({ kind: "note", text: "Earlier messages summarised" })
            break
        case "turn/completed": {
            var t = q.turn || {}
            if (stopping || t.status === "interrupted") add({ kind: "note", text: "Stopped" })
            else if (t.status === "failed") add({ kind: "error", text: (t.error && t.error.message) || "Codex stopped with an error" })
            endTurn(false)
            break
        }
        case "error":
            if (q.error && !q.willRetry) add({ kind: "error", text: q.error.message || "Codex error" })
            break
        }
    }

    function request(m) {
        var q = m.params || {}
        if (m.method !== "item/commandExecution/requestApproval" && m.method !== "item/fileChange/requestApproval") {
            write({ id: m.id, error: { code: -32601, message: "Not supported here" } })
            return
        }
        var command = m.method.indexOf("commandExecution") !== -1
        var r = itemRows[q.itemId]
        var row = r !== undefined ? rows.get(r) : null
        var title = command ? "Run " + shortCommand(q.command || "", q.commandActions)
            : row ? row.detail : "Edit files"
        asks = asks.concat([{
            id: m.id, tool: command ? "Bash" : "Edit", input: {}, title: title,
            detail: command ? (q.reason ? q.reason + "\n" : "") + shortCommand(q.command || "", q.commandActions)
                : (q.reason || (row ? row.body : "")),
            suggestions: [{ type: "session" }]
        }])
        activity = "Waiting for you"
        unseen = true
        asked(title)
    }

    // `bash -lc 'touch x'` as `touch x`
    function shortCommand(c, actions) {
        if (actions && actions.length > 0) return actions.map(a => a.command).join(" && ")
        var m = String(c).match(/^\S*bash -lc '([\s\S]*)'$/)
        return m ? m[1] : String(c)
    }

    // a ThreadItem, started or finished, into its row
    function item(it, history, starting) {
        if (!it) return
        var r = itemRows[it.id]
        switch (it.type) {
        case "userMessage":
            if (history) {
                var c = it.content || []
                add({ kind: "user", text: c.filter(x => x.type === "text").map(x => x.text).join("\n"),
                      note: c.some(x => x.type === "localImage" || x.type === "image") ? "Image" : "" })
            }
            break
        case "agentMessage":
            if (r === undefined) {
                if (!starting && (it.text || "").trim() === "") break
                itemRows[it.id] = add({ kind: "assistant", text: it.text || "", streaming: !!starting })
            } else if (!starting) {
                setRow(r, { text: it.text || rows.get(r).text, streaming: false })
            }
            break
        case "reasoning":
            if (!history) activity = "Thinking"
            break
        case "commandExecution": {
            var cmd = shortCommand(it.command, it.commandActions)
            var phase = it.status === "inProgress" ? "running"
                : it.status === "completed" && (it.exitCode === 0 || it.exitCode === null) ? "done" : "error"
            var o = { phase: history && phase === "running" ? "done" : phase, result: clip(it.aggregatedOutput || "") }
            if (r === undefined) itemRows[it.id] = add(Object.assign({ kind: "tool", name: "Bash", toolId: it.id,
                detail: cmd, body: "$ " + cmd }, o))
            else setRow(r, o)
            if (!history && phase === "running") activity = cmd
            break
        }
        case "fileChange": {
            var ch = it.changes || []
            var detail = ch.length === 1 ? "Edit " + rel(ch[0].path) : "Edit " + ch.length + " files"
            var body = ch.map(x => (ch.length > 1 ? "@@ " + rel(x.path) + "\n" : "")
                + ((x.kind && x.kind.type === "add") ? String(x.diff || "").replace(/\n$/, "").split("\n").map(l => "+" + l).join("\n")
                    : String(x.diff || "").split("\n").filter(l => !/^(---|\+\+\+|diff |index )/.test(l)).join("\n"))).join("\n")
            var fphase = it.status === "inProgress" ? "running" : it.status === "completed" ? "done" : "error"
            if (history && fphase === "running") fphase = "done"
            if (r === undefined) itemRows[it.id] = add({ kind: "tool", name: "Edit", toolId: it.id, phase: fphase,
                detail: detail, body: body, result: it.status === "declined" ? "Declined" : "" })
            else setRow(r, { phase: fphase, body: body, result: it.status === "declined" ? "Declined" : "" })
            if (!history && fphase === "done") edited()
            if (!history && fphase === "running") activity = detail
            break
        }
        case "webSearch":
        case "mcpToolCall":
        case "dynamicToolCall":
        case "imageView": {
            var d = it.type === "webSearch" ? "Search the web" + (it.query ? " for " + it.query : "")
                : it.type === "mcpToolCall" ? it.server + ": " + it.tool
                : it.type === "imageView" ? "View " + rel(it.path || "") : (it.tool || it.type)
            var st = starting ? "running" : (it.status === "failed" ? "error" : "done")
            if (history) st = "done"
            if (r === undefined) itemRows[it.id] = add({ kind: "tool", name: it.type, toolId: it.id, phase: st, detail: d })
            else setRow(r, { phase: st })
            if (!history && starting) activity = d
            break
        }
        case "contextCompaction":
            if (!starting) add({ kind: "note", text: "Earlier messages summarised" })
            break
        }
    }

    // the turn's plan, as one to-do row updated in place
    function plan(q) {
        var text = (q.plan || []).map(s => (s.status === "completed" ? "󰄬 " : s.status === "inProgress" ? "󰐊 " : "󰄱 ") + s.step).join("\n")
        var key = "plan:" + (q.turnId || "")
        var r = itemRows[key]
        if (r === undefined) itemRows[key] = add({ kind: "tool", name: "TodoWrite", toolId: key, phase: "running",
                                                   detail: "To-do list", body: text })
        else setRow(r, { body: text })
    }

    function endTurn(failed) {
        for (var i = 0; i < rows.count; i++) {
            var r = rows.get(i)
            if (r.kind === "tool" && r.phase === "running") setRow(i, { phase: r.name === "TodoWrite" ? "done" : "stopped" })
            if (r.streaming) setRow(i, { streaming: false })
        }
        var wasStopped = stopping
        busy = false
        stopping = false
        turnId = ""
        activity = ""
        asks = []
        unseen = true
        if (!wasStopped) turnEnded()
    }
}
