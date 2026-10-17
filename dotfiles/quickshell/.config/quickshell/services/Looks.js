// Singularity - Quickshell
// ~/.config/quickshell/services/Looks.js
//
// The shell's looks: complete, named sets of the values Theme.qml hands out.
// Components never read this file -- they ask Theme for a role (Theme.panel,
// Theme.hoverFill, Theme.rowHeight) and Theme answers from whichever look is
// active, so switching look restyles everything at once.
//
// Switch looks from the Appearance page, the Control Centre, or a keybind:
//   qs ipc call look cycle        qs ipc call look set singularity
//
// A look has two halves:
//
//   settings  -- the values the Appearance page can also change. Picking a
//                look writes these into Settings; after that they're the
//                user's to adjust, and the look only comes back on a
//                re-pick. Every look states a `style` (Styles.js), which
//                draws all of its chrome; the Finish switches a look leaves
//                out come from its style.
//   the rest  -- fixed per look:
//     palette        the ten-role ramp (see below)
//     accent         the one hue for marks: selection ticks, focus, current
//                    items. null = the ramp's bright, a colourless look
//     good, alert    status hues
//     scrim          how dark full-screen overlays dim the desktop
//     motion         a factor on every animation; 0 for a look that should
//                    never move (e-ink)
//     layout         optional: the bar's arrangement, as Bar Widgets stores
//                    it -- { left, centre, right: [module keys], hidden:
//                    [keys], anchor: the pinned centre module or "" }.
//                    Picking the look replaces Bar Widgets' arrangement;
//                    leaving it for a look without one restores the user's.
//                    Keys a section omits go back to their default section.
//
// The shape keys in `settings`:
//     style        one of Styles.order
//     radius       Roundness: chips, panels, the bar and Hyprland's windows
//     barStyle     "full" edge to edge, "floating" inset and rounded, or
//                  "islands", each group of modules on its own ground
//     spacing      every gap and padding, in percent (Theme.sp)
//     rowScale     row heights, in percent (Theme.row); text never clips
//     barHeight    the bar's height in px; its chips grow with it
//     barIconSize  the bar's glyphs, in px at the base font size
//     modulePad    px either side of each bar module, before spacing
//                  (Settings.densities names the usual sets of the first
//                  three)
//     edgeGap      px between the screen's edges and the windows, and a
//                  floating bar or its islands; unstated, edgeGaps[barStyle]
//     seeThrough   the bar's and panels' opacity, in percent
//     focusedOpacity, unfocusedOpacity   Hyprland's windows' opacity when
//                  focused and not, in percent; unstated, the style's
//     terminalOpacity the terminal's background opacity, in percent;
//                  unstated, the style's
//     shadows, gradient, heavyLines, headingUpper, headingRule, headingMark,
//     barSeparator, levelColour, clockIsland   the Finish switches
//                  (Settings.qml)
//     styleOptions the style's own options that are on, comma-joined ids
//                  (Styles.js `options`); unstated, the style's
//
//     paletteBase … paletteBright   one ramp role each, "" for the
//                  look's own (grayscale only)
//     colourGood, colourAlert       the status hues, "" for the look's own
//     accentText   text on accent fills: "auto", "white" or "dark"
//
// The content keys in `settings`:
//     barPosition  "top" or "bottom"
//     windowBorderWidth   Hyprland's border: "style" (as thick as the
//                  strokes) or "0".."3" px
//     windowBorderFocused  "accent", "text" or "custom" (…FocusedHex)
//     windowBorderUnfocused "border", "none" or "custom" (…UnfocusedHex)
//     windowRounding  "shell" (the panels' corners) or "own" (windowRadius)
//     windowShadow "style" (the style's, with Shadows), "off", "small", "large"
//     tabBar       grouped windows' tab bar: "shell" colours or "accent"
//     flyoutWidth  bar flyouts' width, in percent of their own
//     launcherRows results the launcher shows before it scrolls (four
//                  more when it's full screen)
//     notifWidth   notification popups' width, in px at the base font size
//     workspaceStyle "pills"  the current workspace a long pill, others stubs
//                  "dots"     one dot each, the current one lit
//                  "lines"    one short rule each, the current one lit
//                  "numbers"  1 2 3, the current one lit
//                  "blocks"   squares: filled when occupied, lit when current
//                  "roman"    I II III, the current one lit
//                  "names"    the names in Settings.workspaceNames, numbers
//                             for the rest
//                  "apps"     the icon of an app open on each, a dot when empty
//     controlIcon  the Control Centre button's glyph: "arch" by default, or
//                  any of Settings.choices.controlIcon
//     clockStyle   "stamp"    23:50:02 | 09/18/26
//                  "time"     23:50
//                  "seconds"  23:50:02
//                  "day"      Fri 19 Sep  23:50
//                  "long"     Friday, September 19 · 23:50
//                  "iso"      2026-09-19  23:50
//                  "custom"   Settings.clockFormat, a Qt date format
//     windowStyle  "icons"    the open windows' icons, a short rule under each,
//                             a long accent one under the focused window
//                  "titled"   the same, with the focused window's title
//                  "glide"    the icons over one rail, an accent slider
//                             travelling to the focused one
//                  "lift"     no marks: the focused icon large and in
//                             colour, the rest small and grey
//                  "inset"    the focused icon in a recessed well
//                  "segmented" segments of one control, the focused one
//                             on a soft accent ground
//                  "spotlight" the focused window a capsule with its
//                             title, the rest small icons
//                  "tabs"     icon and title for every window, the focused
//                             one on a lit ground -- a classic taskbar
//                  "index"    a number and the app's name for each, the
//                             focused one on an accent ground
//                  "dots"     a dot per window, no icons
//     windowScope  "workspace" the focused workspace's windows
//                  "all"      every workspace's, grouped, a rule between
//     iconTint     "colour"   app icons as they are
//                  "mono"     greyed, so they sit in a colourless look
//                  "accent"   tinted the accent's hue
//     vizStyle     the bar's audio visualizer, in the meter colour:
//                  "mirror"   pills growing out from the middle
//                  "rise"     bars rising from the bottom
//                  "dots"     a stack of up to four dots per band
//                  "line"     one line through every band's level
//     launcherLayout "list" rows of results, "grid" a grid of large app
//                  icons (apps only; the other modes stay a list), "line"
//                  one compact row under the field, dmenu-like
//     launcherPosition "centre" of the screen, "top" just under the bar,
//                  "full" centred over a dimmed screen, with more rows
//     launcherDetails true: each result's second line (what the app is,
//                  where the file is) and the key hints; false: names only
//     notifStyle   notification popups: "full" every part of them,
//                  "compact" the body, picture and actions only while
//                  hovered, "banner" one line of summary and body
//     barSeparator between the bar's modules: "none", a thin "line", two
//                  ("double"), a "dot", three stacked ("dots"), or a line
//                  with a dot at each end ("capped")
//     altTabStyle  the ALT+Tab switcher's cards: "icons", "titled" an icon
//                  over each window's title, "previews" a still of each
//                  window with its app's icon in the corner
//     altTabScope  which windows ALT+Tab offers: "workspace" the focused
//                  workspace's, "all" every workspace's
//     overviewLayout SUPER+W's workspaces: a "grid" three across, or a
//                  "strip" of every workspace in one row
//     overviewBackdrop behind the overview: the desktop "dim"med by the
//                  overlay dimming, "clear", or hidden behind a "solid" ground
//     powerStyle   the power menu: a "row" of tiles, a "list" of rows, or
//                  "full" screen -- large tiles over a darkened desktop
//     levelStyle   the volume/brightness popup when the clock island is
//                  off: a level "pill" under the bar, a vertical bar at the
//                  screen's right "edge", or the "number" itself
//     gradient     true: the bar's ground and the panels shade from a
//                  little lighter at the top to a little darker at the
//                  bottom; false: flat grounds
//
// The palette's roles are semantic, not literal lightness: base is the most
// recessed ground (meter tracks), panel the flyouts' ground, overlay a hover
// fill, border a stroke, text/bright the foreground. A light look simply
// makes the grounds light and the foreground dark -- text on `panel` must
// read, `border` must show on `panel`, `bright` must stand out from `text`. Colour mode "wallpaper" swaps these
// ten for tones from the image (Wallpaper.qml) and keeps the rest.

