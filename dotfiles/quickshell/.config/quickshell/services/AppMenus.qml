// The menu bar's application menus (File, Edit, View…) for the focused
// window. An app that exports its own menu bar over D-Bus gets that, read by
// scripts/appmenu.py, which is also the menu registrar these apps look for.
// Under Hyprland only XWayland apps export one (Qt, Electron, GTK3 with
// appmenu-gtk-module), and only if they started after the registrar.
// Every other app gets the menus in AppMenuTables.js, which send it its own
// shortcuts. The shell's Window menu comes after either.
//
// An item has id, label, enabled, separator, toggle ("", "check" or
// "radio"), checked, shortcut and children (its items for a submenu, else
// null), plus keys (AppMenuTables.js) or run (a Hyprland dispatch, the Window menu).

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "AppMenuTables.js" as AppMenuTables

Singleton {
    id: root

    readonly property bool running: proc.running

    // [{ win, service, path, pid, at }]: every exported menu bar
    property var exported: []

    readonly property var focused: Hyprland.activeToplevel
    readonly property var info: focused ? focused.lastIpcObject : null
    readonly property string address: focused ? "0x" + focused.address : ""
    // the focused window's exported menu, the newest its process registered
    readonly property var source: {
        if (!info || !info.pid) return null
        var own = exported.filter(m => m.pid === info.pid)
        own.sort((a, b) => b.at - a.at)
        return own.length > 0 ? own[0] : null
    }
    onSourceChanged: {
        layout = []
        if (source) send({ cmd: "watch", service: source.service, path: source.path })
        else send({ cmd: "unwatch" })
    }
    // the exported menu's items, [] until read
    property var layout: []

    // true while the menus are the app's own
    readonly property bool exportedMenus: layout.length > 0
    readonly property var appMenus: exportedMenus ? layout
        : info && info.class ? AppMenuTables.forClass(info.class) : []

    // the bar's menus: the app's, then Window, before the app's Help when it has one
    readonly property var menus: {
        if (!info || !info.class) return []
        var list = appMenus.filter(m => m.children && m.children.length > 0)
        var help = list.length > 0 && /^help$/i.test(list[list.length - 1].label) ? list.pop() : null
        list.push(windowMenu)
        if (help) list.push(help)
        return list
    }

    function win() { return "address:" + address }
    readonly property var windowMenu: {
        var i = info || {}
        var w = JSON.stringify(win())
        var wsItems = []
        for (var n = 1; n <= Settings.workspaceCount; n++)
            wsItems.push(item(-100 - n, "Workspace " + n, {
                toggle: "radio", checked: !!i.workspace && i.workspace.id === n,
                run: "hl.dsp.window.move({ workspace = " + n + ", window = " + w + ", follow = false })" }))
        // the binds' own functions act on the focused window, so it's focused first
        function focusThen(fn) {
            return "function() hl.dispatch(hl.dsp.focus({ window = " + w + " })); " + fn + "() end"
        }
        return item(-1, "Window", { children: [
            item(-2, "Minimize", { run: focusThen("toggleMinimize") }),
            item(-3, "Maximize", { run: focusThen("toggleMaximize") }),
            item(-4, "Full screen", { toggle: "check", checked: !!i.fullscreen,
                run: "hl.dsp.window.fullscreen({ window = " + w + " })" }),
            item(-5, "", { separator: true }),
            item(-6, "Float", { toggle: "check", checked: !!i.floating,
                run: "hl.dsp.window.float({ action = \"toggle\", window = " + w + " })" }),
            // only floating windows pin
            i.floating ? item(-7, "Pin on every workspace", { toggle: "check", checked: !!i.pinned,
                run: "hl.dsp.window.pin({ window = " + w + " })" }) : null,
            item(-8, "Move to", { children: wsItems }),
            Quickshell.screens.length > 1 ? item(-9, "Move to the next display", { run: focusThen("sendToNextMonitor") }) : null,
            item(-10, "Stash in the scratchpad", { run: focusThen("toggleStashed") }),
            item(-11, "", { separator: true }),
            item(-12, "Close window", { run: "hl.dsp.window.close({ window = " + w + " })" }),
        ].filter(it => it !== null) })
    }
    function item(id, label, extra) {
        return Object.assign({ id: id, label: label, enabled: true, separator: false,
                               toggle: "", checked: false, shortcut: "", children: null }, extra)
    }

    // the window's floating/fullscreen/pinned state is read again as a menu opens
    function refresh() { Hyprland.refreshToplevels() }

    // a submenu opening and closing, for apps that fill theirs as it opens
    function opened(it) { if (exportedMenus && it.id >= 0) send({ cmd: "open", id: it.id }) }
    function closed(it) { if (exportedMenus && it.id >= 0) send({ cmd: "close", id: it.id }) }

    // Runs an entry a beat after its menu closes, so the app has the
    // keyboard back for a shortcut.
    function activate(it) {
        pendingItem = it
        pendingWindow = win()
        activateTimer.start()
    }
    property var pendingItem: null
    Timer {
        id: activateTimer
        interval: 120
        onTriggered: {
            var it = root.pendingItem
            root.pendingItem = null
            if (!it) return
            if (it.run) Hyprland.dispatch(it.run)
            else if (it.keys) root.sendKeys(AppMenuTables.keySteps(it.keys))
            else if (root.exportedMenus) root.send({ cmd: "click", id: it.id })
        }
    }

    // a chord's steps go a beat apart
    property var pendingSteps: []
    property string pendingWindow: ""
    function sendKeys(steps) {
        pendingSteps = steps
        stepTimer.triggered()
    }
    Timer {
        id: stepTimer
        interval: 60
        onTriggered: {
            if (root.pendingSteps.length === 0) return
            var s = root.pendingSteps[0]
            root.pendingSteps = root.pendingSteps.slice(1)
            Hyprland.dispatch("hl.dsp.send_shortcut({ mods = " + JSON.stringify(s.mods) + ", key = "
                + JSON.stringify(s.key) + ", window = " + JSON.stringify(root.pendingWindow) + " })")
            if (root.pendingSteps.length > 0) start()
        }
    }

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }

    Process {
        id: proc
        running: Settings.widgetVisible("appmenu")
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/appmenu.py"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                var m
                try { m = JSON.parse(line) } catch (e) { return }
                if (m.event === "menus") root.exported = m.menus
                else if (m.event === "layout" && root.source
                         && m.service === root.source.service && m.path === root.source.path)
                    root.layout = m.items.filter(it => !it.separator)
            }
        }
        onRunningChanged: {
            if (!running) { root.exported = []; root.layout = [] }
            else if (root.source) root.send({ cmd: "watch", service: root.source.service, path: root.source.path })
        }
    }
}
