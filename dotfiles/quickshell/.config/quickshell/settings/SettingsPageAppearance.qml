// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAppearance.qml
//
// Appearance, in tabs, one per part of the screen:
//   Theme      the style, its shape and finish, the colours, spacing, the
//              shell's font and headings -- what restyles everything at once
//   Bar        its arrangement, shape and size, then each module
//   Panels     flyouts, the launcher, notifications and the overlays
//   Desktop    the wallpaper, how Hyprland draws windows, and motion
//   Apps       the fonts, icons and cursor of other apps
// Every tab opens on a preview of what it changes, under a strip counting
// the changes from the baseline (ChangesBar), with Save as default and
// Reset beside it.
//
// The look (Looks.js) is the starting point: everything it carries can be
// adjusted one by one. A field holding such a setting is marked while it
// differs from the baseline, and the mark puts it back.
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
    banner: ChangesBar {}
    pinned: LivePreview { kind: ({ bar: "bar", panels: "launcher", desktop: "windows" })[page.tab] || "flyout" }

    title: "Appearance"
    description: "Changes apply as you make them; a dot marks a setting that differs from the baseline."

    tabs: [
        { id: "theme",   label: "Theme",   icon: "󰏘" },
        { id: "bar",     label: "Bar",     icon: "󰕰" },
        { id: "panels",  label: "Panels",  icon: "󰕮" },
        { id: "desktop", label: "Desktop", icon: "󰖲" },
        { id: "apps",    label: "Apps",    icon: "󰀻" },
    ]
    stickyColumn: ({ theme: tab_theme, bar: tab_bar, panels: tab_panels,
                     desktop: tab_desktop, apps: tab_apps })[tab] || tab_theme

    function label(v, key) { return Settings.choiceLabel(v, key) }

    // the field a control sits in, marked as holding `key` when a look
    // carries it
    function markField(control, key) {
        var f = control.parent ? control.parent.parent : null
        if (f && f.isSettingsField === true && f.lookKey === "" && Looks.looks[Looks.fallback].settings[key] !== undefined)
            f.lookKey = key
    }

    // --- the list of changes (ChangesBar) -------------------------------------

    // What each setting a look carries is called on this page, for the list
    // of changes; the same as its field's label, so "Show" can find it
    readonly property var keyLabels: ({
        style: "Style", radius: "Roundness", barStyle: "Bar shape", edgeGap: "Gaps at screen edges",
        focusedOpacity: "Focused opacity", unfocusedOpacity: "Unfocused opacity",
        terminalOpacity: "Terminal opacity", spacing: "Spacing", rowScale: "Row height",
        barHeight: "Height", barIconSize: "Icon size", modulePad: "Module padding",
        flyoutWidth: "Flyout width", launcherRows: "Rows shown", notifWidth: "Popup width",
        seeThrough: "See-through", scrim: "Overlay dimming", barSeparator: "Separators",
        shadows: "Shadows", gradient: "Shaded grounds", heavyLines: "Heavy lines",
        headingUpper: "Case", headingRule: "Heading rule", headingMark: "Mark",
        headingMarkColour: "Mark colour", headingSize: "Heading size",
        fontFamily: "Font", barPosition: "Position", workspaceStyle: "Workspaces",
        controlIcon: "Control Centre icon", clockStyle: "Clock", windowStyle: "Open windows", windowScope: "Windows shown",
        iconTint: "App icons", vizStyle: "Visualizer", flyoutAnim: "Flyouts open",
        launcherLayout: "Launcher layout", launcherPosition: "Launcher position",
        launcherDetails: "Launcher details", notifStyle: "Notification popups",
        altTabStyle: "Window switcher", altTabScope: "Switcher windows",
        overviewLayout: "Workspace overview",
        overviewBackdrop: "Overview backdrop", powerStyle: "Power menu", levelStyle: "Level popup",
        accent: "Accent", levelColour: "Level colour", accentText: "Text on the accent",
        colourGood: "Good", colourAlert: "Alert",
        paletteBase: "Base", paletteBar: "Bar", palettePanel: "Panel", paletteSurface: "Surface",
        paletteOverlay: "Overlay", paletteBorder: "Border", paletteMuted: "Muted",
        paletteSubtext: "Subtext", paletteText: "Text", paletteBright: "Bright",
    })
    readonly property var keyUnits: ({ radius: "px", edgeGap: "px", spacing: "%", rowScale: "%",
                                         barHeight: "px", barIconSize: "px", modulePad: "px",
                                         flyoutWidth: "%", notifWidth: "px", seeThrough: "%", scrim: "%",
                                         focusedOpacity: "%", unfocusedOpacity: "%", terminalOpacity: "%" })
    function valueText(k, v) {
        if (typeof v === "boolean") return v ? "on" : "off"
        if (typeof v === "number") return v + (keyUnits[k] || "")
        if (v === "") return Settings.hexKeys.indexOf(k) !== -1 ? page.label(Settings.look) + "'s own" : "none"
        return page.label(v, k)
    }

    ThemeTab { id: tab_theme; page: page }

    BarTab { id: tab_bar; page: page }

    PanelsTab { id: tab_panels; page: page }

    DesktopTab { id: tab_desktop; page: page }

    AppsTab { id: tab_apps; page: page }

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
