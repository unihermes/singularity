// Singularity - Quickshell
// ~/.config/quickshell/services/Apps.qml
//
// The launchable desktop entries, shared by the Control Centre's
// Applications page and the launcher (Launcher.qml).

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // { desktop entry id: launch count }, for most-used-first ordering.
    // One small JSON file, rewritten once per launch.
    property var counts: ({})

    FileView {
        id: usageFile
        path: Settings.stateDir + "/app-usage.json"
        preload: true
        // no file until the first launch
        printErrors: false
        onLoaded: {
            try { root.counts = JSON.parse(text()) || {} } catch (e) { root.counts = {} }
        }
    }

    // Desktop entry ids kept out of the list: system tools that
    // arrived as dependencies of something else and aren't ever
    // launched by hand. Ids rather than names, so a translation or a
    // package renaming its Name= line doesn't let one back in.
    readonly property var hidden: [
        "avahi-discover", "bssh", "bvnc",   // avahi
        "lstopo",                           // hwloc
        "qv4l2", "qvidcap",                 // v4l-utils
        "xfce4-about",                      // xfce4-about
        "jconsole-java25-openjdk",          // jdk
        "jshell-java25-openjdk",
        "thunar-settings",                  // thunar extras
        "thunar-volman-settings",
        "thunar-bulk-rename",
    ]

    // Every launchable desktop entry, most launched first, ties A-Z, or
    // purely A-Z with `alphabetical`. Case-insensitive, or lowercase names ("htop", "nvim") would all
    // sort after Z.
    //
    // With a query, names that *start* with it come first, then any
    // other match, each group in the same order. genericName is searched
    // too, so "browser" finds Zen and Floorp.
    function list(query, alphabetical) {
        var all = DesktopEntries.applications.values
        var q = (query || "").trim().toLowerCase()
        var starts = [], rest = []
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            if (e.noDisplay || hidden.indexOf(e.id) !== -1) continue
            var name = e.name.toLowerCase()
            if (q === "") { rest.push(e); continue }
            if (name.startsWith(q)) starts.push(e)
            else if (name.indexOf(q) !== -1
                || (e.genericName || "").toLowerCase().indexOf(q) !== -1) rest.push(e)
        }
        var c = counts
        var byName = (a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase())
        var order = alphabetical ? byName
            : (a, b) => (c[b.id] || 0) - (c[a.id] || 0) || byName(a, b)
        starts.sort(order)
        rest.sort(order)
        return starts.concat(rest)
    }

    function launch(entry) {
        var next = Object.assign({}, counts)
        next[entry.id] = (next[entry.id] || 0) + 1
        counts = next
        usageFile.setText(JSON.stringify(next))

        // execute() runs the Exec line as-is, which for a terminal
        // app (htop, nvim) means a process with no terminal to draw
        // in -- it starts and dies unseen. Those get wrapped.
        if (entry.runInTerminal) {
            // command is a Qt list, not a JS array: concat() would
            // push it as one nested element instead of spreading it
            var cmd = ["alacritty", "-e"]
            for (var i = 0; i < entry.command.length; i++) cmd.push(entry.command[i])
            Quickshell.execDetached(cmd)
        } else
            entry.execute()
    }

    // The icon for an open window's class, for everything that lists
    // windows: the bar's window strip, ALT+Tab, the workspace overlay.
    //
    // heuristicLookup() goes through the desktop entries, which leave out
    // NoDisplay=true ones, so the class is also tried as an icon name of its
    // own, then its bare last segment lowercased, for apps whose class is
    // reverse-DNS but whose icon isn't. The shell's own windows get no icon
    // here: they all share org.quickshell's, and draw their glyph instead.
    function iconForClass(cls) {
        if (!cls || String(cls) === "org.quickshell") return ""
        var entry = DesktopEntries.heuristicLookup(cls)
        var path = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
        if (path === "") path = Quickshell.iconPath(cls, true)
        if (path === "") path = Quickshell.iconPath(cls.replace(/^.*\./, "").toLowerCase(), true)
        return path
    }

    // When no icon file can be found, something still has to be drawn: an
    // IconImage with an empty source is a hole in the row. The shell's own
    // windows always take this path, with a glyph for what the window
    // actually is, so Settings, System, Keybinds and Notes are told apart at a
    // glance. Anything else falls back to a plain window outline.
    readonly property var shellGlyphs: ({
        keybinds: "󰌌", notes: "󰎚", settings: "󰒓", system: "󰨇",
    })

    function glyphForWindow(cls, title) {
        if (String(cls) === "org.quickshell")
            return shellGlyphs[String(title || "").toLowerCase()] || "󰖯"
        return "󰖯"
    }

    // A short name for an open window's app: its desktop entry's name, else
    // the class's bare last segment. The shell's own windows go by their
    // title (Settings, System…), since they all share one class.
    function nameForWindow(cls, title) {
        if (String(cls) === "org.quickshell") return String(title || "Singularity")
        var entry = cls ? DesktopEntries.heuristicLookup(cls) : null
        if (entry && entry.name) return entry.name
        var bare = String(cls || "").replace(/^.*\./, "")
        return bare.charAt(0).toUpperCase() + bare.slice(1)
    }
}
