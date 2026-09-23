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
        path: Quickshell.statePath("app-usage.json")
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

    // Every launchable desktop entry, most launched first, ties A-Z.
    // Case-insensitive, or lowercase names ("htop", "nvim") would all
    // sort after Z.
    //
    // With a query, names that *start* with it come first, then any
    // other match, each group in the same order. genericName is searched
    // too, so "browser" finds Zen and Floorp.
    function list(query) {
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
        var byUse = (a, b) => (c[b.id] || 0) - (c[a.id] || 0)
            || a.name.toLowerCase().localeCompare(b.name.toLowerCase())
        starts.sort(byUse)
        rest.sort(byUse)
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
    // heuristicLookup() alone isn't enough. It goes through the desktop
    // entries, and an entry marked NoDisplay=true isn't among them -- which
    // is exactly the case for org.quickshell.desktop, so the shell's own
    // windows (Settings, System, Keybinds) came out iconless. The class is
    // tried as an icon name of its own after that, which is where
    // org.quickshell.svg in hicolor gets found, and then the bare last
    // segment of it, lowercased, for apps whose class is reverse-DNS but
    // whose icon isn't.
    function iconForClass(cls) {
        if (!cls) return ""
        var entry = DesktopEntries.heuristicLookup(cls)
        var path = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
        if (path === "") path = Quickshell.iconPath(cls, true)
        if (path === "") path = Quickshell.iconPath(cls.replace(/^.*\./, "").toLowerCase(), true)
        return path
    }

    // When no icon file can be found, something still has to be drawn: an
    // IconImage with an empty source is a hole in the row. The shell's own
    // windows are that case -- org.quickshell.desktop is NoDisplay, so it
    // isn't among the desktop entries, and its themed icon doesn't resolve
    // either -- and they get a glyph for what the window actually is, so
    // Settings, System and Keybinds are told apart at a glance. Anything
    // else falls back to a plain window outline.
    readonly property var shellGlyphs: ({
        keybinds: "󰌌", settings: "󰒓", system: "󰨇",
    })

    function glyphForWindow(cls, title) {
        if (String(cls) === "org.quickshell")
            return shellGlyphs[String(title || "").toLowerCase()] || "󰖯"
        return "󰖯"
    }
}
