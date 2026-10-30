// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAppearance.qml
//
// The Look pages, one part of the screen each (`part`): Theme, Wallpaper &
// Desktop, Bar, Panels & Popups, Windows, Fonts & Icons; each a thin
// SettingsPage<Part>.qml over this. Most open on a preview; while anything
// differs from the baseline, ChangesBar floats at the page's foot (Review,
// Save as default, Reset), whose Show opens the page a change is on; a
// changed field is marked and its mark resets it. Shell settings are
// Settings.qml (shared with the Control Centre); window settings go to
// hyprland.json, then a reload. Each part's rows live in appearance/; this
// keeps what they reach through `page`.

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
    footer: ChangesBar {}
    footerVisible: !Settings.lookPristine
    // theme | wallpaper | bar | panels | windows | fonts
    property string part: "theme"
    tab: part

    // the card on top: what the part is set to now
    status: {
        switch (part) {
        case "theme": {
            var look = Looks.looks[Settings.look]
            return (look ? look.name : label(Settings.look)) + " · " + label(Settings.style, "style")
        }
        case "wallpaper": return Wallpaper.current !== "" ? Wallpaper.current.split("/").pop() : "No wallpaper"
        case "bar": return label(Settings.barPosition) + " · " + label(Settings.barStyle, "barStyle") + " · " + Settings.barHeight + " px"
        case "panels": return "Flyouts: " + label(Settings.flyoutAnim, "flyoutAnim") + " · launcher: " + label(Settings.launcherLayout, "launcherLayout")
        case "windows": return "Gaps " + (hyprField(["general"], "gaps_in").value || 0) + " px · " + label(Settings.windowAnim, "windowAnim") + " animation"
        case "fonts": return Theme.fontText + " · " + Settings.fontSize + " px"
        }
        return ""
    }
    statusDetail: {
        switch (part) {
        case "theme": return "Roundness " + Settings.radius + " px · " + label(Settings.colourMode)
        case "wallpaper": return Settings.wallpaperShuffle ? "Changes on its own" : "Stays until you change it"
        case "bar": return "Chips " + label(Settings.barChips, "barChips").toLowerCase() + " · separators " + label(Settings.barSeparator, "barSeparator").toLowerCase()
        case "panels": return "Switcher: " + label(Settings.altTabStyle, "altTabStyle") + " · popups: " + label(Settings.notifStyle, "notifStyle")
        case "windows": return "Corners " + (Settings.windowRounding === "own" ? Settings.windowRadius + " px" : "as the shell's")
        case "fonts": return "Apps: " + label(Settings.systemFontFamily) + " · " + Settings.iconTheme + " · " + Settings.cursorTheme
        }
        return ""
    }

    // a small bar, flyout or windows, drawn by the shell's own pieces, above
    // the parts whose settings change how they look
    pinned: LivePreview { kind: ({ bar: "bar", panels: "launcher", windows: "windows" })[page.part] || "flyout" }
    pinnedVisible: page.part !== "wallpaper"

    title: ({ theme: "Theme", wallpaper: "Wallpaper & Desktop", bar: "Bar", panels: "Panels & Popups",
              windows: "Windows", fonts: "Fonts & Icons" })[part]
    description: "Changes apply as you make them; a dot marks a setting that differs from the baseline."

    stickyColumn: rows.item || rows

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
        style: "Style", radius: "Roundness", barStyle: "Bar shape", edgeGap: "Edge gaps",
        focusedOpacity: "Focused opacity", unfocusedOpacity: "Unfocused opacity",
        terminalOpacity: "Terminal opacity", spacing: "Spacing", rowScale: "Row height",
        barHeight: "Height", barIconSize: "Icon size", modulePad: "Module padding",
        windowBorderWidth: "Border width", windowBorderFocused: "Focused border",
        windowBorderFocusedHex: "Focused colour", windowBorderUnfocused: "Unfocused border",
        windowBorderUnfocusedHex: "Unfocused colour", windowRounding: "Window corners",
        windowRadius: "Window rounding", windowShadow: "Window shadow", tabBar: "Tab bar",
        flyoutWidth: "Flyout width", launcherRows: "Rows shown", notifWidth: "Popup width",
        seeThrough: "See-through", scrim: "Overlay dimming", barSeparator: "Separators", barChips: "Chips",
        shadows: "Shadows", gradient: "Shaded grounds", heavyLines: "Heavy lines",
        headingUpper: "Case", headingRule: "Heading rule", headingMark: "Mark",
        headingMarkColour: "Mark colour", headingSize: "Heading size",
        fontFamily: "Font", barPosition: "Position", workspaceStyle: "Workspaces",
        controlIcon: "Control Centre icon", clockStyle: "Clock", clockIsland: "Clock island", windowStyle: "Open windows", windowScope: "Windows shown",
        iconTint: "App icons", vizStyle: "Visualizer", vizBars: "Visualizer bars", vizShown: "Music visualizer", musicTitle: "Music title", vizHideSilent: "Hide when silent", flyoutAnim: "Flyouts open",
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
                                         flyoutWidth: "%", notifWidth: "px", windowRadius: "px", seeThrough: "%", scrim: "%",
                                         focusedOpacity: "%", unfocusedOpacity: "%", terminalOpacity: "%" })
    function valueText(k, v) {
        if (typeof v === "boolean") return v ? "on" : "off"
        if (typeof v === "number") return v + (keyUnits[k] || "")
        if (v === "") return Settings.hexKeys.indexOf(k) !== -1 ? page.label(Settings.look) + "'s own" : "none"
        return page.label(v, k)
    }

    // the part's rows
    Loader {
        id: rows
        width: parent ? parent.width : 0
        Component.onCompleted: setSource("appearance/" + ({ theme: "ThemeTab", wallpaper: "WallpaperTab", bar: "BarTab",
            panels: "PanelsTab", windows: "WindowsTab", fonts: "FontsTab" })[page.part] + ".qml", { page: page })
    }

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
