// Singularity - Quickshell
// ~/.config/quickshell/services/Ai.qml
//
// The Claude sidebar (SUPER+I): two conversations through the claude CLI
// on the user's own subscription, one a tab.
//   Chat     plain chat, no tools, in a folder of its own
//   Code     Claude Code in a project folder, asking before it acts
// Either can run on Codex instead (CodexSession, the engine chip), each
// engine keeping its own conversation.
// Screenshots, the clipboard, the selection and files dropped on the
// sidebar ride along with a message.
// The tab, the Code folder, each tab's model and mode and its conversation
// (resumed after a reload) live in ai.json.

pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool hosted: Quickshell.env("SINGULARITY_AI_HOST") === "1"
    property var hostStatus: ({})
    readonly property bool available: probe.found

    // the sidebar: on which screen, and whether it's out
    property bool shown: false
    property var screen: null
    onShownChanged: save()
    onScreenChanged: if (screen) save()
    // built on first open, then kept
    property bool used: false
    // hidden for a screenshot, so it isn't in it
    property bool capturing: false

    property string tab: "chat"
    readonly property var tabs: ["chat", "code"]
    readonly property var current: sessionFor(tab)
    function sessionFor(t) {
        return t === "code" ? (codex("code") ? codeCodex : code)
            : (codex("chat") ? chatCodex : chat)
    }
    readonly property var all: [chat, code, chatCodex, codeCodex]

    // Claude or Codex, for Chat and Code
    property var engines: ({ chat: "claude", code: "claude" })
    function codex(t) { return engines[t] === "codex" }
    readonly property bool codexAvailable: codexProbe.found
    onCodexAvailableChanged: if (codexAvailable && shown) readUsage()
    function setEngine(t, e) {
        if (!(t in engines) || (e === "codex" && !codexAvailable)) return
        var o = Object.assign({}, engines)
        o[t] = e
        engines = o
        current.unseen = false
        save()
    }

    // for the bar: working, waiting on a prompt, or something new to read
    readonly property bool busy: hosted ? all.some(s => s.busy) : !!hostStatus.busy
    readonly property bool asking: hosted ? all.some(s => s.asks.length > 0) : !!hostStatus.asking
    readonly property bool unseen: hosted ? all.some(s => s.unseen) : !!hostStatus.unseen

    // the subscription's usage, 0..1 (-1 until known) and when each window
    // resets (epoch seconds, 0 unknown): refreshed while the sidebar shows,
    // and from the CLI's rate-limit events between
    property real fiveHour: -1
    property real sevenDay: -1
    property int fiveHourResets: 0
    property int sevenDayResets: 0
    // Codex's primary and secondary windows, or null until read
    property var codexUsage: null

    function readUsage() {
        if (!usageProc.running) usageProc.running = true
        if (codexAvailable && !codexUsageProc.running) codexUsageProc.running = true
    }
    Process {
        id: usageProc
        command: [root.py, "usage"]
        stdout: StdioCollector {
            onStreamFinished: {
                var u
                try { u = JSON.parse(text) } catch (e) { return }
                if (u.five_hour) { root.fiveHour = u.five_hour.used; root.fiveHourResets = u.five_hour.resets }
                if (u.seven_day) { root.sevenDay = u.seven_day.used; root.sevenDayResets = u.seven_day.resets }
            }
        }
    }
    Process {
        id: codexUsageProc
        command: ["codex", "app-server"]
        stdinEnabled: true
        onStarted: {
            codexUsageProc.write(JSON.stringify({ id: 1, method: "initialize", params: {
                clientInfo: { name: "singularity", title: "Singularity", version: "1" }, capabilities: null
            } }) + "\n")
            codexUsageTimeout.restart()
        }
        stdout: SplitParser {
            onRead: line => {
                var m
                try { m = JSON.parse(line) } catch (e) { return }
                if (m.id === 1 && m.result) {
                    codexUsageProc.write(JSON.stringify({ method: "initialized", params: {} }) + "\n")
                    codexUsageProc.write(JSON.stringify({ id: 2, method: "account/rateLimits/read", params: {} }) + "\n")
                } else if (m.id === 2) {
                    if (m.result && m.result.rateLimits) root.noteCodexLimit(m.result.rateLimits)
                    codexUsageProc.running = false
                } else if (m.id === 1 && m.error) {
                    codexUsageProc.running = false
                }
            }
        }
        onExited: codexUsageTimeout.stop()
    }
    Timer {
        id: codexUsageTimeout
        interval: 15000
        onTriggered: codexUsageProc.running = false
    }
    Timer {
        interval: 120000
        repeat: true
        running: root.hosted && root.shown
        triggeredOnStart: true
        onTriggered: root.readUsage()
    }

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: home + "/.cache/singularity/ai"
    readonly property string chatDir: cacheDir + "/chat"
    readonly property string py: Quickshell.shellPath("scripts/ai.py")

    // saved; models by tab, and by tab + "Codex" for Codex's
    property string codeDir: home
    property var models: ({ chat: "", code: "", chatCodex: "", codeCodex: "" })
    property var reasoning: ({ chat: "", code: "", chatCodex: "", codeCodex: "" })
    function setReasoning(k, value) {
        var choices = Object.assign({}, reasoning)
        choices[k] = value
        reasoning = choices
        save()
    }
    property string codeMode: "default"

    // the composer's choices
    readonly property var modelChoices: [
        { value: "", text: "Default" }, { value: "opus", text: "Opus" },
        { value: "sonnet", text: "Sonnet" }, { value: "haiku", text: "Haiku" }]
    readonly property var modeChoices: [
        { value: "default", text: "Ask first" }, { value: "acceptEdits", text: "Accept edits" },
        { value: "plan", text: "Plan" }, { value: "auto", text: "Auto" }]
    // Codex has no plan mode
    readonly property var codexModeChoices: modeChoices.filter(c => c.value !== "plan")
    function modesFor(t) { return codex(t) ? codexModeChoices : modeChoices }

    // Codex's models as its own cache lists them, Default first
    property var codexModels: []
    FileView {
        path: root.home + "/.codex/models_cache.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.codexModels = (JSON.parse(text()).models || []).filter(m => m.visibility === "list")
                    .map(m => ({ value: m.slug, text: m.display_name || m.slug }))
            } catch (e) {}
        }
    }
    function modelKey(t) { return codex(t) ? t + "Codex" : t }
    function modelChoicesFor(t) { return codex(t) ? [{ value: "", text: "Default" }].concat(codexModels) : modelChoices }

    function toggle(screen) {
        if (!hosted) {
            Notifications.shown = false
            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/ai_host.py"), Quickshell.shellPath("AiHost.qml"), "toggle", screen ? screen.name : ""])
            return
        }
        if (shown && root.screen === screen) { shown = false; return }
        root.screen = screen
        used = true
        shown = true
        current.unseen = false
    }

    function openConversation(t, engine) {
        if (tabs.indexOf(t) === -1) return
        if (!hosted) {
            Notifications.shown = false
            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/ai_host.py"), Quickshell.shellPath("AiHost.qml"), "open", t, engine])
            return
        }
        setEngine(t, engine)
        setTab(t)
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        root.screen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
        used = true
        shown = true
    }

    function close() {
        if (hosted) shown = false
        else Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/ai_host.py"), Quickshell.shellPath("AiHost.qml"), "close"])
    }

    function setTab(t) {
        if (tabs.indexOf(t) === -1) return
        tab = t
        current.unseen = false
        save()
    }

    function setModel(t, m) {
        var o = Object.assign({}, models)
        o[t] = m
        models = o
        save()
    }

    function cycleMode() {
        var list = modesFor("code")
        var i = list.findIndex(c => c.value === codeMode)
        setCodeMode(list[(i + 1) % list.length].value)
    }
    // Code's mode, shared by both engines (Codex reads plan as Ask first)
    function setCodeMode(m) {
        code.mode = m
        if (codeMode !== m) { codeMode = m; save() }
    }

    // the model chip: the pick, else the model the CLI says it runs
    // ("claude-opus-5-5" reads "Opus 5.5"), else Default till it starts
    function modelText(t) {
        var pick = models[modelKey(t)] || ""
        if (pick !== "") return label(modelChoicesFor(t), pick)
        if (codex(t)) {
            var running = sessionFor(t).modelName
            return running !== "" ? label(codexModels, running) : "Default"
        }
        var m = sessionFor(t).modelName.match(/claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?!\d)/)
        return m ? m[1][0].toUpperCase() + m[1].slice(1) + " " + m[2] + (m[3] ? "." + m[3] : "") : "Default"
    }

    function label(list, v) {
        var c = list.find(x => x.value === v)
        return c ? c.text : v
    }

    function send(text) {
        return current.busy ? false : current.send(text)
    }

    // --- attachments ---------------------------------------------------

    // area | window | screen | clipboard | selection, for this tab
    function capture(kind) {
        if (shotProc.running) return
        shotProc.target = current
        var shot = ["area", "window", "screen"].indexOf(kind) !== -1
        shotProc.command = shot
            ? [py, "shot", kind, screen ? screen.name : ""]
            : [py, "paste", kind]
        capturing = shot
        // a beat for the sidebar to leave the screen first
        if (shot) shotDelay.restart()
        else shotProc.running = true
    }

    Timer {
        id: shotDelay
        interval: 180
        onTriggered: shotProc.running = true
    }

    Process {
        id: shotProc
        property var target: null
        stdout: StdioCollector {
            onStreamFinished: {
                var a = null
                try { a = JSON.parse(text) } catch (e) {}
                if (a && shotProc.target) shotProc.target.attach(a)
            }
        }
        onExited: root.capturing = false
    }

    // files dropped on the sidebar, one at a time onto this tab
    property var dropQueue: []
    function attachFiles(urls) {
        var paths = urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")))
            .filter(p => p.indexOf("/") === 0)
        dropQueue = dropQueue.concat(paths.map(p => ({ target: current, path: p })))
        if (!fileProc.running) nextFile()
    }
    function nextFile() {
        if (dropQueue.length === 0) return
        var f = dropQueue[0]
        dropQueue = dropQueue.slice(1)
        fileProc.target = f.target
        fileProc.command = [py, "file", f.path]
        fileProc.running = true
    }
    Process {
        id: fileProc
        property var target: null
        stdout: StdioCollector {
            onStreamFinished: {
                var a = null
                try { a = JSON.parse(text) } catch (e) {}
                if (a && fileProc.target) fileProc.target.attach(a)
            }
        }
        onExited: root.nextFile()
    }

    // --- past sessions and projects ------------------------------------

    // this tab's earlier conversations: [{ id, title, last, turns, mtime }]
    property var past: []
    property bool pastLoading: false

    function listPast() {
        pastLoading = true
        if (codex(tab)) { past = []; current.listPast(); return }
        pastProc.command = [py, "sessions", current.cwd]
        pastProc.running = true
    }
    function tookPast(rows) {
        past = rows
        pastLoading = false
    }

    function resume(id) {
        if (codex(tab)) current.resume(id)
        else resumeIn(current, id)
    }

    // one at a time: a restart restores every tab at once
    property var resumeQueue: []
    function resumeIn(s, id) {
        resumeQueue = resumeQueue.concat([{ target: s, id: id }])
        if (!historyProc.running) nextResume()
    }
    function nextResume() {
        if (resumeQueue.length === 0) return
        var r = resumeQueue[0]
        resumeQueue = resumeQueue.slice(1)
        historyProc.target = r.target
        historyProc.sid = r.id
        historyProc.command = [py, "history", r.target.cwd, r.id]
        historyProc.running = true
    }

    // the folders Claude Code has worked in: [{ path, name, used }]
    property var projects: []

    function listProjects() { projectsProc.running = true }

    function setCodeDir(dir) {
        dir = dir.replace(/\/+$/, "")
        if (dir.indexOf("~") === 0) dir = home + dir.slice(1)
        if (dir === "" || dir === codeDir) return
        code.reset()
        codeCodex.reset()
        codeDir = dir
        save()
    }

    Process {
        id: pastProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.past = JSON.parse(text) || [] } catch (e) { root.past = [] }
                root.pastLoading = false
            }
        }
    }

    Process {
        id: historyProc
        property var target: null
        property string sid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = []
                try { rows = JSON.parse(text) || [] } catch (e) {}
                historyProc.target.resume(historyProc.sid, rows)
            }
        }
        onExited: root.nextResume()
    }

    Process {
        id: projectsProc
        command: [root.py, "projects"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.projects = JSON.parse(text) || [] } catch (e) { root.projects = [] }
            }
        }
    }

    // --- the conversations ---------------------------------------

    function noteLimit(info) {
        var w = info.unifiedWindows || {}
        if (w.five_hour) fiveHour = w.five_hour.utilization
        if (w.seven_day) sevenDay = w.seven_day.utilization
        readUsage()
    }

    ClaudeSession {
        id: chatSession
        cwd: root.chatDir
        tools: ""
        modelPick: root.models.chat || ""
        reasoningPick: root.reasoning.chat || ""
        extraArgs: ["--strict-mcp-config"]
        appendPrompt: "You are the chat in the sidebar of the user's Linux desktop (Arch, Hyprland, "
            + "a Quickshell shell called Singularity). You have no tools here: just talk. Your "
            + "replies are rendered as markdown in a narrow panel, so keep tables small. "
            + "Screenshots, the clipboard or the selected text may come attached to a message."
        onRateLimit: info => root.noteLimit(info)
    }

    ClaudeSession {
        id: codeSession
        cwd: root.codeDir
        mode: root.codeMode
        modelPick: root.models.code || ""
        reasoningPick: root.reasoning.code || ""
        appendPrompt: "You are running in the Code tab of the Claude sidebar on the user's desktop, "
            + "a narrow panel that renders markdown. Permission prompts appear there as cards."
        onRateLimit: info => root.noteLimit(info)
        onModeChanged: if (mode !== root.codeMode) { root.codeMode = mode; root.save() }
    }

    CodexSession {
        id: chatCodexSession
        cwd: root.chatDir
        readOnly: true
        modelPick: root.models.chatCodex || ""
        reasoningPick: root.reasoning.chatCodex || ""
        instructions: "You are the chat in the sidebar of the user's Linux desktop (Arch, Hyprland, "
            + "a Quickshell shell called Singularity), run through Codex. Just talk; you can read but "
            + "not change anything. Your replies are rendered as markdown in a narrow panel, so keep "
            + "tables small. Screenshots, the clipboard or the selected text may come attached."
        onRateLimit: info => root.noteCodexLimit(info)
        onListed: rows => root.tookPast(rows)
    }

    CodexSession {
        id: codeCodexSession
        cwd: root.codeDir
        mode: root.codeMode
        modelPick: root.models.codeCodex || ""
        reasoningPick: root.reasoning.codeCodex || ""
        instructions: "You are running in the Code tab of a sidebar on the user's desktop, a narrow "
            + "panel that renders markdown. Approval requests appear there as cards."
        onRateLimit: info => root.noteCodexLimit(info)
        onListed: rows => root.tookPast(rows)
    }

    // Codex's own limit, as it reports it after each reply
    function noteCodexLimit(r) {
        function window(w) {
            return w && w.usedPercent !== undefined && w.usedPercent !== null
                ? { used: w.usedPercent / 100, resets: w.resetsAt || 0 } : null
        }
        var primary = window(r.primary), secondary = window(r.secondary)
        if (primary || secondary) codexUsage = { primary: primary, secondary: secondary }
    }

    readonly property alias chatCodex: chatCodexSession
    readonly property alias codeCodex: codeCodexSession
    readonly property alias chat: chatSession
    readonly property alias code: codeSession

    CommandProbe { id: probe; name: "claude" }
    CommandProbe { id: codexProbe; name: "codex" }

    // each tab's conversation is picked up again after a reload or restart
    function restore(ids) {
        if (ids.chat) resumeIn(chat, ids.chat)
        if (ids.code) resumeIn(code, ids.code)
        // Codex's come back through its own app-server, started for it
        if (ids.chatCodex) chatCodex.resume(ids.chatCodex)
        if (ids.codeCodex) codeCodex.resume(ids.codeCodex)
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", chatDir])
        if (!hosted) Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/ai_host.py"), Quickshell.shellPath("AiHost.qml")])
    }
    FileView {
        path: root.hosted ? "" : Quickshell.env("XDG_RUNTIME_DIR") + "/singularity-ai-status.json"
        watchChanges: !root.hosted
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (root.hosted) return
            try { root.hostStatus = JSON.parse(text()) } catch (e) { return }
            root.screen = Quickshell.screens.find(s => s.name === root.hostStatus.screen) || null
            root.shown = !!root.hostStatus.shown
        }
    }

    // --- notifications while the sidebar is away --------------------------

    // A reply done or a prompt waiting, as a notification with Open, which
    // brings the sidebar out on that tab on the focused screen. One a tab;
    // a newer one takes over its Open.
    readonly property var tabNames: ({ chat: "Chat", code: "Code" })
    function notify(t, engine, title, body) {
        if (shown) return
        var p = t === "code" ? codeNote : chatNote
        // the prose only (no code or tables), markdown marks and line
        // breaks out, a couple of lines kept
        body = String(body || "").replace(/```[\s\S]*?(```|$)/g, "")
            .split("\n").filter(l => !/^\s*\|/.test(l)).join(" ")
            .replace(/[*_`#>]/g, "").replace(/\s+/g, " ").trim()
        if (body.length > 160) body = body.slice(0, 157) + "…"
        p.running = false
        p.engine = engine
        p.command = ["notify-send", "-a", "Claude", "-i", "claude-desktop", "-A", "default=Open",
                     "-h", "string:desktop-entry:singularity-sidebar-" + t + "-" + engine,
                     "Claude · " + tabNames[t] + ": " + title, body]
        p.running = true
    }
    function openFromNote(t, engine, text) {
        if (text.trim() !== "open" && text.trim() !== "default") return
        openConversation(t, engine)
    }
    Process {
        id: chatNote
        property string engine: "claude"
        stdout: StdioCollector { onStreamFinished: root.openFromNote("chat", chatNote.engine, text) }
    }
    Process {
        id: codeNote
        property string engine: "claude"
        stdout: StdioCollector { onStreamFinished: root.openFromNote("code", codeNote.engine, text) }
    }
    Connections {
        target: root.chat
        function onTurnEnded() { root.notify("chat", "claude", "replied", root.chat.lastReply()) }
        function onAsked(title) { root.notify("chat", "claude", "waiting for you", title) }
    }
    Connections {
        target: root.code
        function onTurnEnded() { root.notify("code", "claude", "done", root.code.lastReply()) }
        function onAsked(title) { root.notify("code", "claude", "waiting for you", title) }
    }

    Connections {
        target: root.chatCodex
        function onTurnEnded() { root.notify("chat", "codex", "replied", root.chatCodex.lastReply()) }
        function onAsked(title) { root.notify("chat", "codex", "waiting for you", title) }
        function onSessionIdChanged() { root.save() }
    }
    Connections {
        target: root.codeCodex
        function onTurnEnded() { root.notify("code", "codex", "done", root.codeCodex.lastReply()) }
        function onAsked(title) { root.notify("code", "codex", "waiting for you", title) }
        function onSessionIdChanged() { root.save() }
    }

    Connections { target: root.chat; function onSessionIdChanged() { root.save() } }
    Connections { target: root.code; function onSessionIdChanged() { root.save() } }

    // --- ai.json -------------------------------------------------------

    function save() { if (hosted) saveTimer.restart() }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: view.setText(JSON.stringify({
            tab: root.tab, codeDir: root.codeDir, models: root.models, reasoning: root.reasoning, codeMode: root.codeMode,
            engines: root.engines, shown: root.shown, screen: root.screen ? root.screen.name : "",
            sessions: { chat: root.chat.sessionId, code: root.code.sessionId,
                        chatCodex: root.chatCodex.sessionId, codeCodex: root.codeCodex.sessionId }
        }, null, 2) + "\n")
    }

    FileView {
        id: view
        path: Settings.stateDir + "/ai.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            if (!root.hosted) return
            var d
            try { d = JSON.parse(text()) } catch (e) { return }
            if (root.tabs.indexOf(d.tab) !== -1) root.tab = d.tab
            if (typeof d.codeDir === "string" && d.codeDir !== "") root.codeDir = d.codeDir
            if (d.models && typeof d.models === "object")
                root.models = Object.assign({ chat: "", code: "", chatCodex: "", codeCodex: "" }, d.models)
            if (d.reasoning && typeof d.reasoning === "object")
                root.reasoning = Object.assign({ chat: "", code: "", chatCodex: "", codeCodex: "" }, d.reasoning)
            if (d.engines && typeof d.engines === "object")
                root.engines = Object.assign({ chat: "claude", code: "claude" }, d.engines)
            if (root.modeChoices.some(c => c.value === d.codeMode)) root.codeMode = d.codeMode
            if (d.sessions && typeof d.sessions === "object") root.restore(d.sessions)
            if (d.shown === true) {
                root.screen = Quickshell.screens.find(s => s.name === d.screen) || Quickshell.screens[0] || null
                root.used = true
                root.shown = true
            }
        }
    }
}
