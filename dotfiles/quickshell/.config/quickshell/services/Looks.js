// Singularity - Quickshell
// ~/.config/quickshell/services/Looks.js
//
// The shell's looks: complete, named sets of the values Theme.qml hands out.
// Components never read this file -- they ask Theme for a role (Theme.panel,
// Theme.hoverFill, Theme.rowHeight) and Theme answers from whichever look is
// active, so switching look restyles everything at once.
//
// Only the fallback look lives here. The rest are data in looks.json, read by
// LookStore.qml -- which is what everything asks for the list of looks -- so
// the Appearance page can delete one outright. Each entry there has exactly
// the shape described below.
//
// Switch looks from the Appearance page, the Control Centre, or a keybind:
//   qs ipc call look cycle        qs ipc call look set singularity
//
// A look has two halves:
//
//   settings  -- the values the Appearance page can also change: radius, the
//                bar's height/gap/opacity/style/position, module style,
//                frame style, density, font, workspace and clock style,
//                plus the adjustable part of the fixed half (adjustable()
//                below). Picking a look writes these into Settings;
//                after that they're the user's to adjust, and the look only
//                comes back on a re-pick.
//   the rest  -- fixed per look:
//     palette        the ten-role ramp (see below)
//     accent         the one hue for marks: selection ticks, focus, current
//                    items, and meters when meterAccent. null = the ramp's
//                    bright, i.e. a colourless look
//     accent2        a second hue, for meters, levels and the visualizer;
//                    null leaves those to the accent or the text colour
//     good, alert    status hues
//     borderWidth    every stroke, in px
//     panelOpacity   flyouts, windows, wofi and notification cards; below 1
//                    lets the desktop show through
//     heading        { upper, bold, spacing, rule, accent }: section headings
//                    in caps or title case, with or without the trailing
//                    rule, in the accent or in bright
//     bevel          { light, dark }, or null. When frameStyle is "bevel",
//                    panels and outline chips are drawn as a chiselled 3D
//                    edge in these two colours instead of a flat stroke
//                    (see Bevel.qml). null falls back to a computed
//                    light/dark pair off `border`.
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
// Corners in `settings`: `radius` for chips and controls, `panelRadius` for
// flyouts, the shell's windows, notifications and wofi, `barRadius` for a
// floating bar, islands and the notch. The last two default to `radius`.
//
// The style switches in `settings`:
//     moduleStyle  "outline"  stroked chips (the double frame applies here)
//                  "filled"   solid chips, no stroke
//                  "flat"     bare glyphs; the active one is underlined
//                  "pill"     solid, fully rounded
//                  "ghost"    bare until active, then a filled ground
//                  "bracket"  bare, between [ and ], like a tmux status line
//                  "underline" bare over a rule, lit when active; a gauge
//                             fills the rule instead of the chip
//     barStyle     "full"     edge to edge, a hairline on its inner edge
//                  "floating" inset from the screen edges, rounded, stroked
//                  "islands"  no bar at all between the groups: left, centre
//                             and right each float on a ground of their own
//                  "bare"     no ground anywhere -- the chips sit straight
//                             on the wallpaper
//                  "notch"    only the centre group has a ground, hanging
//                             flush from the screen edge; the sides are bare
//     barPosition  "top" or "bottom"
//     workspaceStyle "pills"  the current workspace a long pill, others stubs
//                  "dots"     one dot each, the current one lit
//                  "lines"    one short rule each, the current one lit
//                  "numbers"  1 2 3, the current one lit
//                  "blocks"   squares: filled when occupied, lit when current
//                  "roman"    I II III, the current one lit
//                  "names"    the names in Settings.workspaceNames, numbers
//                             for the rest
//                  "apps"     the icon of an app open on each, a dot when empty
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
//     windowMark   how the icon styles mark the focused window:
//                  "pill"     a long accent pill under it, stubs under the rest
//                  "dot"      an accent dot under it alone
//                  "above"    an accent rule along the chip's top edge
//                  "ground"   a lit ground behind its icon
//                  "box"      an accent outline around its icon
//     iconTint     "colour"   app icons as they are
//                  "mono"     greyed, so they sit in a colourless look
//                  "accent"   tinted the accent's hue
//     shadow       "none"     panels and chips sit flat
//                  "soft"     a blurred drop shadow under flyouts, the
//                             shell's panels and solid chips
//                  "hard"     a solid offset copy of the shape instead --
//                             Windows 95, or a brutalist poster
//     vizStyle     the bar's audio visualizer, in the meter colour:
//                  "mirror"   pills growing out from the middle
//                  "rise"     bars rising from the bottom
//                  "dots"     a stack of up to four dots per band
//                  "line"     one line through every band's level
//     gaugeStyle   the volume, brightness and battery chips' level:
//                  "fill"     the chip's interior fills from the left
//                  "segments" five blocks, lit up to the level
//                  "rule"     a thin rule along the chip's bottom edge
//                  (the underline module style always uses its own rule)
//     flyoutAnim   how a flyout opens: "drop" slides it out of the bar,
//                  "fade" fades it in, "scale" grows it from its chip,
//                  "none" shows it at once
//     flyoutAttach where a flyout sits: "flush" against the bar, "tab" the
//                  same with the corners at the bar squared off, so it
//                  hangs from it, "floating" a gap below it
//     flyoutTitle  a flyout's first heading: "none" a plain heading,
//                  "strip" on a ground of its own across the top,
//                  "titlebar" a title bar in the accent with a close box
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
//     notifStripe  true: a stripe down a notification's edge, in the
//                  accent, the alert colour when critical, muted when low
//     barSeparator between the bar's modules: "none", a thin "line", a
//                  "dot", or a powerline-style "chevron"
//     hoverStyle   a bar module under the pointer: "none", a "fill"
//                  behind it, an accent "outline", or a one-pixel "lift"
//     altTabStyle  the ALT+Tab switcher's cards: "icons", "titled" an icon
//                  over each window's title, "previews" a still of each
//                  window with its app's icon in the corner
//     overviewLayout SUPER+W's workspaces: a "grid" three across, or a
//                  "strip" of every workspace in one row
//     overviewBackdrop behind the overview: the desktop "dim"med by the
//                  overlay dimming, "clear", or hidden behind a "solid" ground
//     powerStyle   the power menu: a "row" of tiles, a "list" of rows, or
//                  "full" screen -- large tiles over a darkened desktop
//     levelStyle   the volume/brightness popup when the clock island is
//                  off: a level "pill" under the bar, a vertical bar at the
//                  screen's right "edge", or the "number" itself
//     headingFont  the face section headings are set in; "" for the text
//                  font. Any of the text fonts, or one of Looks.headingFonts
//     textWeight   labels and body text: "light", "regular" or "medium"
//     boldWeight   what's bold -- headings, titles: "medium", "bold" or
//                  "black". A font without the weight draws its nearest
//     gradient     true: the bar's ground and the panels shade from a
//                  little lighter at the top to a little darker at the
//                  bottom; false: flat grounds
//     frameStyle   "double"   a second stroke inset inside the outer one
//                  "single"   the outer stroke alone
//                  "bevel"    a raised 3D edge outside, a sunken one inside --
//                             Windows 95's chrome
//                  "groove"   the bevel inside out, an etched line
//                  "accent"   the outer stroke alone, in the accent colour
//                  "corners"  an L at each corner, nothing between
//                  "none"     no stroke, the ground alone
//
// Adding a look: copy an entry in looks.json and rename its key. Every key in
// `palette` must be present, and in `settings` all but the layout ones in
// `settingsBase` below; the rest of the fixed half falls back to `base`.
// Fonts must be installed (fc-list : family); the families here are all in
// packages/.

