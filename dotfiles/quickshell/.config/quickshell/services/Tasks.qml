// Singularity - Quickshell
// ~/.config/quickshell/services/Tasks.qml
//
// Google Tasks for the desktop's to-do widget, through scripts/gtasks.py:
// the lists and their tasks, read every five minutes while the widget is
// on and after each change. A change shows at once and is sent after; a
// failure puts the last reading back and says why (error).
//
// Signing in needs a Google Cloud "Desktop app" OAuth client's JSON in
// ~/Downloads (gtasks.py takes it from there); signIn() opens the browser.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string py: Quickshell.shellPath("scripts/gtasks.py")
    readonly property bool wanted: Settings.deskWidget("todo").on

    property bool connected: false
    // there's an OAuth client to sign in with
    property bool hasClient: false
    property bool signingIn: false
    property string error: ""
    // each list: id, title, tasks; each task: id, title, notes, done, due
    property var lists: []
    readonly property bool loading: listProc.running

    // the list the widget shows, by id; the first when it's gone
    readonly property var list: lists.find(l => l.id === Settings.todoList) || lists[0] || null

    function checkStatus() { if (!statusProc.running) statusProc.running = true }
    function refresh() { if (connected && !listProc.running) listProc.running = true }

    function showList(delta) {
        if (lists.length < 2 || !list) return
        const i = lists.indexOf(list)
        Settings.setTodoList(lists[((i + delta) % lists.length + lists.length) % lists.length].id)
    }

    // a copy of the lists with one task changed (null removes it), shown
    // before Google answers
    function edit(listId, taskId, fn) {
        lists = lists.map(l => l.id !== listId ? l : ({ id: l.id, title: l.title,
            tasks: l.tasks.map(t => t.id === taskId ? fn(t) : t).filter(t => t !== null) }))
    }

    function add(title) {
        title = title.trim()
        if (!list || title === "") return
        const l = list
        lists = lists.map(x => x.id !== l.id ? x : ({ id: x.id, title: x.title,
            tasks: [{ id: "", title: title, notes: "", done: false, due: "" }].concat(x.tasks) }))
        send(["add", l.id, title])
    }
    function toggle(task) {
        if (!list || task.id === "") return
        const done = !task.done
        edit(list.id, task.id, t => ({ id: t.id, title: t.title, notes: t.notes, done: done, due: t.due }))
        send(["done", list.id, task.id, done ? "1" : "0"])
    }
    function remove(task) {
        if (!list || task.id === "") return
        edit(list.id, task.id, t => null)
        send(["delete", list.id, task.id])
    }

    // changes go one after another, then one refresh
    property var queue: []
    function send(args) {
        queue = queue.concat([args])
        if (!changeProc.running) next()
    }
    function next() {
        if (queue.length === 0) { refresh(); return }
        changeProc.command = [py].concat(queue[0])
        queue = queue.slice(1)
        changeProc.running = true
    }

    function signIn() {
        if (signInProc.running) return
        error = ""
        signingIn = true
        signInProc.running = true
    }
    function signOut() {
        Quickshell.execDetached([py, "signout"])
        connected = false
        lists = []
    }

    function readError(text) {
        try { return JSON.parse(text).error || "" } catch (e) { return text.trim() || "Google Tasks didn't answer" }
    }

    Process {
        id: statusProc
        command: [root.py, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s
                try { s = JSON.parse(text) } catch (e) { return }
                root.hasClient = !!s.client
                root.connected = !!s.connected
                root.refresh()
            }
        }
    }

    Process {
        id: listProc
        command: [root.py, "lists"]
        stdout: StdioCollector { id: listOut }
        onExited: code => {
            if (code !== 0) { root.error = root.readError(listOut.text); return }
            try { root.lists = JSON.parse(listOut.text) || []; root.error = "" } catch (e) {}
        }
    }

    Process {
        id: changeProc
        stdout: StdioCollector { id: changeOut }
        onExited: code => {
            if (code !== 0) {
                root.error = root.readError(changeOut.text)
                root.queue = []
            }
            root.next()
        }
    }

    Process {
        id: signInProc
        command: [root.py, "auth"]
        stdout: StdioCollector { id: signInOut }
        onExited: code => {
            root.signingIn = false
            if (code !== 0) root.error = root.readError(signInOut.text)
            root.checkStatus()
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.wanted && root.connected
        onTriggered: root.refresh()
    }

    onWantedChanged: if (wanted) checkStatus()
    Component.onCompleted: if (wanted) checkStatus()
}
