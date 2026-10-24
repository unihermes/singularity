// Singularity - Quickshell
// ~/.config/quickshell/services/Ai.qml
//
// The Claude sidebar (SUPER+I): three conversations through the claude CLI
// on the user's own subscription, one a tab.
//   Chat     plain chat, no tools, in a folder of its own
//   Desktop  changes to this desktop, made in a staging copy of the repo
//            (scripts/ai-desktop.sh) and applied once the diff is reviewed
//   Code     Claude Code in a project folder, asking before it acts
// Screenshots, the clipboard and the selection ride along with a message.
// The tab, the Code folder, each tab's model and mode and its conversation
// (resumed after a reload) live in ai.json.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool available: probe.found

    // the sidebar: on which screen, and whether it's out
    property bool shown: false
    property var screen: null
    // built on first open, then kept
    property bool used: false
    // hidden for a screenshot, so it isn't in it
    property bool capturing: false

    property string tab: "chat"
    readonly property var tabs: ["chat", "desktop", "code"]
    readonly property var current: sessionFor(tab)
    function sessionFor(t) { return t === "code" ? code : t === "desktop" ? desktop : chat }

    // for the bar: working, waiting on a prompt, or something new to read
    readonly property bool busy: chat.busy || desktop.busy || code.busy
    readonly property bool asking: chat.asks.length + desktop.asks.length + code.asks.length > 0
    readonly property bool unseen: chat.unseen || desktop.unseen || code.unseen

    // the subscription's usage, from the CLI's rate-limit events: 0..1, -1
    // until one comes
    property real fiveHour: -1
    property real sevenDay: -1

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: home + "/.cache/singularity/ai"
    readonly property string chatDir: cacheDir + "/chat"
    readonly property string py: Quickshell.shellPath("scripts/ai.py")
    readonly property string desktopScript: Quickshell.shellPath("scripts/ai-desktop.sh")
    readonly property var desktopEnv: ({ SINGULARITY_SETTINGS: Settings.stateDir + "/appearance.json" })

    // saved
    property string codeDir: home
    property var models: ({ chat: "", desktop: "", code: "" })
    property string codeMode: "default"

    // the choices the composer cycles through
    readonly property var modelChoices: [
        { value: "", text: "Default" }, { value: "opus", text: "Opus" },
        { value: "sonnet", text: "Sonnet" }, { value: "haiku", text: "Haiku" }]
    readonly property var modeChoices: [
        { value: "default", text: "Ask first" }, { value: "acceptEdits", text: "Accept edits" },
        { value: "plan", text: "Plan" }, { value: "auto", text: "Auto" }]

    function toggle(screen) {
        if (shown && root.screen === screen) { shown = false; return }
        root.screen = screen
        used = true
        shown = true
        current.unseen = false
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

    function cycleModel() {
        var i = modelChoices.findIndex(c => c.value === models[tab])
        setModel(tab, modelChoices[(i + 1) % modelChoices.length].value)
    }

    function cycleMode() {
        var i = modeChoices.findIndex(c => c.value === code.mode)
        code.mode = modeChoices[(i + 1) % modeChoices.length].value
    }

    function label(list, v) {
        var c = list.find(x => x.value === v)
        return c ? c.text : v
    }

    // the Desktop tab needs its staging copy before Claude starts in it
    function send(text) {
        var s = current
        if (s.busy) return false
        // a new conversation with nothing waiting starts from a fresh copy,
        // not one left from before later commits
        if (s === desktop && (!staged || (!hasChanges && s.sessionId === "" && s.empty))) {
            if (stageProc.running) return false
            stageProc.pending = text
            stageProc.running = true
            return true
        }
        return s.send(text)
    }

    // --- Desktop: the staging copy -------------------------------------

    property bool staged: false
    property string diff: ""
    // [{ path, added, removed }]
    readonly property var files: parseFiles(diff)
    readonly property bool hasChanges: files.length > 0
    property bool applying: false

    function apply() {
        if (desktop.busy || !hasChanges) return
        // detached: the reload after applying would kill a child
        Quickshell.execDetached({ command: [desktopScript, "apply"], environment: desktopEnv })
        applying = true
        afterApply.restart()
    }

    // the conversation goes first, so nothing still writes into the copy
    function discard() {
        desktop.reset()
        dropWhenGone = true
        if (!desktop.alive) dropStaging()
    }
    property bool dropWhenGone: false
    function dropStaging() {
        dropWhenGone = false
        Quickshell.execDetached({ command: [desktopScript, "discard"], environment: desktopEnv })
        staged = false
        diff = ""
    }

    function refreshDiff() {
        if (diffProc.running) diffProc.again = true
        else diffProc.running = true
    }

    function parseFiles(d) {
        var out = [], cur = null
        d.split("\n").forEach(l => {
            if (l.indexOf("diff --git ") === 0) {
                var m = l.match(/ b\/(.*)$/)
                cur = { path: m ? m[1] : l, added: 0, removed: 0 }
                out.push(cur)
            } else if (cur && l.indexOf("+++") !== 0 && l.indexOf("---") !== 0) {
                if (l[0] === "+") cur.added++
                else if (l[0] === "-") cur.removed++
            }
        })
        return out
    }

    Process {
        id: stageProc
        property string pending: ""
        command: [root.desktopScript, "start"]
        environment: root.desktopEnv
        onExited: code => {
            if (code !== 0) return
            root.staged = true
            root.desktop.send(pending)
            pending = ""
        }
    }

    Process {
        id: diffProc
        property bool again: false
        command: [root.desktopScript, "diff"]
        environment: root.desktopEnv
        stdout: StdioCollector {
            onStreamFinished: {
                root.diff = text
                // gone with nothing left means the apply went through
                if (root.applying && text === "") root.desktop.reset()
                root.applying = false
            }
        }
        onExited: code => {
            root.staged = code === 0
            // the Desktop conversation comes back only with its copy
            if (root.restoreDesktop !== "" && root.staged) root.resumeIn(root.desktop, root.restoreDesktop)
            root.restoreDesktop = ""
            if (again) { again = false; running = true }
        }
    }

    Timer {
        id: afterApply
        interval: 1500
        onTriggered: root.refreshDiff()
    }

    Connections {
        target: root.desktop
        function onEdited() { root.refreshDiff() }
        function onBusyChanged() { if (!root.desktop.busy) root.refreshDiff() }
        function onAliveChanged() { if (!root.desktop.alive && root.dropWhenGone) root.dropStaging() }
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

    // --- past sessions and projects ------------------------------------

    // this tab's earlier conversations: [{ id, title, last, turns, mtime }]
    property var past: []
    property bool pastLoading: false

    function listPast() {
        pastProc.command = [py, "sessions", current.cwd]
        pastLoading = true
        pastProc.running = true
    }

    function resume(id) { resumeIn(current, id) }

    // one at a time: a restart restores all three tabs at once
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

    // --- the three conversations ---------------------------------------

    function noteLimit(info) {
        var w = info.unifiedWindows || {}
        if (w.five_hour) fiveHour = w.five_hour.utilization
        if (w.seven_day) sevenDay = w.seven_day.utilization
    }

    ClaudeSession {
        id: chatSession
        cwd: root.chatDir
        tools: ""
        modelPick: root.models.chat || ""
        extraArgs: ["--strict-mcp-config"]
        appendPrompt: "You are the chat in the sidebar of the user's Linux desktop (Arch, Hyprland, "
            + "a Quickshell shell called Singularity). You have no tools here: just talk. Your "
            + "replies are rendered as markdown in a narrow panel, so keep tables small. "
            + "Screenshots, the clipboard or the selected text may come attached to a message."
        onRateLimit: info => root.noteLimit(info)
    }

    ClaudeSession {
        id: desktopSession
        cwd: root.home + "/.cache/singularity/ai-desktop/work"
        tools: "Read,Edit,Write,Glob,Grep"
        mode: "acceptEdits"
        modelPick: root.models.desktop || ""
        extraArgs: ["--strict-mcp-config"]
        appendPrompt: "You were invoked from the Desktop tab of the Claude sidebar in the user's "
            + "Singularity desktop. The working directory is a staging copy of their Singularity "
            + "repo: an Arch Linux + Hyprland + Quickshell desktop whose dotfiles live under "
            + "dotfiles/<app>/ and are symlinked into $HOME (dotfiles/quickshell/.config/quickshell "
            + "is ~/.config/quickshell, and so on). .live/appearance.json is the shell's live "
            + "settings file (bar height, radius, fonts, look, widget layout); edit it for requests "
            + "about those rather than changing defaults in code. Your edits are not live yet: the "
            + "user reviews the diff and applies it, and then Quickshell and Hyprland hot-reload. "
            + "You cannot run commands. Make focused, minimal edits that match the surrounding "
            + "code's style and comment density. End with one to three plain sentences saying what "
            + "you changed; the diff is shown separately. If the request is only a question, just "
            + "answer it."
        onRateLimit: info => root.noteLimit(info)
    }

    ClaudeSession {
        id: codeSession
        cwd: root.codeDir
        mode: root.codeMode
        modelPick: root.models.code || ""
        appendPrompt: "You are running in the Code tab of the Claude sidebar on the user's desktop, "
            + "a narrow panel that renders markdown. Permission prompts appear there as cards."
        onRateLimit: info => root.noteLimit(info)
        onModeChanged: if (mode !== root.codeMode) { root.codeMode = mode; root.save() }
    }

    readonly property alias chat: chatSession
    readonly property alias desktop: desktopSession
    readonly property alias code: codeSession

    CommandProbe { id: probe; name: "claude" }

    // each tab's conversation is picked up again after a reload or restart
    property string restoreDesktop: ""
    function restore(ids) {
        if (ids.chat) resumeIn(chat, ids.chat)
        if (ids.code) resumeIn(code, ids.code)
        // the diff read under way, or the next, says whether its copy is there
        restoreDesktop = ids.desktop || ""
        refreshDiff()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", chatDir])
        refreshDiff()
    }

    Connections { target: root.chat; function onSessionIdChanged() { root.save() } }
    Connections { target: root.desktop; function onSessionIdChanged() { root.save() } }
    Connections { target: root.code; function onSessionIdChanged() { root.save() } }

    // --- ai.json -------------------------------------------------------

    function save() { saveTimer.restart() }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: view.setText(JSON.stringify({
            tab: root.tab, codeDir: root.codeDir, models: root.models, codeMode: root.codeMode,
            sessions: { chat: root.chat.sessionId, desktop: root.desktop.sessionId, code: root.code.sessionId }
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
            var d
            try { d = JSON.parse(text()) } catch (e) { return }
            if (root.tabs.indexOf(d.tab) !== -1) root.tab = d.tab
            if (typeof d.codeDir === "string" && d.codeDir !== "") root.codeDir = d.codeDir
            if (d.models && typeof d.models === "object")
                root.models = Object.assign({ chat: "", desktop: "", code: "" }, d.models)
            if (root.modeChoices.some(c => c.value === d.codeMode)) root.codeMode = d.codeMode
            if (d.sessions && typeof d.sessions === "object") root.restore(d.sessions)
        }
    }
}