//
// The palette's roles are semantic, not literal lightness: base is the most
// recessed ground (meter tracks), panel the flyouts' ground, overlay a hover
// fill, border a stroke, text/bright the foreground. A light look simply
// makes the grounds light and the foreground dark -- text on `panel` must
// read, `border` must show on `panel`, `bright` must stand out from `text`. Colour mode "wallpaper" swaps these
// ten for tones from the image (Wallpaper.qml) and keeps the rest.

.pragma library

// the look that can't be removed, and the one used when the chosen look is gone
var fallback = "singularity"

// shared defaults for the fixed half, so each look only states what differs
var base = {
    accent: null,
    accent2: null,
    borderWidth: 1,
    panelOpacity: 1,
    meterAccent: false,
    heading: { upper: true, bold: true, spacing: 1, rule: true, accent: false },
    bevel: null,
    scrim: 0.4,
    motion: 1,
}

var looks = {
    singularity: {
        name: "Singularity",
        description: "Grayscale, double-stroked frames, tight spacing",
        palette: {
            base: "#0b0b0b", bar: "#121212", panel: "#141414", surface: "#1a1a1a", overlay: "#242424",
            border: "#303030", muted: "#4d4d4d", subtext: "#7a7a7a", text: "#d0e2fa", bright: "#ebebeb",
        },
        accent: "#5555c8",
        // desaturated hard, so they read as a tinted grey rather than alerts
        good: "#7d9b7d", alert: "#a87676",
        settings: {
            radius: 6, barHeight: 32, moduleGap: 2, barOpacity: 100,
            frameStyle: "double", density: "normal", fontFamily: "UbuntuMono Nerd Font",
            moduleStyle: "outline", barStyle: "full",
        },
    },
}