.pragma library

.import "Styles.js" as Styles

// the look used when the chosen one is gone
var fallback = "singularity"

// shared defaults for the fixed half, so each look only states what differs
var base = {
    accent: null,
    scrim: 0.4,
    motion: 1,
}

var looks = {
    singularity: {
        name: "Singularity",
        description: "Greys and indigo, a double-stroked chip for every module, a full bar",
        palette: {
            base: "#0b0b0b", bar: "#121212", panel: "#141414", surface: "#1a1a1a", overlay: "#242424",
            border: "#303030", muted: "#4d4d4d", subtext: "#7a7a7a", text: "#d0e2fa", bright: "#ebebeb",
        },
        accent: "#5555c8",
        // desaturated hard, so they read as a tinted grey rather than alerts
        good: "#7d9b7d", alert: "#a87676",
        settings: {
            style: "double", radius: 6, fontFamily: "UbuntuMono Nerd Font",
        },
    },
    // The rest are ports of well-known editor themes: each one's own
    // backgrounds and foregrounds laid along the ramp, its signature hue as
    // the accent. Their accents are light, so accent fills say white text
    // outright rather than leaving it to "auto".
    arch: {
        name: "Arch",
        description: "Blue-black greys and the Arch logo's blue, outlined chips",
        palette: {
            base: "#0d1014", bar: "#12161b", panel: "#161a20", surface: "#1c2128", overlay: "#252b33",
            border: "#313842", muted: "#4d5663", subtext: "#7c8794", text: "#dce4ec", bright: "#f4f7fa",
        },
        accent: "#1793d1",
        good: "#57a773", alert: "#d9534f",
        settings: {
            style: "double", radius: 4, fontFamily: "Hack Nerd Font", accentText: "white",
        },
    },
    nord: {
        name: "Nord",
        description: "Polar Night greys, Snow Storm text, a Frost blue accent",
        palette: {
            base: "#242933", bar: "#292e39", panel: "#2e3440", surface: "#3b4252", overlay: "#434c5e",
            border: "#4c566a", muted: "#616e88", subtext: "#9aa3b5", text: "#d8dee9", bright: "#eceff4",
        },
        accent: "#81a1c1",
        good: "#a3be8c", alert: "#bf616a",
        settings: {
            style: "solid", radius: 8, fontFamily: "JetBrainsMono Nerd Font", accentText: "white",
        },
    },
    dracula: {
        name: "Dracula",
        description: "Dracula's purple-greys and purple, frosted glass",
        palette: {
            base: "#191a21", bar: "#21222c", panel: "#282a36", surface: "#303241", overlay: "#3a3c4e",
            border: "#44475a", muted: "#6272a4", subtext: "#9aa3c4", text: "#f8f8f2", bright: "#ffffff",
        },
        accent: "#bd93f9",
        good: "#50fa7b", alert: "#ff5555",
        settings: {
            style: "glass", radius: 10, fontFamily: "FiraCode Nerd Font", accentText: "white",
        },
    },
    tokyonight: {
        name: "Tokyo Night",
        description: "Tokyo Night's deep indigo and its blue, grooved bands",
        palette: {
            base: "#13141c", bar: "#16161e", panel: "#1a1b26", surface: "#1f2335", overlay: "#292e42",
            border: "#3b4261", muted: "#565f89", subtext: "#737aa2", text: "#c0caf5", bright: "#dfe5ff",
        },
        accent: "#7aa2f7",
        good: "#9ece6a", alert: "#f7768e",
        settings: {
            style: "channel", radius: 6, fontFamily: "GeistMono Nerd Font", accentText: "white",
        },
    },
    catppuccin: {
        name: "Catppuccin Mocha",
        description: "Mocha's soft darks and Mauve, solid blocks on a floating bar",
        palette: {
            base: "#11111b", bar: "#181825", panel: "#1e1e2e", surface: "#252536", overlay: "#313244",
            border: "#45475a", muted: "#6c7086", subtext: "#a6adc8", text: "#cdd6f4", bright: "#eef1ff",
        },
        accent: "#cba6f7",
        good: "#a6e3a1", alert: "#f38ba8",
        settings: {
            style: "solid", radius: 12, barStyle: "floating", fontFamily: "CaskaydiaCove Nerd Font",
            accentText: "white",
        },
    },
    onedark: {
        name: "One Dark",
        description: "Atom's One Dark greys and its blue, outlined chips",
        palette: {
            base: "#1b1d23", bar: "#21252b", panel: "#282c34", surface: "#2c313c", overlay: "#353b45",
            border: "#3e4451", muted: "#5c6370", subtext: "#828997", text: "#abb2bf", bright: "#d7dae0",
        },
        accent: "#61afef",
        good: "#98c379", alert: "#e06c75",
        settings: {
            style: "double", radius: 6, fontFamily: "SauceCodePro Nerd Font", accentText: "white",
        },
    },
    kanagawa: {
        name: "Kanagawa",
        description: "Sumi ink and Fuji white, a Crystal Blue accent, grooved bands",
        palette: {
            base: "#16161d", bar: "#1a1a22", panel: "#1f1f28", surface: "#2a2a37", overlay: "#363646",
            border: "#54546d", muted: "#727169", subtext: "#9e9a85", text: "#dcd7ba", bright: "#ede8cf",
        },
        accent: "#7e9cd8",
        good: "#98bb6c", alert: "#c34043",
        settings: {
            style: "channel", radius: 4, fontFamily: "BlexMono Nerd Font", accentText: "white",
        },
    },
}
var order = Object.keys(looks)

