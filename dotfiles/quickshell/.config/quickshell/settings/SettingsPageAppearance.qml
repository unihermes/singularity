// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAppearance.qml
//
// Appearance, in tabs, from the broadest choice to the finest:
//   Look       every look as a card; the wallpaper and how often a new one
//              comes; what's been changed from the look in use, each with
//              its way back; the saved default
//   Colours    the palette and the accents
//   Style      the style, its shape dials, the shell's font and size, and
//              the Finish switches
//   Bar        its layout, then its modules, workspaces, windows and clock
//   Panels     flyouts, the launcher, notifications and the overlays
//   Windows    how Hyprland draws windows
//   System     motion, and the fonts, icons and cursor of other apps
// Colours, Style, Bar and Panels open on a preview of the setup as it is.
//
// A look (LookStore) is a starting point: picking one sets everything it
// carries, which can then be adjusted one by one. A field holding such a
// setting is marked while it differs from the look, and the mark puts it
// back; the Look tab lists every such change. Every look but the fallback
// can be removed from its card, which deletes it from looks.json.
//
// Two stores behind it. The shell's own look is Settings.qml, the same
// values the Control Centre edits, so the two always agree and a change
// here applies the moment it's made. The Windows tab is the `general` and
// `decoration` tables in looks.lua; its changes go to the state
// directory's hyprland.json, as the Input page's do, then a reload.
//
// Each tab is its own file in appearance/, as are the pieces they share;
// this file keeps what they all reach through `page`.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services/HyprTables.js" as HyprTables
import "../services/Looks.js" as Looks
import "../services"
import "../flyouts"
import "appearance"

SettingsPage {
    id: page

    sectioned: true
    // a small bar and flyout, drawn by the shell's own pieces, above the
    // tabs whose settings change how they look
    pinned: LivePreview {}
    pinnedVisible: ["colours", "style", "bar", "panels"].indexOf(tab) !== -1

    title: "Appearance"
    description: "Pick a look, then change anything about it. Changes apply as you make them; a dot marks a setting that differs from the look."

    tabs: [
        { id: "look",      label: "Look",      icon: "󰏘" },
        { id: "colours",   label: "Colours",   icon: "󰌁" },
        { id: "style",     label: "Style",     icon: "󰆧" },
        { id: "bar",       label: "Bar",       icon: "󰕰" },
        { id: "panels",    label: "Panels",    icon: "󰕮" },
        { id: "windows",   label: "Windows",   icon: "󰖲" },
        { id: "system",    label: "System",    icon: "󰒓" },
    ]
    stickyColumn: ({ look: tab_look, colours: tab_colours, style: tab_style,
                     bar: tab_bar, panels: tab_panels, windows: tab_windows,
                     system: tab_system })[tab] || tab_look

    function label(v, key) { return Settings.choiceLabel(v, key) }

    // the field a control sits in, marked as holding `key` when a look
    // carries it
    function markField(control, key) {
        var f = control.parent ? control.parent.parent : null
        if (f && f.isSettingsField === true && f.lookKey === "" && Looks.looks[Looks.fallback].settings[key] !== undefined)
            f.lookKey = key
    }

    // on the page rather than the card: the reload after the write destroys
    // the removed look's card before the result comes back
    function removeLook(name) { Settings.removeLook(name, (ok, msg) => say(msg, !ok)) }

    // --- the Look tab's changes ----------------------------------------------

    // What each setting a look carries is called on this page, for the list
    // of changes; the same as its field's label, so "Show" can find it
    readonly property var keyLabels: ({
        style: "Style", radius: "Roundness", barStyle: "Bar shape", edgeGap: "Gaps at screen edges",
        focusedOpacity: "Focused opacity", unfocusedOpacity: "Unfocused opacity",
        terminalOpacity: "Terminal opacity", density: "Density",
        seeThrough: "See-through", scrim: "Overlay dimming", barSeparator: "Separators",
        shadows: "Shadows", gradient: "Shaded grounds", heavyLines: "Heavy lines",
        headingUpper: "Capital headings", headingRule: "Heading rule",
        fontFamily: "Font", barPosition: "Position", workspaceStyle: "Workspaces",
        clockStyle: "Clock", windowStyle: "Open windows", windowScope: "Windows shown",
        iconTint: "App icons", vizStyle: "Visualizer", flyoutAnim: "Flyouts open",
        launcherLayout: "Launcher layout", launcherPosition: "Launcher position",
        launcherDetails: "Launcher details", notifStyle: "Notification popups",
        altTabStyle: "Window switcher", overviewLayout: "Workspace overview",
        overviewBackdrop: "Overview backdrop", powerStyle: "Power menu", levelStyle: "Level popup",
        accent: "Accent", levelColour: "Level colour",
    })
    readonly property var keyUnits: ({ radius: "px", edgeGap: "px", seeThrough: "%", scrim: "%",
                                         focusedOpacity: "%", unfocusedOpacity: "%", terminalOpacity: "%" })
    function valueText(k, v) {
        if (typeof v === "boolean") return v ? "on" : "off"
        if (typeof v === "number") return v + (keyUnits[k] || "")
        if (v === "") return "none"
        return page.label(v, k)
    }

    LookTab { id: tab_look; page: page }

    ColoursTab { id: tab_colours; page: page }

    StyleTab { id: tab_style; page: page }

    BarTab { id: tab_bar; page: page }

    PanelsTab { id: tab_panels; page: page }

    WindowsTab { id: tab_windows; page: page }

    SystemTab { id: tab_system; page: page }

    // --- windows: looks.lua, and hyprland.json over it ------------------------

    // { "general": {key: {editable, value}}, "decoration.blur": ... }, a
    // table being null when the file doesn't have it
    property var conf: ({})
    readonly property var tablePaths: [["general"], ["decoration"], ["decoration", "blur"]]

    // Hyprland's own defaults, for keys the file leaves out
    readonly property var hyprDefaults: ({
        "general.gaps_in": 5,
        "decoration.dim_inactive": false, "decoration.blur.enabled": true,
        "decoration.dim_strength": 0.5, "decoration.blur.size": 8, "decoration.blur.passes": 1,
    })

    readonly property bool blurOn: hyprField(["decoration", "blur"], "enabled").value === true

    function hyprField(path, key) {
        var o = HyprLuaWrite.override(path, key)
        if (o !== undefined) return { editable: true, value: o }
        var t = conf[path.join(".")]
        if (!t) return { editable: false, value: hyprDefaults[path.join(".") + "." + key] }
        var f = t[key]
        return f === undefined ? { editable: true, value: hyprDefaults[path.join(".") + "." + key], unset: true } : f
    }

    function reread() {
        luaFile.reload()
        luaFile.waitForJob()
        var src = luaFile.text()
        var out = {}
        tablePaths.forEach(p => out[p.join(".")] = src === "" ? null : HyprTables.readConfig(src, p))
        conf = out
        if (src === "") say("Couldn't read " + HyprLuaWrite.looksPath, true)
    }

    function setHypr(path, key, v, message) {
        HyprLuaWrite.setLocal([[path, key, v]], message, (ok, msg) => page.say(msg, !ok))
    }

    Component.onCompleted: {
        reread()
        // picks up fonts and themes installed since the shell started
        Fonts.refresh()
        DesktopThemes.refresh()
    }

    FileView {
        id: luaFile
        path: HyprLuaWrite.looksPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: if (!HyprLuaWrite.busy) page.reread()
    }

}
