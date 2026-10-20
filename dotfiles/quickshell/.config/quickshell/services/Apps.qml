// Singularity - Quickshell
// ~/.config/quickshell/services/Apps.qml
//
// The launchable desktop entries, shared by the Control Centre's
// Applications page and the launcher (Launcher.qml).

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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

    // desktop entry ids kept out of the list (dependency-installed system
    // tools), by id so a renamed Name= can't bring one back
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

    // Every launchable entry, most launched first then A-Z (or A-Z with
    // `alphabetical`), case-insensitive. With a query, prefix matches first;
    // genericName is searched too.
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

        // So the window gets its app's window rule even with another of the
        // app's windows open (windows.lua's markLaunch).
        Quickshell.execDetached(["hyprctl", "eval", "markLaunch()"])

        // a terminal app is wrapped, or it starts with nothing to draw in
        if (entry.runInTerminal) {
            // command is a Qt list, not a JS array: concat() would
            // push it as one nested element instead of spreading it
            var cmd = [Settings.terminal, "-e"]
            for (var i = 0; i < entry.command.length; i++) cmd.push(entry.command[i])
            Quickshell.execDetached(cmd)
        } else
            entry.execute()
    }

    // The icon for a window class: via desktop entries (heuristicLookup),
    // then the class as an icon name, then its last segment lowercased. The
    // shell's own windows get none; they draw a glyph. The scratchpad
    // terminal (SCRATCH_CLASS) takes the terminal app's icon.
    function iconForClass(cls) {
        if (!cls || String(cls) === "org.quickshell") return ""
        var c = byClass(cls)
        if (c.icon === undefined) {
            var scratch = String(cls) === "singularity.scratch"
            if (scratch) c.entry = terminalEntry()
            var path = c.entry && c.entry.icon ? Quickshell.iconPath(c.entry.icon, true) : ""
            if (path === "" && !scratch) path = Quickshell.iconPath(cls, true)
            if (path === "" && !scratch) path = Quickshell.iconPath(cls.replace(/^.*\./, "").toLowerCase(), true)
            c.icon = path
        }
        return c.icon
    }

    // The desktop entry whose command runs Settings.terminalApp; its id
    // needn't be the command's name (Ghostty's is com.mitchellh.ghostty).
    function terminalEntry() {
        var all = DesktopEntries.applications.values
        for (var i = 0; i < all.length; i++) {
            var cmd = all[i].command
            if (cmd && cmd.length > 0 && String(cmd[0]).replace(/^.*\//, "") === Settings.terminalApp)
                return all[i]
        }
        return null
    }

    // class -> { entry, icon }, cached (heuristicLookup walks every entry);
    // cleared when the entries, icon theme or terminal app change
    property var classCache: ({})
    function byClass(cls) {
        var cache = classCache
        if (!cache[cls]) cache[cls] = { entry: DesktopEntries.heuristicLookup(cls) }
        return cache[cls]
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.classCache = {} }
    }
    Connections {
        target: Settings
        function onIconThemeChanged() { root.classCache = {} }
        function onTerminalAppChanged() { root.classCache = {} }
    }

    // The shell's own windows (one shared class): listed in the strip and
    // ALT+Tab, but left out of the workspace views, occupancy and tray matching.
    function isShellWindow(tl) {
        return !!(tl.lastIpcObject && tl.lastIpcObject.class === "org.quickshell")
    }

    // glyphs for the shell's own windows, and a window outline for any
    // other window with no icon
    readonly property var shellGlyphs: ({
        keybinds: "󰌌", notes: "󰎚", settings: "󰒓", system: "󰨇",
    })

    function glyphForWindow(cls, title) {
        if (String(cls) === "org.quickshell")
            return shellGlyphs[String(title || "").toLowerCase()] || "󰖯"
        return "󰖯"
    }

    // a tab behind the most recently focused one in its group (windows.lua's
    // TABS), so lists show each group once; `ipc`/`ipcs` as hyprctl clients -j
    function isBackTab(ipc, ipcs) {
        if (!ipc || !ipc.grouped || ipc.grouped.length < 2) return false
        for (const o of ipcs) {
            if (o && o.address !== ipc.address && ipc.grouped.indexOf(o.address) !== -1
                    && o.focusHistoryID < ipc.focusHistoryID)
                return true
        }
        return false
    }
    function isBackTabToplevel(tl) {
        var ipc = tl.lastIpcObject
        // most windows aren't tabs: skip gathering every window for them
        if (!ipc || !ipc.grouped || ipc.grouped.length < 2) return false
        return isBackTab(ipc, Hyprland.toplevels.values.map(t => t.lastIpcObject))
    }

    // a short app name: the desktop entry's, else the class's last segment;
    // the shell's windows go by title
    function nameForWindow(cls, title) {
        if (String(cls) === "org.quickshell") return String(title || "Singularity")
        var entry = cls ? byClass(cls).entry : null
        if (entry && entry.name) return entry.name
        var bare = String(cls || "").replace(/^.*\./, "")
        return bare.charAt(0).toUpperCase() + bare.slice(1)
    }
}
