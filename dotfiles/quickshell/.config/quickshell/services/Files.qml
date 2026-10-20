// Singularity - Quickshell
// ~/.config/quickshell/services/Files.qml
//
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
    readonly property bool available: true

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
        if (q.trim() === "") {
            results = []
            searching = false
            debounce.stop()
            finder.running = false
            return
        }
        searching = true
        debounce.restart()
    }

    function clear() {
        query = ""
        results = []
        searching = false
        debounce.stop()
        finder.running = false
    }

    // ~/Documents/report.pdf -> "~/Documents", for the second line of a row
    function pretty(path) {
        return path.indexOf(root.home) === 0 ? "~" + path.slice(root.home.length) : path
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

    // the .xbel read with a regex (two attributes matter)
    FileView {
        id: recentFile
        path: root.home + "/.local/share/recently-used.xbel"
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var out = [], seen = ({})
            var re = /<bookmark[^>]*\shref="([^"]+)"[^>]*\smodified="([^"]*)"/g
            var m
            while ((m = re.exec(text())) !== null) {
                if (m[1].indexOf("file://") !== 0) continue
                var p
                try { p = decodeURIComponent(m[1].slice(7)) } catch (e) { continue }
                // it's XML: a & in a file name is stored as &amp;
                p = p.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                     .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
                if (seen[p]) continue
                seen[p] = true
                var e2 = root.entry(p, false)
                e2.modified = m[2]
                out.push(e2)
            }
            out.sort(function (a, b) { return a.modified < b.modified ? 1 : -1 })
            root.bookmarked = out
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
        onTriggered: {
            // a search already running is killed rather than queued: its
            // results are for a query the user has moved on from
            finder.running = false
            finder.command = [
                "fd", "--hidden", "--fixed-strings", "--ignore-case", "--follow",
                "--max-results", String(root.fetchLimit),
            ].concat(root.excludes.reduce(function (acc, e) {
                return acc.concat(["--exclude", e])
            // "--" so a query starting with a dash isn't read as an option
            }, [])).concat(["--", root.query.trim(), root.home])
            finder.running = true
        }
    }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i]
                    if (p === "") continue
                    var isDir = p.charAt(p.length - 1) === "/"
                    if (isDir) p = p.slice(0, -1)
                    out.push(root.entry(p, isDir))
                }
                // ranked: prefix matches, then outside dot directories, then
                // shallowest
                var q = root.query.trim().toLowerCase()
                function score(f) {
                    var n = f.name.toLowerCase()
                    var s = n === q ? 0 : n.indexOf(q) === 0 ? 1 : 2
                    if (f.path.slice(root.home.length).indexOf("/.") !== -1) s += 4
                    return s
                }
                out.sort(function (a, b) {
                    var sa = score(a), sb = score(b)
                    if (sa !== sb) return sa - sb
                    var da = a.path.split("/").length, db = b.path.split("/").length
                    if (da !== db) return da - db
                    return a.name.localeCompare(b.name)
                })
                root.results = out.slice(0, root.maxResults)
            }
        }
        onExited: root.searching = false
    }
}
