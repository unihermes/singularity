// The sticky notes' tabs and the last open one, in notes.json; edits save
// a moment after typing, flush() at once. Shown by the Notes window
// (SUPER+N), where every tab lives, and on the desktop, where a tab shows
// as a sticky while it has a place there (desk). The editors follow each
// other's typing through edited(). A tab is either text or a checklist
// (kind); switching keeps what the other side holds.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // each tab: id (fixed, for the desktop), title, text, kind ("text" or
    // "list"), items (the checklist's { text, done } rows), and desk: where
    // it sits on the desktop (fx, fy, size, w and h, and screen, as a desktop
    // widget's place) or null when it's only in the window. Never empty
    // once loaded.
    property var tabs: [blank("Note")]
    property int current: 0

    // the ids of the tabs on the desktop
    readonly property var deskIds: tabs.filter(t => !!t.desk).map(t => t.id)

    // a tab's text changed in one editor, for the others showing it
    signal edited(int index)

    function newId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6) }
    function blank(title) { return { id: newId(), title: title, text: "", format: "html", kind: "text", items: [], desk: null } }
    function indexOf(id) { return tabs.findIndex(t => t.id === id) }

    function editorText(tab) {
        if (!tab) return ""
        if (tab.format === "html") return tab.text
        return tab.text.replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;").replace(/\n/g, "<br>")
    }

    // the words of an editor's html (its head and style are not words)
    function plainOf(tab) {
        if (tab.format !== "html") return tab.text
        return tab.text.replace(/<head>[\s\S]*?<\/head>|<style[\s\S]*?<\/style>/gi, "")
            .replace(/<br\s*\/?>|<\/(p|div|li|h\d)>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&nbsp;|&#160;/gi, " ").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
    }

    function hasContent(tab) {
        if (!tab) return false
        return plainOf(tab).trim() !== "" || (tab.items || []).some(it => it.text.trim() !== "")
    }

    // --- checklists --------------------------------------------------------

    // typing in a row: no new array, so the editors keep their place
    function setItemText(i, k, text) {
        const it = tabs[i] && tabs[i].items[k]
        if (!it || it.text === text) return
        it.text = text
        saveTimer.restart()
        edited(i)
    }

    function setItems(i, items) { if (tabs[i]) patch(i, { items: items }) }

    function toggleItem(i, k) {
        const items = tabs[i].items.map(it => ({ text: it.text, done: it.done }))
        items[k].done = !items[k].done
        setItems(i, items)
    }

    // a new empty row after row k (-1 for the top)
    function addItem(i, k) {
        const items = tabs[i].items.slice()
        items.splice(k + 1, 0, { text: "", done: false })
        setItems(i, items)
    }

    function removeItem(i, k) {
        const items = tabs[i].items.slice()
        items.splice(k, 1)
        setItems(i, items)
    }

    function clearDone(i) { setItems(i, tabs[i].items.filter(it => !it.done)) }

    // A list made from text takes its lines, and text made from a list its
    // rows (struck when done), but only into an empty side.
    function setKind(i, kind) {
        const t = tabs[i]
        if (!t || t.kind === kind) return
        const f = { kind: kind }
        if (kind === "list" && t.items.length === 0) {
            f.items = plainOf(t).split("\n").map(l => l.trim()).filter(l => l !== "")
                .map(l => ({ text: l, done: false }))
        } else if (kind === "text" && !plainOf(t).trim()) {
            const esc = x => x.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            f.text = t.items.map(it => it.done ? "<s>" + esc(it.text) + "</s>" : esc(it.text)).join("<br>")
            f.format = "html"
        }
        patch(i, f)
    }

    function toggleFormat(editor, kind) {
        if (kind === "bold") editor.cursorSelection.font.bold = !editor.cursorSelection.font.bold
        else if (kind === "italic") editor.cursorSelection.font.italic = !editor.cursorSelection.font.italic
        else if (kind === "strikeout") editor.cursorSelection.font.strikeout = !editor.cursorSelection.font.strikeout
        editor.forceActiveFocus()
    }

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
        if (!tabs[i] || (tabs[i].text === text && tabs[i].format === "html")) return
        tabs[i].text = text
        tabs[i].format = "html"
        saveTimer.restart()
        edited(i)
    }

    function rename(i, title) {
        title = title.trim()
        if (!tabs[i] || title === "" || tabs[i].title === title) return
        patch(i, { title: title })
    }

    function freeTitle() {
        let n = 2
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

    // w and h, when set, are the note's own size in card units (dragged
    // in edit mode), over the grid's size
    function deskOf(d) {
        d = d || {}
        const out = { fx: typeof d.fx === "number" ? d.fx : -1, fy: typeof d.fy === "number" ? d.fy : -1,
                      size: ["s", "m", "l"].indexOf(d.size) !== -1 ? d.size : "m", screen: String(d.screen || "") }
        if (d.w > 0 && d.h > 0) { out.w = d.w; out.h = d.h }
        return out
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

    // Closing a sticky: an empty one is removed outright, one with text
    // stays as a tab in the window.
    function closeDesk(i) {
        if (!tabs[i]) return
        if (hasContent(tabs[i])) setDesk(i, null)
        else remove(i)
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
        path: Paths.stateDir + "/notes.json"
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
                             format: x.format === "html" ? "html" : "plain",
                             kind: x.kind === "list" ? "list" : "text",
                             items: (Array.isArray(x.items) ? x.items : []).filter(it => it && typeof it.text === "string")
                                 .map(it => ({ text: it.text, done: it.done === true })),
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
