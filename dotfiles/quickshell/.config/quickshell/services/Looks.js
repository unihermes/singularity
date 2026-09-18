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
//   qs ipc call look cycle        qs ipc call look set terminal
//
// A look has two halves:
//
//   settings  -- the values the Appearance page can also change: radius, the
//                bar's height/gap/opacity/style, module style, frame style,
//                density, font. Picking a look writes these into Settings;
//                after that they're the user's to adjust, and the look only
//                comes back on a re-pick.
//   the rest  -- fixed per look:
//     palette        the ten-role ramp (see below)
//     accent         the one hue for marks: selection ticks, focus, current
//                    items, and meters when meterAccent. null = the ramp's
//                    bright, i.e. a colourless look
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
//
// The style switches in `settings`:
//     moduleStyle  "outline"  stroked chips (the double frame applies here)
//                  "filled"   solid chips, no stroke
//                  "flat"     bare glyphs; the active one is underlined
//                  "pill"     solid, fully rounded
//     barStyle     "full"     edge to edge, a hairline on its inner edge
//                  "floating" inset from the screen edges, rounded, stroked
//     frameStyle   "double"   a second stroke inset inside the outer one
//                  "single"   the outer stroke alone
//                  "bevel"    a raised 3D edge outside, a sunken one inside --
//                             Windows 95's chrome
//
// Adding a look: copy an entry in looks.json and rename its key. Every key in
// `settings` and `palette` must be present; the rest of the fixed half falls
// back to `base` below. Fonts must be installed (fc-list : family); the
// families here are all in packages/.

//
// The palette's roles are semantic, not literal lightness: base is the most
// recessed ground (meter tracks), panel the flyouts' ground, overlay a hover
// fill, border a stroke, text/bright the foreground. A light look simply
// makes the grounds light and the foreground dark -- text on `panel` must
// read, `border` must show on `panel`, `bright` must stand out from `text`. Colour mode "wallpaper" swaps these
// ten for tones from the image (Wallpaper.qml) and keeps the rest.

.pragma library

// the look that can't be removed, and the one used when the chosen look is gone
var fallback = "neutrino"

// shared defaults for the fixed half, so each look only states what differs
var base = {
    accent: null,
    borderWidth: 1,
    panelOpacity: 1,
    meterAccent: false,
    heading: { upper: true, bold: true, spacing: 1, rule: true, accent: false },
    bevel: null,
    scrim: 0.4,
    motion: 1,
}

var looks = {
    neutrino: {
        name: "Neutrino",
        description: "Grayscale, double-stroked frames, tight spacing",
        palette: {
            base: "#0b0b0b", bar: "#121212", panel: "#141414", surface: "#1a1a1a", overlay: "#242424",
            border: "#303030", muted: "#4d4d4d", subtext: "#7a7a7a", text: "#c2c2c2", bright: "#ebebeb",
        },
        // desaturated hard, so they read as a tinted grey rather than alerts
        good: "#7d9b7d", alert: "#a87676",
        settings: {
            radius: 6, barHeight: 34, moduleGap: 2, barOpacity: 100,
            frameStyle: "double", density: "normal", fontFamily: "UbuntuMono Nerd Font",
            moduleStyle: "outline", barStyle: "full",
        },
    },
}

// a look with its fixed half filled in from `base`
function complete(look) {
    for (var b in base)
        if (look[b] === undefined) look[b] = base[b]
    return look
}
complete(looks[fallback])

// The look the template stylesheets (wofi, swaync) are written in: their
// hexes are this ramp, and AppearanceSync maps each one to the current role.
var reference = "neutrino"

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

// Density, as a factor on every gap and padding (Theme.sp) and, at half
// strength, on row heights (Theme.row) -- so compact rows tighten a little
// while the space between them tightens more.
var densities = { compact: 0.75, normal: 1, roomy: 1.3 }
