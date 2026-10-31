// Singularity - Quickshell
// ~/.config/quickshell/services/Looks.js
//
// The shell's looks: named sets of colours Theme hands out. Components
// never read this file; they ask Theme for a role. Switch with the
// Appearance page, the Control Centre or `qs ipc call look set <name>`.
// A look holds colours only; the rest of Appearance is the style's
// (Styles.js), so picking a look never changes the style or its default.
//
// A look has two halves:
//   settings  -- colours Appearance can also change (colourKeys), written
//                into Settings when the look is picked; colourBase fills in
//                any a look omits
//   the rest  -- fixed per look:
//     palette      the ten-role ramp (below)
//     accent       the one hue for marks; null = the ramp's bright
//     good, alert  status hues
//     scrim        how dark full-screen overlays dim
//     motion       a factor on every animation (0: never moves)
//     layout       optional bar arrangement as Bar Widgets stores it
//                  ({ left, centre, right, hidden, anchor }); replaces the
//                  user's while the look is on
//
// `settings` keys are Settings.qml's, with values from Settings.choices.
//
// The palette's roles are semantic: base the most recessed ground (meter
// tracks), panel the flyouts' ground, overlay a hover fill, border a
// stroke, text/bright the foreground. A light look makes the grounds light
// and the foreground dark. Wallpaper colour mode swaps these ten for the
// image's tones (Wallpaper.qml).

.pragma library

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
        description: "Greys and indigo",
        palette: {
            base: "#0b0b0b", bar: "#121212", panel: "#141414", surface: "#1a1a1a", overlay: "#242424",
            border: "#303030", muted: "#4d4d4d", subtext: "#7a7a7a", text: "#d0e2fa", bright: "#ebebeb",
        },
        accent: "#5555c8",
        // desaturated hard, so they read as a tinted grey rather than alerts
        good: "#7d9b7d", alert: "#a87676",
        settings: {},
    },
    // Ports of well-known editor themes: their grounds and foregrounds laid
    // along the ramp, their signature hue as the accent (light, so accent
    // text is white outright).
    arch: {
        name: "Arch",
        description: "Blue-black greys and the Arch logo's blue",
        palette: {
            base: "#0d1014", bar: "#12161b", panel: "#161a20", surface: "#1c2128", overlay: "#252b33",
            border: "#313842", muted: "#4d5663", subtext: "#7c8794", text: "#dce4ec", bright: "#f4f7fa",
        },
        accent: "#1793d1",
        good: "#57a773", alert: "#d9534f",
        settings: { accentText: "white" },
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
        settings: { accentText: "white" },
    },
    dracula: {
        name: "Dracula",
        description: "Dracula's purple-greys and purple",
        palette: {
            base: "#191a21", bar: "#21222c", panel: "#282a36", surface: "#303241", overlay: "#3a3c4e",
            border: "#44475a", muted: "#6272a4", subtext: "#9aa3c4", text: "#f8f8f2", bright: "#ffffff",
        },
        accent: "#bd93f9",
        good: "#50fa7b", alert: "#ff5555",
        settings: { accentText: "white" },
    },
    tokyonight: {
        name: "Tokyo Night",
        description: "Tokyo Night's deep indigo and its blue",
        palette: {
            base: "#13141c", bar: "#16161e", panel: "#1a1b26", surface: "#1f2335", overlay: "#292e42",
            border: "#3b4261", muted: "#565f89", subtext: "#737aa2", text: "#c0caf5", bright: "#dfe5ff",
        },
        accent: "#7aa2f7",
        good: "#9ece6a", alert: "#f7768e",
        settings: { accentText: "white" },
    },
    catppuccin: {
        name: "Catppuccin Mocha",
        description: "Mocha's soft darks and Mauve",
        palette: {
            base: "#11111b", bar: "#181825", panel: "#1e1e2e", surface: "#252536", overlay: "#313244",
            border: "#45475a", muted: "#6c7086", subtext: "#a6adc8", text: "#cdd6f4", bright: "#eef1ff",
        },
        accent: "#cba6f7",
        good: "#a6e3a1", alert: "#f38ba8",
        settings: { accentText: "white" },
    },
    onedark: {
        name: "One Dark",
        description: "Atom's One Dark greys and its blue",
        palette: {
            base: "#1b1d23", bar: "#21252b", panel: "#282c34", surface: "#2c313c", overlay: "#353b45",
            border: "#3e4451", muted: "#5c6370", subtext: "#828997", text: "#abb2bf", bright: "#d7dae0",
        },
        accent: "#61afef",
        good: "#98c379", alert: "#e06c75",
        settings: { accentText: "white" },
    },
    kanagawa: {
        name: "Kanagawa",
        description: "Sumi ink and Fuji white, a Crystal Blue accent",
        palette: {
            base: "#16161d", bar: "#1a1a22", panel: "#1f1f28", surface: "#2a2a37", overlay: "#363646",
            border: "#54546d", muted: "#727169", subtext: "#9e9a85", text: "#dcd7ba", bright: "#ede8cf",
        },
        accent: "#7e9cd8",
        good: "#98bb6c", alert: "#c34043",
        settings: { accentText: "white" },
    },
}
var order = Object.keys(looks)

