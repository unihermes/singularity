// The launchable desktop entries, shared by the Control Centre's
// Applications page and the launcher (Launcher.qml).

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "AppSearch.js" as AppSearch

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

    // Rebuild only when desktop entries or usage change, not on each keystroke.
    readonly property var searchIndex: AppSearch.index(DesktopEntries.applications.values, hidden)
    readonly property var alphabeticalApps: AppSearch.order(searchIndex, null)
    readonly property var frequentApps: AppSearch.order(searchIndex, counts)
    readonly property var appsById: {
        var byId = Object.create(null)
        for (var row of searchIndex) byId[row.entry.id] = row.entry
        return byId
    }

    function list(query, alphabetical) {
        return AppSearch.search(alphabetical ? alphabeticalApps : frequentApps, query)
    }

    // --- pinned and grouped, for the launcher's Home and Start menu --------

    // desktop entry ids pinned in the launcher (Ctrl+P), in pin order. No
    // file yet: the twelve most launched stand in.
    property var pinnedIds: []
    property bool pinsSaved: false
    FileView {
        id: pinsFile
        path: Settings.stateDir + "/app-pins.json"
        preload: true
        printErrors: false
        onLoaded: {
            try { root.pinnedIds = JSON.parse(text()) || []; root.pinsSaved = true } catch (e) { root.pinnedIds = [] }
        }
    }
    readonly property var pinned: {
        if (!pinsSaved) return list("").slice(0, 12)
        return pinnedIds.map(id => appsById[id]).filter(e => !!e)
    }
    function isPinned(entry) { return pinned.indexOf(entry) !== -1 }
    function togglePin(entry) {
        var ids = pinned.map(e => e.id)
        var i = ids.indexOf(entry.id)
        if (i === -1) ids.push(entry.id)
        else ids.splice(i, 1)
        pinnedIds = ids
        pinsSaved = true
        pinsFile.setText(JSON.stringify(ids))
    }

    // put a pinned app at place `to` among the pinned ones
    function movePin(entry, to) {
        var ids = pinned.map(e => e.id)
        var from = ids.indexOf(entry.id)
        if (from === -1) return
        ids.splice(from, 1)
        ids.splice(Math.max(0, Math.min(ids.length, to)), 0, entry.id)
        pinnedIds = ids
        pinsSaved = true
        pinsFile.setText(JSON.stringify(ids))
    }

    // Pane's taskbar keeps pins of its own, apart from the launcher's: desktop
    // entry ids in taskbar order. None until one is pinned.
    readonly property bool taskbarOn: Settings.style === "pane"
    property var taskbarIds: []
    FileView {
        id: taskbarFile
        path: Settings.stateDir + "/taskbar-pins.json"
        preload: true
        printErrors: false
        onLoaded: {
            try { root.taskbarIds = JSON.parse(text()) || [] } catch (e) { root.taskbarIds = [] }
        }
    }
    readonly property var taskbarPinned: {
        return taskbarIds.map(id => appsById[id]).filter(e => !!e)
    }
    function isTaskbarPinned(entry) { return taskbarIds.indexOf(entry.id) !== -1 }
    function saveTaskbar(ids) {
        taskbarIds = ids
        taskbarFile.setText(JSON.stringify(ids))
    }
    function toggleTaskbarPin(entry) {
        var ids = taskbarIds.slice()
        var i = ids.indexOf(entry.id)
        if (i === -1) ids.push(entry.id)
        else ids.splice(i, 1)
        saveTaskbar(ids)
    }
    function moveTaskbarPin(entry, to) {
        var ids = taskbarIds.slice()
        var from = ids.indexOf(entry.id)
        if (from === -1) return
        ids.splice(from, 1)
        ids.splice(Math.max(0, Math.min(ids.length, to)), 0, entry.id)
        saveTaskbar(ids)
    }

    // the Start menu's groups, in its order: the first freedesktop main
    // category an entry has that maps to one, else "other"
    readonly property var groups: [
        { key: "internet", label: "Internet", cats: ["Network"] },
        { key: "dev", label: "Development", cats: ["Development"] },
        { key: "games", label: "Games", cats: ["Game"] },
        { key: "media", label: "Media", cats: ["AudioVideo", "Audio", "Video", "Graphics"] },
        { key: "office", label: "Office", cats: ["Office", "Education"] },
        { key: "system", label: "System", cats: ["System", "Settings", "Utility"] },
        { key: "other", label: "Other", cats: [] },
    ]
    function groupOf(entry) {
        var cats = Array.from(entry.categories || [])
        // a game is a game whatever else it lists
        if (cats.indexOf("Game") !== -1) return "games"
        for (var i = 0; i < groups.length; i++)
            if (groups[i].cats.some(c => cats.indexOf(c) !== -1)) return groups[i].key
        return "other"
    }

    // The pointer for what the shell starts, as env.lua sets it for
    // Hyprland: the shell's own environment is fixed at its launch, so a
    // theme picked since would otherwise miss X11 apps (Electron there
    // reads XCURSOR_* and GTK's settings.ini, which XDG_CONFIG_DIRS finds).
    readonly property string xdgDir: Settings.stateDir + "/xdg"
    readonly property var cursorEnv: ({
        XCURSOR_THEME: Settings.cursorTheme,
        XCURSOR_SIZE: String(Settings.cursorSize),
        HYPRCURSOR_THEME: Settings.cursorTheme,
        HYPRCURSOR_SIZE: String(Settings.cursorSize),
        XDG_CONFIG_DIRS: [xdgDir].concat((Quickshell.env("XDG_CONFIG_DIRS") || "/etc/xdg")
            .split(":").filter(d => d !== "" && d !== xdgDir)).join(":"),
    })

    // a desktop entry's command, in cursorEnv
    function run(entry) {
        Quickshell.execDetached({
            command: entry.command,
            workingDirectory: entry.workingDirectory,
            environment: cursorEnv,
        })
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
            Quickshell.execDetached({ command: cmd, environment: cursorEnv })
        } else
            run(entry)
    }

    // Equicord uses Discord's icon throughout the shell.
    function iconPath(name, allowMissing) {
        var icon = /^equicord$/i.test(String(name)) ? "discord" : name
        return Quickshell.iconPath(icon, allowMissing)
    }

    // The icon for a window class: via desktop entries (heuristicLookup),
    // then the class as an icon name, then its last segment lowercased. A
    // Steam game (steam_app_ID) takes the steam_icon_ID Steam installs with
    // its shortcut, and a knownApp its own icon. The shell's own windows get
    // none; they draw a glyph. The scratchpad terminal (SCRATCH_CLASS) takes
    // the terminal app's icon.
    function iconForClass(cls) {
        if (!cls || String(cls) === "org.quickshell") return ""
        var c = byClass(cls)
        if (c.icon === undefined) {
            var known = knownApp(cls)
            var scratch = String(cls) === "singularity.scratch"
            if (scratch) c.entry = terminalEntry()
            var steamApp = String(cls).match(/^steam_app_(\d+)$/)
            var path = steamApp ? root.iconPath("steam_icon_" + steamApp[1], true) : ""
            // one installed after the shell started isn't in Qt's icon cache:
            // Steam always writes a 256px copy
            if (path === "" && steamApp)
                path = "file://" + Quickshell.env("HOME") + "/.local/share/icons/hicolor/256x256/apps/steam_icon_"
                    + steamApp[1] + ".png"
            if (path === "" && known) path = root.iconPath(known.icon, true)
            if (path === "" && c.entry && c.entry.icon) path = root.iconPath(c.entry.icon, true)
            if (path === "" && !scratch) path = root.iconPath(cls, true)
            if (path === "" && !scratch) path = root.iconPath(cls.replace(/^.*\./, "").toLowerCase(), true)
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
    property var classCache: Object.create(null)
    function byClass(cls) {
        var cache = classCache
        if (!cache[cls]) cache[cls] = { entry: DesktopEntries.heuristicLookup(cls) }
        return cache[cls]
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.classCache = Object.create(null) }
    }
    Connections {
        target: Settings
        function onIconThemeChanged() { root.classCache = Object.create(null) }
        function onTerminalAppChanged() { root.classCache = Object.create(null) }
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

    // apps whose class has no desktop entry and carries a version: Minecraft's
    // is "Minecraft 26.1.2", with a * after Minecraft when modded
    function knownApp(cls) {
        if (/^Minecraft\*? \d/.test(String(cls))) return { name: "Minecraft", icon: "minecraft" }
        return null
    }

    function displayName(entry) { return AppSearch.displayName(entry && entry.name) }

    // a short app name: a knownApp's, the desktop entry's, else the class's
    // last segment; the shell's windows go by title
    function nameForWindow(cls, title) {
        if (String(cls) === "org.quickshell") return String(title || "Singularity")
        var known = knownApp(cls)
        if (known) return known.name
        var entry = cls ? byClass(cls).entry : null
        if (entry && entry.name) return displayName(entry)
        var bare = String(cls || "").replace(/^.*\./, "")
        return bare.charAt(0).toUpperCase() + bare.slice(1)
    }
}
