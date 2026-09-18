// Singularity - Quickshell
// ~/.config/quickshell/services/Theme.qml
//
// The one stylesheet. Colour, type, shape, spacing and motion for every bar
// module, flyout, window and settings page come from here, so they agree
// without any file carrying its own copy of a value -- and so swapping the
// look (Looks.js) restyles all of it at once.
//
// A Quickshell Singleton rather than properties on the bar: the flyout
// components are separate files and have no way to reach into the bar's
// scope, and passing a palette down through every instantiation is worse
// than one import-free global.
//
// Three layers, most specific wins:
//   LookStore    the active look's palette and fixed style (see Looks.js)
//   Settings     what the Appearance page edits -- radius, bar geometry,
//                frame, density, font, colour mode -- seeded by the look
//   this file    semantic roles derived from both. Components ask for
//                Theme.hoverFill, not Theme.overlay, so a look can remap
//                what "hovered" means without touching any component.
//
// Rules for components:
//   - no hex colours, font families or pixel sizes of their own
//   - colours by semantic role where one exists, raw ramp role otherwise
//   - text sizes from the type scale, row heights through row(), gaps and
//     padding through sp() or the named steps, durations through dur()

pragma Singleton

import Quickshell
import QtQuick
import "Looks.js" as Looks

Singleton {
    id: root

    // --- the look ------------------------------------------------------------

    readonly property string lookName: LookStore.looks[Settings.look] ? Settings.look : Looks.fallback
    readonly property var look: LookStore.looks[lookName]

    // The look's own ramp. In wallpaper colour mode each role is swapped for
    // the matching tone from the wallpaper's palette (see Wallpaper.qml);
    // until one exists, or in grayscale mode, it's these.
    readonly property var gray: look.palette
    readonly property var roles: Settings.colourMode === "wallpaper" && Wallpaper.palette
        ? Wallpaper.palette : gray

    // --- palette: the ramp, darkest to brightest ------------------------------

    readonly property color base:    roles.base
    readonly property color bar:     roles.bar
    // the flyouts' ground, a step above the bar
    readonly property color panel:   roles.panel
    readonly property color surface: roles.surface
    readonly property color overlay: roles.overlay
    readonly property color border:  roles.border
    readonly property color muted:   roles.muted
    readonly property color subtext: roles.subtext
    readonly property color text:    roles.text
    readonly property color bright:  roles.bright

    // The only hues that don't follow the wallpaper, and deliberately so:
    // charging and critical are states you want to catch without reading
    // anything, and a red or green wallpaper would otherwise camouflage them.
    readonly property color good:    look.good
    readonly property color alert:   look.alert

    // The look's one hue, for marks rather than text: selection ticks, focus
    // strokes, the current item, and meters in looks that ask for it. In
    // wallpaper mode it's the wallpaper's primary tone (the ramp's bright).
    readonly property bool hasAccent: !!look.accent && Settings.colourMode !== "wallpaper"
    readonly property color accent: hasAccent ? look.accent : bright

    // --- semantic colours -----------------------------------------------------
    // What each state looks like, named for the state. Components use these
    // in preference to the ramp roles above.

    // emphasised text: values, titles, hovered labels
    readonly property color textStrong:    bright
    // a row or button under the pointer
    readonly property color hoverFill:     overlay
    // a smaller control under the pointer, or a chip/tab that's lit
    readonly property color hoverFillSoft: surface
    readonly property color selectedFill:  overlay
    readonly property color selectedStroke: hasAccent ? accent : muted
    // the inner half of a double frame
    readonly property color frameStroke:   muted
    // a field's ground: inputs, key-capture boxes
    readonly property color fieldFill:     surface
    readonly property color stroke:        border
    readonly property color strokeHover:   muted
    readonly property color strokeFocus:   hasAccent ? accent : subtext
    readonly property color textDisabled:  muted
    // Meters: gauges, sliders, progress and level bars
    readonly property color meterTrack:    base
    readonly property color meterStroke:   surface
    readonly property color meterFill:     look.meterAccent && hasAccent ? accent : text
    // the dimming behind full-screen overlays
    readonly property color scrim:         Qt.rgba(0, 0, 0, look.scrim)
    // Flyouts', windows' and cards' ground, translucent in glassy looks. The
    // desktop shows through only where Hyprland blurs or nothing's behind.
    readonly property real panelOpacity:   look.panelOpacity
    readonly property color panelFill:     Qt.rgba(panel.r, panel.g, panel.b, panelOpacity)

    // --- type ------------------------------------------------------------------

    // One font for text and icons alike, so no icon is drawn by fallback at
    // another font's metrics. Always a NON-Mono Nerd Font variant: "Nerd
    // Font Mono" forces every icon into one terminal cell -- at 18px it draws
    // all of them 9px wide, squeezing a 17px glyph by half while leaving a
    // 9px one alone, which is what makes a row of icons look mismatched.
    readonly property string fontText: Fonts.resolve(Settings.fontFamily)
    readonly property string fontIcon: fontText

    // Font Size, as a factor of the 16px base. Every font size and every
    // text-bearing row height in the shell goes through fs(), so text and the
    // rows holding it grow together instead of larger text clipping in
    // fixed-height rows. AppearanceSync carries the same factor to wofi and
    // swaync.
    readonly property real fontScale: Settings.fontSize / Settings.fontSizeBase

    function fs(n) { return Math.round(n * fontScale) }

    // The type scale. Everything with text uses one of these rather than a
    // size of its own, so a label reads the same size in every flyout and
    // window. Pixel sizes, not point: points scale with the screen's DPI
    // while the rows and chips around them are laid out in pixels.
    readonly property int fontSmall:    fs(14)   // headings, captions, secondary lines
    readonly property int fontBody:     fs(16)   // labels, values, chips, inputs
    readonly property int fontLarge:    fs(19)   // the odd emphasised glyph (calendar arrows)
    readonly property int fontIconSize: fs(16)   // Nerd Font glyphs inside rows
    readonly property int fontTitle:    fs(22)   // a flyout's headline figure (temperature)
    readonly property int fontDisplay:  fs(26)   // placeholder art glyphs
    readonly property int fontHero:     fs(34)   // the one big glyph a flyout leads with

    // Section headings (FlyoutHeading and its kin). Headings are written in
    // caps in the source; title-case looks lower them with heading().
    readonly property bool headingBold:    look.heading.bold
    readonly property real headingSpacing: look.heading.spacing
    readonly property bool headingUpper:   look.heading.upper
    readonly property bool headingRule:    look.heading.rule
    readonly property color headingColor:  look.heading.accent && hasAccent ? accent : bright
    // acronyms title case leaves alone
    readonly property var headingKeep: ["AUR", "CPU", "GPU", "RAM", "MEM", "IP", "DND", "USB",
                                        "HDMI", "VPN", "UI", "SSD", "OS", "WIFI"]
    function heading(t) {
        if (headingUpper) return String(t).toUpperCase()
        return String(t).split(/(\s+)/).map(w => {
            if (headingKeep.indexOf(w.replace(/[^A-Za-z]/g, "").toUpperCase()) !== -1) return w.toUpperCase()
            var lw = w.toLowerCase()
            return lw.charAt(0).toUpperCase() + lw.slice(1)
        }).join("")
    }


    // --- shape -----------------------------------------------------------------

    readonly property int radius:      Settings.radius
    // One step in from the outer stroke. Floored at 0 because the radius is
    // user-settable down to square, and a negative radius draws nothing.
    readonly property int radiusInner: Math.max(0, radius - 2)
    // small controls inside a row: stepper buttons, drag handles
    readonly property int radiusSmall: Math.max(0, radius - 3)
    // "double" draws a second stroke inset inside panels and bar modules --
    // the Neutrino signature. "single" is the outer stroke alone. "bevel" is
    // Win95's chiselled 3D edge (see Bevel.qml) instead of either. "none"
    // draws no stroke at all -- the ground colour alone marks the edge.
    readonly property bool frameDouble: Settings.frameStyle === "double"
    readonly property bool frameBevel:  Settings.frameStyle === "bevel"
    readonly property bool frameNone:   Settings.frameStyle === "none"
    readonly property int borderWidth: look.borderWidth
    // how far the inner stroke sits inside a panel's outer one
    readonly property int frameInset:  3
    // The bevel's own highlight/shadow pair, for looks that ask for one.
    // Looks that don't (bevel: null) get a computed pair off the border
    // colour, so frameBevel never has to be a look-specific escape hatch --
    // any look can be switched to it from the Appearance page.
    readonly property var bevel: look.bevel || { light: Qt.lighter(border, 1.8), dark: Qt.darker(border, 1.8) }
    readonly property color bevelLight: bevel.light
    readonly property color bevelDark:  bevel.dark
    // the left-edge bar marking the current row in a list
    readonly property int indicatorWidth: 2
    readonly property int meterHeight: 6

    // --- spacing ---------------------------------------------------------------

    readonly property real density: Looks.densities[Settings.density] || 1
    function sp(n) { return Math.round(n * density) }
    // A text-bearing row: scaled with the font, and with density at half
    // strength so compact rows tighten without clipping their text.
    function row(n) { return Math.round(fs(n) * (1 + (density - 1) / 2)) }

    // the steps every gap and padding is picked from
    readonly property int spaceXs:  sp(2)
    readonly property int spaceS:   sp(4)
    readonly property int spaceM:   sp(6)
    readonly property int spaceL:   sp(8)
    readonly property int spaceXl:  sp(12)
    readonly property int spaceXxl: sp(16)
    // inside a flyout's frame, and inside a window's
    readonly property int panelPad:  sp(10)
    readonly property int windowPad: sp(16)
    // between a flyout and the screen edge it's clamped against
    readonly property int edgeMargin: 6

    // Control heights. Every text-bearing control is one of these, so a chip
    // beside a stepper beside a row all line up.
    readonly property int rowHeight:     row(24)   // list rows, steppers
    readonly property int rowHeightTall: row(26)   // action rows, inputs
    readonly property int fieldHeight:   row(28)   // settings fields, nav rows
    readonly property int chipHeight:    fs(20)
    readonly property int controlSize:   fs(18)    // square +/- and close buttons
    readonly property int headingHeight: fs(16)
    // the column an icon sits in at the start of a row
    readonly property int iconCell:      fs(20)

    // --- motion ----------------------------------------------------------------

    // Animation Speed. Every duration goes through dur(); "off" makes them
    // all zero, which Qt treats as an instant jump. A look can also opt out
    // of motion entirely (its `motion` factor).
    readonly property real animFactor: look.motion * (Settings.animSpeed === "off" ? 0
        : Settings.animSpeed === "fast" ? 0.5 : 1)
    function dur(ms) { return Math.round(ms * animFactor) }
    // named steps: colour and hover changes / things appearing / meters filling
    readonly property int durFast:   dur(110)
    readonly property int durMedium: dur(150)
    readonly property int durSlow:   dur(250)
    // The pulse on something busy, one half-cycle. Not scaled: it's a status
    // signal rather than motion, and at 0 an infinite loop would just spin.
    readonly property int durPulse:  600

    readonly property int ease: Easing.OutCubic

    // --- the bar ---------------------------------------------------------------

    // One source of truth for the bar's geometry: the flyouts anchor to
    // barHeight to sit flush under it, and the icons size off it, so
    // changing the bar's height moves everything together.
    //
    // The values the Appearance page can change come from Settings, which
    // persists them. They stay readonly here because nothing should write
    // them through Theme -- Settings.set() is the one way in, and it clamps.
    readonly property string barPosition: Settings.barPosition
    readonly property int barHeight:  Settings.barHeight
    // A floating bar sits inset from the screen edges on its own rounded,
    // stroked ground; barMargin is that inset. barExtent is how far from the
    // screen edge anything anchored to the bar (flyouts, toasts) starts --
    // with a floating bar, the same gap again below it.
    readonly property bool barFloating: Settings.barStyle === "floating"
    readonly property int barMargin:  barFloating ? 6 : 0
    readonly property int barExtent:  barHeight + barMargin * 2
    // "outline", "filled", "flat" or "pill" -- see Looks.js
    readonly property string moduleStyle: Settings.moduleStyle

    readonly property real barOpacity: Settings.barOpacity / 100
    // Derived from the bar rather than fixed, so a taller bar gets taller
    // chips instead of a 28px chip swimming in it. The -6 reproduces the
    // original 28 at the default 34, and the floor keeps the double border
    // from eating the whole chip at the smallest bar height.
    readonly property int moduleHeight: Math.max(18, barHeight - 6)
    readonly property int modulePadH:   sp(8)
    // gap between adjacent modules, the same on both sides of the bar
    readonly property int moduleGap:    Settings.moduleGap
    // Shared width for the gauge modules only, so their fill bars are
    // directly comparable. The icon-only chips hug their content instead --
    // padding them out to match would just add dead space.
    readonly property int moduleWidth:  54
    // The double frame eats 8px of the chip (outer stroke + a 2px-inset inner
    // one), so the icon is sized to the space left inside it. Capped to the
    // chip, so a large Font Size can't push icons out of it.
    readonly property int iconSize:     Math.min(moduleHeight - 8, fs(17))
    // one size for every bar label (clock, media, counts), capped the same way
    readonly property int barLabelSize: Math.min(moduleHeight - 8, fs(15))
}