// The settings a look doesn't state. Filled in rather than left out so
// picking any look sets all of them -- otherwise leaving a bottom-bar look
// for one that doesn't say would keep the bar at the bottom.
var settingsBase = {
    // the ramp's roles one by one, "" for the look's own (grayscale only)
    paletteBase: "", paletteBar: "", palettePanel: "", paletteSurface: "", paletteOverlay: "",
    paletteBorder: "", paletteMuted: "", paletteSubtext: "", paletteText: "", paletteBright: "",
    // the status hues, "" for the look's own
    colourGood: "",
    colourAlert: "",
    // text on an accent fill: "auto" picks white or dark by the accent's
    // brightness
    accentText: "auto",
    // the headings' mark's colour ("accent", "text", "muted") and their
    // size against body text ("smaller", "same", "larger"); the mark
    // itself (headingMark) comes with the style
    headingMarkColour: "accent",
    headingSize: "smaller",
    spacing: 100,
    rowScale: 100,
    barHeight: 32,
    barIconSize: 17,
    modulePad: 6,
    windowBorderWidth: "style",
    windowBorderFocused: "accent",
    windowBorderFocusedHex: "",
    windowBorderUnfocused: "border",
    windowBorderUnfocusedHex: "",
    windowRounding: "shell",
    windowRadius: 6,
    windowShadow: "style",
    tabBar: "shell",
    flyoutWidth: 100,
    launcherRows: 8,
    notifWidth: 380,
    barStyle: "full",
    barPosition: "top",
    seeThrough: 100,
    shadows: true,
    heavyLines: false,
    levelColour: "accent",
    workspaceStyle: "pills",
    controlIcon: "arch",
    clockStyle: "stamp",
    windowStyle: "icons",
    windowScope: "workspace",
    iconTint: "colour",
    vizStyle: "mirror",
    launcherLayout: "list",
    launcherPosition: "centre",
    launcherDetails: true,
    notifStyle: "full",
    altTabStyle: "icons",
    altTabScope: "workspace",
    overviewLayout: "grid",
    overviewBackdrop: "dim",
    powerStyle: "row",
    levelStyle: "pill",
}