// The layout half of `settings`, which the looks from before these existed
// don't state. Filled in rather than left out so picking any look sets all
// of them -- otherwise leaving a bottom-bar look for one of those would keep
// the bar at the bottom.
var settingsBase = {
    barPosition: "top",
    workspaceStyle: "pills",
    clockStyle: "stamp",
    windowStyle: "icons",
    windowScope: "workspace",
    windowMark: "pill",
    iconTint: "colour",
    shadow: "none",
    vizStyle: "mirror",
    flyoutAnim: "drop",
    flyoutAttach: "flush",
    flyoutTitle: "none",
    launcherLayout: "list",
    launcherPosition: "centre",
    launcherDetails: true,
    notifStyle: "full",
    notifStripe: false,
    barSeparator: "none",
    hoverStyle: "none",
    altTabStyle: "icons",
    overviewLayout: "grid",
    overviewBackdrop: "dim",
    powerStyle: "row",
    levelStyle: "pill",
    headingFont: "",
    textWeight: "regular",
    boldWeight: "bold",
    gradient: false,
    gaugeStyle: "fill",
}

// The parts of the fixed half the Appearance page can also adjust. The look
// states them where they always were; they're copied into `settings` in the
// units Settings stores (percentages, "" for no accent), so picking the look
// sets them like the rest, and Reset look puts them back.
function adjustable(look) {
    var h = look.heading
    return {
        accent: look.accent || "",
        accent2: look.accent2 || "",
        panelOpacity: Math.round(look.panelOpacity * 100),
        borderWidth: look.borderWidth,
        scrim: Math.round(look.scrim * 100),
        headingUpper: h.upper, headingBold: h.bold, headingRule: h.rule, headingAccent: h.accent,
    }
}

// a look with its fixed half filled in from `base`, and its settings from
// `settingsBase` and adjustable()
function complete(look) {
    for (var b in base)
        if (look[b] === undefined) look[b] = base[b]
    for (var s in settingsBase)
        if (look.settings[s] === undefined) look.settings[s] = settingsBase[s]
    var a = adjustable(look)
    for (var k in a)
        if (look.settings[k] === undefined) look.settings[k] = a[k]
    // the panels' and the bar's corners follow `radius` unless stated
    for (var r of ["panelRadius", "barRadius"])
        if (look.settings[r] === undefined) look.settings[r] = look.settings.radius
    return look
}
complete(looks[fallback])

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

// Faces headings can be set in besides the monospace ones above: a serif and
// two sans, each in a package pacman.txt installs.
var headingFonts = ["Noto Serif", "Noto Sans", "Ubuntu Nerd Font"]

// The system font: what GTK and Qt apps draw everywhere outside the shell
// itself (AppearanceSync.renderGtk/renderQt) -- independent of `fonts` above,
// which is the shell's own monospace-only face. Proportional, general-purpose
// faces only, each one a package pacman.txt already installs, so every entry
// here is always selectable. The first is the fallback.
var systemFonts = ["Ubuntu Nerd Font", "Noto Sans"]
var systemFontLabels = {
    "Ubuntu Nerd Font": "Ubuntu", "Noto Sans": "Noto Sans",
}

// Density, as a factor on every gap and padding (Theme.sp) and, at half
// strength, on row heights (Theme.row) -- so compact rows tighten a little
// while the space between them tightens more.
var densities = { compact: 0.75, normal: 1, roomy: 1.3 }
