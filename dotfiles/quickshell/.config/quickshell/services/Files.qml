// The launcher's file search: names under $HOME from fd (fixed strings,
// --hidden, debounced), with EXCLUDES for app data dumps and more matches
// fetched than shown, then ranked here. With nothing typed, recent files
// from recently-used.xbel.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ name, path, dir, isDir }]
    property var results: []
    // the same shape, from recently-used.xbel, newest first: only the ones
    // still on disk, as the list keeps a file after it's deleted
    property var recent: []
    // every file entry in the .xbel, before that check
    property var bookmarked: []
    property bool searching: false
    property string query: ""
    property bool searchPending: false

    readonly property string home: Quickshell.env("HOME")
    // shown, and asked of fd: the gap is what makes ranking possible
    readonly property int maxResults: 60
    readonly property int fetchLimit: 400

    // never what a name search meant: caches, VCS internals, package stores,
    // app data
    readonly property var excludes: [
        ".git", "node_modules", "__pycache__", ".venv", ".cache",
        ".local/share/Trash", ".steam", ".local/share/Steam", ".vscode-oss",
        ".mozilla", ".thunderbird", ".var", ".cargo", ".rustup", ".npm",
        ".nvm", ".gradle", ".m2", ".java", ".wine", ".pki", ".gnupg",
    ]

    function search(q) {
        query = q
        searchPending = q.trim() !== ""
        searching = searchPending
        if (searchPending) debounce.restart()
        else { results = []; debounce.stop() }
        finder.running = false
    }

    function clear() { search("") }

    // Wait for both process exit and collected stdout before reusing finder.
    function startSearch() {
        if (finder.running || finder.awaitingOutput || debounce.running) return
        if (!searchPending) { searching = false; return }
        searchPending = false
        finder.searchQuery = query
        var command = ["fd", "--hidden", "--fixed-strings", "--ignore-case", "--follow",
            "--max-results", String(fetchLimit), "--print0"]
        for (var excluded of excludes) command.push("--exclude", excluded)
        finder.command = command.concat(["--", query.trim(), home])
        finder.awaitingOutput = true
        finder.running = true
    }

    function finishSearch(text) {
        if (!searchPending && finder.searchQuery === query && query.trim() !== "")
            results = rankResults(text, query)
        finder.awaitingOutput = false
        startSearch()
    }

    // ~/Documents/report.pdf -> "~/Documents", for the second line of a row
    function pretty(path) {
        return (path === root.home || path.startsWith(root.home + "/")) ? "~" + path.slice(root.home.length) : path
    }

    // open-file.sh, not xdg-open, which silently does nothing for files with
    // no handler or a terminal one
    readonly property string opener:
        Quickshell.env("HOME") + "/.config/quickshell/scripts/open-file.sh"

    function open(item) {
        if (!item) return
        Quickshell.execDetached([root.opener, item.path])
    }

    // Shift+Enter: show the file in its directory rather than opening it,
    // which is what you want for anything with no useful default handler.
    function reveal(item) {
        if (!item) return
        Quickshell.execDetached(["thunar", item.isDir ? item.path : item.dir])
    }

    function entry(path, isDir) {
        var cut = path.lastIndexOf("/")
        return {
            name: path.slice(cut + 1),
            path: path,
            dir: cut > 0 ? path.slice(0, cut) : "/",
            isDir: !!isDir,
        }
    }

    function recentEntries(xml) {
        var out = [], seen = new Set(), bookmark
        var bookmarks = /<bookmark\b([^>]*)>/g
        while ((bookmark = bookmarks.exec(xml)) !== null) {
            var attrs = {}, attr
            var attributes = /\s(href|modified)\s*=\s*(["'])(.*?)\2/g
            while ((attr = attributes.exec(bookmark[1])) !== null) attrs[attr[1]] = attr[3]
            if (!attrs.href || !attrs.modified) continue
            // Decode XML before URI escapes: %26amp; is a literal "&amp;" filename.
            var uri = attrs.href.replace(/&(amp|lt|gt|quot|apos);/g,
                (_, key) => ({ amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" })[key])
            if (!/^file:\/\/(?:localhost)?\//.test(uri)) continue
            var path
            try { path = decodeURIComponent(uri.replace(/^file:\/\/(?:localhost)?/, "")) }
            catch (e) { continue }
            if (seen.has(path)) continue
            seen.add(path)
            var item = entry(path, false)
            item.modified = attrs.modified
            out.push(item)
        }
        return out.sort((a, b) => a.modified < b.modified ? 1 : a.modified > b.modified ? -1 : 0)
    }

    FileView {
        path: root.home + "/.local/share/recently-used.xbel"
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.bookmarked = root.recentEntries(text())
            root.refreshRecent()
        }
    }

    // which recent files still exist, newest first, until there are enough
    function refreshRecent() {
        existing.running = false
        existing.command = ["sh", "-c",
            "n=0; for p; do [ -e \"$p\" ] || continue; printf '%s\\0' \"$p\"; n=$((n+1)); [ $n -ge " + root.maxResults + " ] && break; done",
            "sh"].concat(root.bookmarked.map(e => e.path))
        existing.running = true
    }

    Process {
        id: existing
        stdout: StdioCollector {
            onStreamFinished: {
                var there = ({})
                text.split("\0").forEach(p => there[p] = true)
                root.recent = root.bookmarked.filter(e => there[e.path]).slice(0, root.maxResults)
            }
        }
    }

    Timer {
        id: debounce
        interval: 140
        onTriggered: root.startSearch()
    }

    function rankResults(text, query) {
        var q = query.trim().toLowerCase()
        var rows = text.split("\0").filter(p => p !== "").map(p => {
            var isDir = p.endsWith("/")
            var item = entry(isDir ? p.slice(0, -1) : p, isDir)
            var name = item.name.toLowerCase()
            return { item: item,
                score: (name === q ? 0 : name.startsWith(q) ? 1 : 2)
                    + (item.path.slice(home.length).includes("/.") ? 4 : 0),
                depth: item.path.split("/").length }
        })
        rows.sort((a, b) => a.score - b.score || a.depth - b.depth
            || a.item.name.localeCompare(b.item.name))
        return rows.slice(0, maxResults).map(row => row.item)
    }

    Process {
        id: finder
        property bool awaitingOutput: false
        property string searchQuery: ""
        stdout: StdioCollector {
            onStreamFinished: root.finishSearch(text)
        }
        onRunningChanged: if (!running) root.startSearch()
    }
}