// the colours a look doesn't state, so picking any look sets all of them
var colourBase = {
    // the ramp's roles one by one, "" for the look's own (grayscale only)
    paletteBase: "", paletteBar: "", palettePanel: "", paletteSurface: "", paletteOverlay: "",
    paletteBorder: "", paletteMuted: "", paletteSubtext: "", paletteText: "", paletteBright: "",
    // the status hues, "" for the look's own
    colourGood: "",
    colourAlert: "",
    // text on an accent fill: "auto" picks white or dark by the accent's
    // brightness
    accentText: "auto",
    // the heading mark's colour, level fills' and the windows' borders'
    headingMarkColour: "accent",
    levelColour: "accent",
    windowBorderFocused: "accent",
    windowBorderFocusedHex: "",
    windowBorderUnfocused: "border",
    windowBorderUnfocusedHex: "",
}

// the fixed half's adjustable parts, in Settings' units ("" for no accent,
// scrim in percent)
function adjustable(look) {
    return {
        accent: look.accent || "",
        scrim: Math.round(look.scrim * 100),
    }
}

// the Settings keys a look sets: its colours, accent and scrim
var colourKeys = Object.keys(colourBase).concat(["accent", "scrim"])

// a look with its fixed half filled in from `base` and the rest of its
// colours from `colourBase`
function complete(look) {
    for (var b in base)
        if (look[b] === undefined) look[b] = base[b]
    for (var s in colourBase)
        if (look.settings[s] === undefined) look.settings[s] = colourBase[s]
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

// The look the template configs (starship, fastfetch) are written in:
// their colours are this ramp, and AppearanceSync maps each one to the current role.
var reference = "singularity"

// Fonts Appearance offers: monospace Nerd Font families (not "Mono", which
// squashes icons; not "Propo"). The first is the fallback; the page lists
// only the installed ones.
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

// GTK and Qt apps' font (AppearanceSync), proportional faces pacman.txt
// installs; the first is the fallback
var systemFonts = ["Ubuntu Nerd Font", "Noto Sans"]
var systemFontLabels = {
    "Ubuntu Nerd Font": "Ubuntu", "Noto Sans": "Noto Sans",
}

// Density's presets: Spacing, Row height and Bar height at once (rows move
// half as far as the gaps)
var densities = {
    compact: { spacing: 75, rowScale: 88, barHeight: 28 },
    normal:  { spacing: 100, rowScale: 100, barHeight: 32 },
    roomy:   { spacing: 130, rowScale: 115, barHeight: 36 },
}
