// Singularity - Quickshell
// ~/.config/quickshell/services/Notes.qml
//
// The sticky notes behind windows/NotesWindow.qml: a list of tabs, each a title and
// its text, and which one was open last. Kept in
// ~/.local/state/singularity/notes.json with the rest of the shell's state.
//
// Every edit lands in memory at once and reaches the disk a moment after the
// last keystroke, so typing never waits on a write. flush() writes straight
// away, for the window closing.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ title, text }]; never empty once loaded
    property var tabs: [{ title: "Note", text: "" }]
    property int current: 0

    function setText(i, text) {
        if (!tabs[i] || tabs[i].text === text) return
        tabs[i].text = text
        saveTimer.restart()
    }

    function rename(i, title) {
        title = title.trim()
        if (!tabs[i] || title === "" || tabs[i].title === title) return
        const t = tabs.slice()
        t[i] = { title: title, text: t[i].text }
        tabs = t
        saveTimer.restart()
    }

    // a new, empty tab after the others, opened
    function add() {
        let n = tabs.length + 1
        while (tabs.some(t => t.title === "Note " + n)) n++
        tabs = tabs.concat([{ title: "Note " + n, text: "" }])
        current = tabs.length - 1
        saveTimer.restart()
    }

    // The last tab is emptied rather than removed, so there's always
    // somewhere to type.
    function remove(i) {
        if (!tabs[i]) return
        if (tabs.length === 1) {
            tabs = [{ title: "Note", text: "" }]
        } else {
            const t = tabs.slice()
            t.splice(i, 1)
            tabs = t
        }
        current = Math.min(current > i ? current - 1 : current, tabs.length - 1)
        saveTimer.restart()
    }

    function select(i) {
        if (i < 0 || i >= tabs.length || i === current) return
        current = i
        saveTimer.restart()
    }

    function step(delta) {
        select(((current + delta) % tabs.length + tabs.length) % tabs.length)
    }

    function flush() {
        if (!saveTimer.running) return
        saveTimer.stop()
        save()
    }

    function save() {
        view.setText(JSON.stringify({ current: current, tabs: tabs }, null, 2) + "\n")
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root.save()
    }

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.local/state/singularity/notes.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        // no file until the first note is written
        printErrors: false

        onLoaded: {
            let d
            try { d = JSON.parse(text()) } catch (e) { return }
            const t = (d.tabs || []).filter(x => x && typeof x.title === "string")
                .map(x => ({ title: x.title, text: typeof x.text === "string" ? x.text : "" }))
            if (t.length === 0) return
            root.tabs = t
            root.current = Math.max(0, Math.min(d.current | 0, t.length - 1))
        }
    }
}