// The edge gap each bar shape starts at: a full bar runs to the screen's
// edges and the windows meet it, a floating one leaves room all round.
var edgeGaps = { full: 0, floating: 10, islands: 10 }

// The parts of the fixed half the Appearance page can also adjust, copied
// into `settings` in the units Settings stores ("" for no accent, scrim in
// percent), so picking the look sets them like the rest.
function adjustable(look) {
    return {
        accent: look.accent || "",
        scrim: Math.round(look.scrim * 100),
    }
}

// a look with its fixed half filled in from `base`, its Finish switches
// from its style, and the rest of its settings from `settingsBase`
function complete(look) {
    for (var b in base)
        if (look[b] === undefined) look[b] = base[b]
    var fin = Styles.finish(look.settings.style)
    for (var f in fin)
        if (look.settings[f] === undefined) look.settings[f] = fin[f]
    var win = Styles.windows(look.settings.style)
    for (var w in win)
        if (look.settings[w] === undefined) look.settings[w] = win[w]
    for (var s in settingsBase)
        if (look.settings[s] === undefined) look.settings[s] = settingsBase[s]
    if (look.settings.edgeGap === undefined) look.settings.edgeGap = edgeGaps[look.settings.barStyle] || 0
    var a = adjustable(look)
    for (var k in a)
        if (look.settings[k] === undefined) look.settings[k] = a[k]
    return look
}
for (var n in looks) complete(looks[n])

