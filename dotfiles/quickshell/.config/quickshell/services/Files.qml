// Singularity - Quickshell
// ~/.config/quickshell/services/Files.qml
//
// The launcher's file-search mode: names under $HOME, from fd.
//
// fd rather than a QML directory walk: the walk would have to run on the UI
// thread and would stall the launcher on the first deep directory. fd is
// already in packages/pacman.txt; with it missing the process simply fails
// and the list stays empty.
//
// Queries are passed as a fixed string (--fixed-strings), not a regex: what
// people type into a search box is a name, and a stray ( or [ would
// otherwise be a syntax error instead of a search.
//
// --hidden is on, because half of what's worth finding on this machine is
// under ~/.config, but that also opens up the application data dumps --
// .steam alone answers "calendar" six times before anything of yours does.
// Hence EXCLUDES, and hence fetching far more matches than are shown and
// ranking them here: fd walks in directory order and stops at
// --max-results, so a low cap fills the list with whatever sorts first
// alphabetically rather than whatever is most likely meant.
//
// Results are capped and the search is debounced, so holding a key down
// doesn't queue a process per keystroke.
//
// With nothing typed the list shows recent files instead of nothing. That
// comes from ~/.local/share/recently-used.xbel, the XDG recent-files list
// every GTK app (Thunar included) already writes -- no new log of our own to
// keep, and it matches what those apps' own "Recent" lists show.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // [{ name, path, dir, isDir }]
    property var results: []
    // the same shape, from recently-used.xbel, newest first
    property var recent: []
    property bool searching: false
    property string query: ""
    readonly property bool available: true

    readonly property string home: Quickshell.env("HOME")
    // shown, and asked of fd: the gap is what makes ranking possible
    readonly property int maxResults: 60
    readonly property int fetchLimit: 400

    // Directories that are never what a name search meant: caches, version
    // control internals, language package stores and the application data
    // dumps that would otherwise answer every common word first.
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

    // Not xdg-open directly: half of what a file search turns up here has
    // either no handler at all (text/markdown, shell scripts) or one that
    // needs a terminal (text/plain -> nvim), and in both cases xdg-open
    // exits 0 having done nothing -- Enter looked broken. The script sorts
    // that out; see its own comment.
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

    // The .xbel is XML, but only two attributes of each bookmark matter and
    // QML has no XML parser worth pulling in for that, so it's read with a
    // regex over the bookmark tags.
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
            root.recent = out.slice(0, root.maxResults)
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
            }, [])).concat([root.query.trim(), root.home])
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
                // Rank rather than take fd's order: a name that starts with
                // what was typed first, then anything not buried in a dot
                // directory, then the shallowest path. ~/Documents/report.md
                // beats ~/.claude/.../generate_report.py, which is the whole
                // point of fetching more than are shown.
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
