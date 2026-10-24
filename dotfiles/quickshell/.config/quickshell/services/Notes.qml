// Singularity - Quickshell
// ~/.config/quickshell/services/Notes.qml
//
// The sticky notes' tabs and the last open one, in notes.json; edits save
// a moment after typing, flush() at once. Shown by the Notes window
// (SUPER+N), where every tab lives, and on the desktop, where a tab shows
// as a sticky while it has a place there (desk). The editors follow each
// other's typing through edited().

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // each tab: id (fixed, for the desktop), title, text, and desk: where
    // it sits on the desktop (fx, fy, size and screen, as a desktop
    // widget's place) or null when it's only in the window. Never empty
    // once loaded.
    property var tabs: [blank("Note")]
    property int current: 0

    // the ids of the tabs on the desktop
    readonly property var deskIds: tabs.filter(t => !!t.desk).map(t => t.id)

    // a tab's text changed in one editor, for the others showing it
    signal edited(int index)

    function newId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6) }
    function blank(title) { return { id: newId(), title: title, text: "", desk: null } }
    function indexOf(id) { return tabs.findIndex(t => t.id === id) }

    // a copy of tab i with fields changed, put back so bindings notice
    function patch(i, fields) {
        const t = tabs.slice()
        const n = {}
        for (const k in t[i]) n[k] = t[i][k]
        for (const k in fields) n[k] = fields[k]
        t[i] = n
        tabs = t
        saveTimer.restart()
    }

    function setText(i, text) {
        if (!tabs[i] || tabs[i].text === text) return
        tabs[i].text = text
        saveTimer.restart()
        edited(i)
    }

    function rename(i, title) {
        title = title.trim()
        if (!tabs[i] || title === "" || tabs[i].title === title) return
        patch(i, { title: title })
    }

    function freeTitle() {
        let n = tabs.length + 1
        while (tabs.some(t => t.title === "Note " + n)) n++
        return "Note " + n
    }

    // a new, empty tab after the others, opened
    function add() {
        tabs = tabs.concat([blank(freeTitle())])
        current = tabs.length - 1
        saveTimer.restart()
    }

    // a new, empty tab on the desktop, placed as `desk` says; its id
    function addOnDesk(desk) {
        const t = blank(freeTitle())
        t.desk = deskOf(desk)
        tabs = tabs.concat([t])
        saveTimer.restart()
        return t.id
    }

    function deskOf(d) {
        d = d || {}
        return { fx: typeof d.fx === "number" ? d.fx : -1, fy: typeof d.fy === "number" ? d.fy : -1,
                 size: ["s", "m", "l"].indexOf(d.size) !== -1 ? d.size : "m", screen: String(d.screen || "") }
    }

    // on the desktop (merging in place fields), or off it; the tab stays
    function setDesk(i, fields) {
        if (!tabs[i]) return
        if (fields === null) { patch(i, { desk: null }); return }
        const d = deskOf(tabs[i].desk)
        for (const k in fields) d[k] = fields[k]
        patch(i, { desk: deskOf(d) })
    }
    function toggleDesk(i) { if (tabs[i]) setDesk(i, tabs[i].desk ? null : {}) }

    // The last tab is emptied rather than removed, so there's always
    // somewhere to type.
    function remove(i) {
        if (!tabs[i]) return
        if (tabs.length === 1) {
            tabs = [blank("Note")]
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

    // a reload or restart inside the half second would lose the last edits
    Component.onDestruction: flush()

    FileView {
        id: view
        path: Quickshell.env("HOME") + "/.local/state/singularity/notes.json"
        preload: true
        blockLoading: true
        atomicWrites: true
        // written before returning, so the save on the way out lands
        blockWrites: true
        // no file until the first note is written
        printErrors: false

        onLoaded: {
            let d
            try { d = JSON.parse(text()) } catch (e) { return }
            const t = (d.tabs || []).filter(x => x && typeof x.title === "string")
                .map(x => ({ id: typeof x.id === "string" && x.id !== "" ? x.id : root.newId(),
                             title: x.title, text: typeof x.text === "string" ? x.text : "",
                             desk: x.desk ? root.deskOf(x.desk) : null }))
            if (t.length === 0) return
            const fresh = (d.tabs || []).some(x => x && typeof x.title === "string" && !x.id)
            root.tabs = t
            root.current = Math.max(0, Math.min(d.current | 0, t.length - 1))
            // ids handed out just now are kept
            if (fresh) saveTimer.restart()
        }
    }
}