// The accents the Appearance page offers besides the look's own: one per
// hue around the wheel, at a lightness that reads on dark and light grounds.
var accents = [
    "#e5484d", "#f76b15", "#f5b70a", "#8fc93a", "#30a46c",
    "#12a594", "#0091ff", "#5555c8", "#8e4ec6", "#d6409f",
]

// The look the template configs (wofi, starship, fastfetch) are written in:
// their colours are this ramp, and AppearanceSync maps each one to the current role.
var reference = "singularity"

// Fonts the Appearance page offers: monospace faces only, each as its plain
// "Nerd Font" family. Not the "Nerd Font Mono" variant, which squashes every
// icon into one text cell (see Theme.fontText), and not "Propo", which isn't
// monospace. The first is the fallback (Fonts.resolve). Each is a package in
// packages/pacman.txt; the page only lists the installed ones.
var fonts = [
    "UbuntuMono Nerd Font", "JetBrainsMono Nerd Font", "FiraCode Nerd Font", "Hack Nerd Font",
    "CaskaydiaCove Nerd Font", "SauceCodePro Nerd Font", "BlexMono Nerd Font", "VictorMono Nerd Font",
    "GeistMono Nerd Font", "CommitMono Nerd Font", "SpaceMono Nerd Font", "MartianMono Nerd Font",
    "Mononoki Nerd Font", "Terminess Nerd Font", "Iosevka Nerd Font",
]
// the fonts' own names, not the Nerd Fonts' renamed families
var fontLabels = {
    "UbuntuMono Nerd Font": "Ubuntu Mono", "JetBrainsMono Nerd Font": "JetBrains Mono",
    "FiraCode Nerd Font": "Fira Code", "Hack Nerd Font": "Hack",
    "CaskaydiaCove Nerd Font": "Cascadia Code", "SauceCodePro Nerd Font": "Source Code Pro",
    "BlexMono Nerd Font": "IBM Plex Mono", "VictorMono Nerd Font": "Victor Mono",
    "GeistMono Nerd Font": "Geist Mono", "CommitMono Nerd Font": "Commit Mono",
    "SpaceMono Nerd Font": "Space Mono", "MartianMono Nerd Font": "Martian Mono",
    "Mononoki Nerd Font": "Mononoki", "Terminess Nerd Font": "Terminus",
    "Iosevka Nerd Font": "Iosevka",
}

// The weight body text is set in, for the fonts that need other than
// regular: Ubuntu Mono has no medium, and its regular reads thin.
var fontWeights = { "UbuntuMono Nerd Font": "bold" }

// The system font: what GTK and Qt apps draw everywhere outside the shell
// itself (AppearanceSync.renderGtk/renderQt) -- independent of `fonts` above,
// which is the shell's own monospace-only face. Proportional, general-purpose
// faces only, each one a package pacman.txt already installs, so every entry
// here is always selectable. The first is the fallback.
var systemFonts = ["Ubuntu Nerd Font", "Noto Sans"]
var systemFontLabels = {
    "Ubuntu Nerd Font": "Ubuntu", "Noto Sans": "Noto Sans",
}

// Density's presets: Spacing, Row height and Bar height at once. Rows
// move half as far as the gaps, so compact rows tighten a little while the
// space between them tightens more.
var densities = {
    compact: { spacing: 75, rowScale: 88, barHeight: 28 },
    normal:  { spacing: 100, rowScale: 100, barHeight: 32 },
    roomy:   { spacing: 130, rowScale: 115, barHeight: 36 },
}
