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
//   Settings     what the Appearance page edits -- the style (Styles.js),
//                roundness, bar shape, density, font, accent, colour mode --
//                seeded by the look
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
import "Styles.js" as Styles

Singleton {
    id: root

    // --- the look ------------------------------------------------------------

    readonly property string lookName: LookStore.looks[Settings.look] ? Settings.look : Looks.fallback
    readonly property var look: LookStore.looks[lookName]

    // Everything the style and the dials beside it decide (Styles.resolve)
    readonly property var resolved: Styles.resolve({
        style: Settings.style, radius: Settings.radius, barStyle: Settings.barStyle,
        density: Settings.density, seeThrough: Settings.seeThrough, shadows: Settings.shadows,
        heavyLines: Settings.heavyLines, flyoutAnim: Settings.flyoutAnim })
    readonly property string style: Settings.style

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

    // Whether the ramp reads as a light theme overall -- some looks (and the
    // wallpaper palette, on a pale image) run light rather than dark. Base is
    // the deepest ground in a dark look and the palest in a light one, so its
    // own lightness is the one signal that always tells the two apart.
    readonly property bool isLight: base.hslLightness > 0.5

    // The only hues that don't follow the wallpaper, and deliberately so:
    // charging and critical are states you want to catch without reading
    // anything, and a red or green wallpaper would otherwise camouflage them.
    readonly property color good:    look.good
    readonly property color alert:   look.alert

    // The look's one hue, for marks rather than text: selection ticks, focus
    // strokes, the current item, and meters in looks that ask for it. In
    // wallpaper mode it's the wallpaper's primary tone (the ramp's bright).
    readonly property bool hasAccent: Settings.accent !== "" && Settings.colourMode !== "wallpaper"
    readonly property color accent: hasAccent ? Settings.accent : bright

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
    // Text on an accent fill: white, unless the accent is so bright that
    // white wouldn't read (by perceived brightness; HSL lightness calls a
    // mid blue like #5555c8 light). Not named onAccent: QML reads an
    // on<Name> property as a signal handler, and it always came back black.
    readonly property color textOnAccent: 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b > 0.65 ? "#111111" : "#ffffff"
    // the inner half of a double frame
    readonly property color frameStroke:   muted
    // a field's ground: inputs, key-capture boxes
    readonly property color fieldFill:     surface
    // Glass draws one light hairline instead of the ramp's border
    readonly property bool glass: resolved.glass
    readonly property color stroke: glass ? (isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.14)) : border
    readonly property color strokeHover:   muted
    readonly property color strokeFocus:   hasAccent ? accent : subtext
    readonly property color textDisabled:  muted
    // Meters: gauges, sliders, progress and level bars
    readonly property color meterTrack:    base
    readonly property color meterStroke:   surface
    // Level colour: meters, sliders and the bar's level chips
    readonly property color meterFill:     Settings.levelColour === "good" ? good
        : Settings.levelColour === "text" ? text : accent
    readonly property color gaugeFill:     meterFill
    // text on a level-colour fill, chosen as textOnAccent is
    readonly property color textOnMeter: 0.299 * meterFill.r + 0.587 * meterFill.g + 0.114 * meterFill.b > 0.65 ? "#111111" : "#ffffff"
    // the dimming behind full-screen overlays
    readonly property color scrim:         Qt.rgba(0, 0, 0, Settings.scrim / 100)
    // Flyouts', windows' and cards' ground, and the bar's: See-through, and
    // further under Glass. The desktop shows through only where Hyprland
    // blurs or nothing's behind.
    readonly property real panelOpacity:   resolved.opacity / 100
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
    // fixed-height rows. AppearanceSync carries the same factor to wofi.
    readonly property real fontScale: Settings.fontSize / Settings.fontSizeBase

    function fs(n) { return Math.round(n * fontScale) }

    // The bar's labels, glyphs and icons, which follow Font size too
    function barFs(n) { return fs(n) }

    // The type scale. Everything with text uses one of these rather than a
    // size of its own, so a label reads the same size in every flyout and
    // window. Pixel sizes, not point: points scale with the screen's DPI
    // while the rows and chips around them are laid out in pixels.
    readonly property int fontEyebrow:  fs(11)   // the spaced-out line over a window's title
    readonly property int fontCaption:  fs(12)   // a row's second line, key hints
    readonly property int fontSmall:    fs(14)   // headings, captions, secondary lines
    readonly property int fontBody:     fs(16)   // labels, values, chips, inputs
    readonly property int fontIconSize: fs(16)   // Nerd Font glyphs inside rows
    readonly property int fontTitle:    fs(22)   // a flyout's headline figure (temperature)
    readonly property int fontDisplay:  fs(26)   // placeholder art glyphs
    readonly property int fontHero:     fs(34)   // the one big glyph a flyout leads with

    // Section headings (FlyoutHeading and its kin). Headings are written in
    // caps in the source; title-case looks lower them with heading().
    readonly property bool headingBold:    true
    readonly property bool headingUpper:   Settings.headingUpper
    readonly property real headingSpacing: headingUpper ? 1 : 0
    readonly property bool headingRule:    Settings.headingRule
    readonly property color headingColor:  bright
    // drawn in the accent before every heading, "" for none
    readonly property string headingPrefix: resolved.headingPrefix
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

    readonly property int radius:      resolved.radius
    // flyouts, windows, cards and wofi; and a floating bar or islands
    readonly property int panelRadius: resolved.panelRadius
    readonly property int barRadius:   resolved.barRadius
    // One step in from the outer stroke. Floored at 0 because the radius is
    // user-settable down to square, and a negative radius draws nothing.
    readonly property int radiusInner: Math.max(0, radius - 2)
    // small controls inside a row: stepper buttons, drag handles
    readonly property int radiusSmall: Math.max(0, radius - 3)
    // "double" draws a second stroke inset inside panels and bar modules.
    // "single" is the outer stroke alone. "bevel" is Win95's chiselled 3D
    // edge (see Bevel.qml) instead of either. "none" draws no stroke at all
    // -- the ground colour alone marks the edge.
    readonly property string frameStyle: resolved.frameStyle
    readonly property bool frameDouble: frameStyle === "double"
    readonly property bool frameBevel:  frameStyle === "bevel"
    readonly property bool frameNone:   frameStyle === "none"
    // "channel": an outer line, a dark groove, an inner line; lit states
    // light the groove in the accent (Channel.qml)
    readonly property bool frameChannel: frameStyle === "channel"
    // bevel: drawn with Bevel pairs rather than a border
    readonly property bool frameChiselled: frameBevel
    // every style but these draws the plain outer stroke
    readonly property bool frameStroked: !frameChiselled && !frameNone

    // The channel's three bands, outside in: the outer line, the groove,
    // the inner line. channelWidth is all of them, the first clear pixel.
    readonly property color channelOuter: muted
    readonly property color channelGroove: base
    readonly property color channelInner: border
    readonly property int channelGrooveWidth: 2
    readonly property int channelWidth: borderWidth * 2 + channelGrooveWidth
    // where a channel's width changes (a flyout grown out of its bar
    // group), the inside corner is rounded by this
    readonly property int channelFillet: 7
    // a channel-framed panel's corners: the panel radius out past the bands,
    // or square when Roundness is 0 (Hyprland's windows follow this)
    readonly property int channelPanelRadius: panelRadius > 0 ? panelRadius + frameInset + channelWidth : 0
    // a panel's outer corners in the current frame style, which Hyprland's
    // window rounding follows (AppearanceSync)
    readonly property int panelFrameRadius: frameChannel ? channelPanelRadius : panelRadius
    // A control's own stroke inside a panel (chips, fields, steppers,
    // cards), given the colour its state asks for: kept for the stroked
    // styles, dropped under Bevel -- ControlEdge.qml draws its edge -- and
    // under None kept only where a lit or focused state shows.
    function controlBorder(c) {
        if (frameStroked) return borderWidth
        if (frameChiselled) return 0
        return Qt.colorEqual(c, stroke) || Qt.colorEqual(c, "transparent") ? 0 : borderWidth
    }
    function controlStroke(c) {
        if (frameChannel && Qt.colorEqual(c, stroke)) return channelOuter
        if (frameChannel && Qt.colorEqual(c, strokeHover)) return subtext
        return c
    }
    // Under None a control with no ground of its own would vanish, so it
    // gets the field's.
    function controlFill(c) {
        return frameNone && Qt.colorEqual(c, "transparent") ? fieldFill : c
    }
    readonly property int borderWidth: resolved.borderWidth
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
    readonly property real densityHalf: 1 + (density - 1) / 2
    function row(n) { return Math.round(fs(n) * densityHalf) }
    // A box that holds text -- a flyout's or a window's size, a label
    // column. Grows with roomy, whose padding would otherwise eat into it,
    // but never shrinks with compact: the text inside doesn't get smaller,
    // so a narrower box would only elide it.
    function fit(n) { return Math.round(fs(n) * Math.max(1, densityHalf)) }

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
    // kept free beside a scrolling page for its ScrollBar
    readonly property int scrollGutter: sp(10)
    // The size Settings and System open at: the Normal-density layout with
    // a 600px body, scaled by Font Size only. A window sized by its
    // content was centred for its first frame and hung off-centre once a
    // list loaded in, and one sized by density changed size under you.
    // Density re-lays out the inside instead. Each is rebuilt on every open
    // (LazyWindow.qml), so a size you drag one to lasts until it closes.
    readonly property size windowSize: Qt.size(fs(1044), fs(755))
    // between a flyout and the screen edge it's clamped against
    readonly property int edgeMargin: 6

    // Control heights. Every text-bearing control is one of these, so a chip
    // beside a stepper beside a row all line up.
    readonly property int rowHeight:      row(24)   // list rows, steppers
    readonly property int rowHeightDense: row(22)   // packed lists: packages, gauges, calendar days
    readonly property int rowHeightTall:  row(26)   // action rows, inputs
    readonly property int fieldHeight:    row(28)   // settings fields, section rows
    readonly property int chipHeight:     row(20)   // chips, segmented strips
    readonly property int controlSize:    chipHeight // square +/-, icon buttons
    // on/off switches (Switch.qml)
    readonly property int switchWidth:   row(28)
    readonly property int switchHeight:  row(16)
    readonly property int headingHeight: fs(16)
    // the faint surface a window's framed panels sit on (WindowPanel.qml)
    readonly property color panelTint: Qt.rgba(surface.r, surface.g, surface.b, 0.35)
    // the scrim a caption bar sits on over an image, so its text reads
    // whatever's behind it (the Appearance wallpaper preview)
    readonly property color captionScrim: Qt.rgba(base.r, base.g, base.b, 0.75)
    // the column an icon sits in at the start of a row
    readonly property int iconCell:      fs(20)

    // --- motion ----------------------------------------------------------------

    // Animation time. Every duration goes through dur(); at 0 they're all
    // zero, which Qt treats as an instant jump. A look can also opt out of
    // motion entirely (its `motion` factor).
    readonly property real animFactor: look.motion * Settings.animTime / 100
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
    readonly property int barHeight:  resolved.barHeight
    // A floating bar sits inset from the screen edges on its own rounded,
    // stroked ground; barMargin is that inset, the same gap the windows keep
    // from the screen's edges (Settings.edgeGap). barExtent is how far from the
    // screen edge anything anchored to the bar (flyouts, toasts) starts --
    // with a floating bar, the same gap again below it.
    //
    // Islands are inset the same way, each group of modules on its own
    // floating ground instead of one bar.
    readonly property bool barFloating: Settings.barStyle === "floating"
    readonly property bool barIslands:  Settings.barStyle === "islands"
    readonly property bool barFull:     !barFloating && !barIslands
    readonly property int barMargin:  barFull ? 0 : Settings.edgeGap
    readonly property int barExtent:  barHeight + barMargin * 2
    // between the bar's (or an island's) edge and its outermost module
    readonly property int barInset: barFloating ? spaceXs : barIslands ? spaceM
        : moduleGrouped ? channelWidth + 1 : 0
    // the workspace indicator and clock chip styles -- see Looks.js
    readonly property string workspaceStyle: Settings.workspaceStyle
    // what the Names style calls each workspace, "" where it has none
    readonly property var workspaceNames: Settings.workspaceNames.split(",").map(s => s.trim())
    readonly property string clockStyle: Settings.clockStyle
    // the Control Centre button's glyph
    readonly property string controlGlyph: ({
        arch: "󰣇", menu: "󰍜", dashboard: "󰕮", cog: "󰒓", home: "󰋜", star: "󰓎",
    })[Settings.controlIcon] || "󰣇"
    // the open-windows strip and app icons in the bar -- see Looks.js
    readonly property string windowStyle: Settings.windowStyle
    readonly property string windowScope: Settings.windowScope
    readonly property string windowMark: resolved.windowMark
    readonly property string iconTint: Settings.iconTint
    // under panels and solid chips -- see Looks.js and flyouts/Shadow.qml
    readonly property string shadow: resolved.shadow
    readonly property int shadowOffset: Math.max(3, borderWidth * 2)
    // the bar's audio visualizer -- see Looks.js
    readonly property string vizStyle: Settings.vizStyle
    // how a gauge chip shows its level -- see Looks.js and ModuleFrame
    readonly property string gaugeStyle: resolved.gaugeStyle
    // a top-to-bottom shading on grounds -- see Looks.js
    readonly property bool gradient: Settings.gradient
    function shadeTop(c) { return Qt.tint(c, Qt.rgba(1, 1, 1, isLight ? 0.35 : 0.06)) }
    function shadeBottom(c) { return Qt.tint(c, Qt.rgba(0, 0, 0, isLight ? 0.06 : 0.12)) }
    // the weights text and its emphasis are set in -- see Looks.js
    readonly property int weightBody: Looks.fontWeights[fontText] === "bold" ? Font.Bold : Font.Normal
    readonly property int weightStrong: Font.Bold
    // section headings' face -- see Looks.js
    readonly property string fontHeading: fontText
    // the volume/brightness popup -- see Looks.js and LevelToast
    readonly property string levelStyle: Settings.levelStyle
    // the power menu -- see Looks.js and PowerMenu
    readonly property string powerStyle: Settings.powerStyle
    readonly property string overviewBackdrop: Settings.overviewBackdrop
    // the workspace overview -- see Looks.js and WorkspaceOverlay
    readonly property string overviewLayout: Settings.overviewLayout
    // the ALT+Tab switcher -- see Looks.js and AltTabSwitcher
    readonly property string altTabStyle: Settings.altTabStyle
    // a bar module under the pointer -- see Looks.js and ModuleFrame
    readonly property string hoverStyle: resolved.hoverStyle
    // between the bar's modules, and the room each gap takes with one
    readonly property string barSeparator: Settings.barSeparator
    readonly property int moduleSpacing: moduleGap + (barSeparator === "none" ? 0 : spaceL)
    // notification popups -- see Looks.js and NotificationCard
    readonly property string notifStyle: Settings.notifStyle
    readonly property bool launcherDetails: Settings.launcherDetails
    readonly property string launcherPosition: Settings.launcherPosition
    // the launcher -- see Looks.js and flyouts/Launcher.qml
    readonly property string launcherLayout: Settings.launcherLayout
    readonly property string flyoutTitle: resolved.flyoutTitle
    readonly property string flyoutAttach: resolved.flyoutAttach
    // how flyouts open and where they sit -- see Looks.js and FlyoutPanel
    readonly property string flyoutAnim: resolved.flyoutAnim
    // A Qt date format with its 24-hour fields turned 12-hour when Date &
    // Time asks for that; every clock in the shell formats through this.
    function hours(fmt) {
        return Settings.clock24 ? fmt : fmt.replace(/HH:mm(:ss)?/g, "h:mm$1 AP")
    }
    readonly property string timeFormat: hours("HH:mm")
    // how the bar's chips are drawn -- see Looks.js
    readonly property string moduleStyle: resolved.moduleStyle
    // "grouped": each section of the bar is one channel (shell.qml), and
    // its modules are bare chips inside it, sized to the channel's interior
    readonly property bool moduleGrouped: moduleStyle === "grouped"
    readonly property int groupHeight: moduleHeight + 2
    readonly property int groupRadius: radius > 0 ? radius + channelWidth : 0
    // "grown": a flyout hangs off its module's group, one outline round both
    readonly property bool flyoutGrown: flyoutAttach === "grown" && moduleGrouped && frameChannel
    // Distance from the bar's screen edge to a flyout's near edge: flush lays
    // the box's stroke over the bar's own edge line, floating leaves a gap.
    // Measured to the bar itself, not barExtent, which adds a floating bar's
    // gap below it again.
    readonly property real flyoutOffset: barHeight + barMargin - borderWidth
        + (flyoutAttach === "floating" ? spaceM + borderWidth : 0)

    readonly property real barOpacity: panelOpacity
    // Derived from the bar rather than fixed, so a taller bar gets taller
    // chips instead of a 28px chip swimming in it. The -6 reproduces the
    // original 28 at the default 34, and the floor keeps the double border
    // from eating the whole chip at the smallest bar height.
    readonly property int moduleHeight: Math.max(18, barHeight - 6)
    // brackets hug their content, and leave the gap between chips instead,
    // so neighbours read "[a] [b]" rather than "[ a ][ b ]"
    readonly property int modulePadH:   moduleStyle === "bracket" ? sp(2) : sp(6)
    // gap between adjacent modules, the same on both sides of the bar
    readonly property int moduleGap:    resolved.moduleGap + (moduleStyle === "bracket" ? spaceS : 0)
    // Shared width for the gauge modules only, so their fill bars are
    // directly comparable. The icon-only chips hug their content instead --
    // padding them out to match would just add dead space.
    // Segments sit beside the icon rather than under it, so they get the
    // room of a whole icon more.
    readonly property int moduleWidth:  gaugeStyle === "segments" ? 76 : 54
    // The double frame eats 8px of the chip (outer stroke + a 2px-inset inner
    // one), so the icon is sized to the space left inside it. Capped to the
    // chip, so a large Font Size can't push icons out of it.
    readonly property int iconSize:     Math.min(moduleHeight - 8, barFs(17))
    // one size for every bar label (clock, media, counts), capped the same way
    readonly property int barLabelSize: Math.min(moduleHeight - 8, barFs(15))
}
