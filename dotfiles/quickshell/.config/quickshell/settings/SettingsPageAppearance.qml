// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAppearance.qml
//
// Appearance: one page, six tabs by what they change (Colour, Shape,
// Type, Bar, Panels, Motion), each under a preview of what it changes;
// every section's rarely changed rows fold behind its Advanced. While
// anything differs from the baseline, ChangesBar floats at the page's foot
// (Review, Save as default, Reset), whose Show opens the tab a change is
// on; a changed field is marked and its mark resets it. Shell settings are
// Settings.qml (shared with the Control Centre); window settings go to
// hyprland.json, then a reload. Each tab's rows live in appearance/; this
// keeps what they reach through `page`.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services/HyprTables.js" as HyprTables
import "../services"
import "../flyouts"
import "appearance"

SettingsPage {
    id: page

    title: "Appearance"
    sectioned: true
    essentialRows: 0
    footer: ChangesBar {}
    footerVisible: !Settings.isDefault

    tabs: [
        { id: "colour", label: "Colour", icon: "󰏘", file: "ColourTab" },
        { id: "shape",  label: "Shape",  icon: "󰠲", file: "ShapeTab" },
        { id: "bar",    label: "Bar",    icon: "󰕰", file: "BarTab" },
        { id: "panels", label: "Panels", icon: "󰕮", file: "PanelsTab" },
        { id: "motion", label: "Motion", icon: "󰗘", file: "MotionTab" },
        { id: "type",   label: "Type",   icon: "󰛖", file: "TypeTab" },
    ]

    // a small bar, flyout, launcher or windows, drawn by the shell's own
    // pieces, showing what the tab changes
    pinned: LivePreview {
        kind: ({ colour: "flyout", shape: "windows", type: "flyout", bar: "bar", panels: "launcher", motion: "windows" })[page.tab]
    }

    stickyColumn: rows.item || rows

    function label(v, key) { return Settings.choiceLabel(v, key) }

    // the field a control sits in, marked as holding `key` when it has a
    // default (Settings.defaults)
    function markField(control, key) {
        var f = control.parent ? control.parent.parent : null
        if (f && f.isSettingsField === true && f.defaultKey === "" && Settings.defaults[key] !== undefined)
            f.defaultKey = key
    }

    // --- the list of changes (ChangesBar) -------------------------------------

    // What each setting with a default is called on this page, for the list
    // of changes; the same as its field's label, so "Show" can find it
    readonly property var keyLabels: ({
        style: "Style", styleOptions: "Style options", radius: "Roundness", barStyle: "Bar shape", edgeGap: "Edge gaps",
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
        fontFamily: "Font", fontSize: "Font size", windowAnim: "Window animation", animTime: "Animations", animWindows: "Window speed",
        animWorkspaces: "Workspace speed", animShell: "Shell speed", barPosition: "Position", workspaceStyle: "Workspaces",
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
                                         focusedOpacity: "%", unfocusedOpacity: "%", terminalOpacity: "%",
                                         fontSize: "px", animTime: "%", animWindows: "%", animWorkspaces: "%", animShell: "%" })
    function valueText(k, v) {
        if (typeof v === "boolean") return v ? "on" : "off"
        if (typeof v === "number") return v + (keyUnits[k] || "")
        if (v === "") return Settings.hexKeys.indexOf(k) !== -1 ? page.label(Settings.look) + "'s own" : "none"
        return page.label(v, k)
    }

    // the tab showing's rows, built when it's picked
    Loader {
        id: rows
        width: parent ? parent.width : 0
        property string shown: ""
        function load() {
            var t = page.tabs.find(x => x.id === page.tab)
            if (!t || shown === t.id) return
            shown = t.id
            setSource("appearance/" + t.file + ".qml", { page: page })
        }
        Component.onCompleted: load()
    }
    onTabChanged: rows.load()

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
