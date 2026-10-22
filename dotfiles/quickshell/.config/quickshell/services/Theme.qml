// Singularity - Quickshell
// ~/.config/quickshell/services/Theme.qml
//
// The one stylesheet: colour, type, shape, spacing and motion for the whole
// shell. Layers, most specific wins: the look (Looks.js), what Appearance
// sets (Settings, the style in Styles.js), and the semantic roles here.
// Components use roles (hoverFill, not overlay), the type scale, row(),
// sp()/named steps and dur(); never their own hex, font or pixel sizes.

pragma Singleton

import Quickshell
import QtQuick
import "Looks.js" as Looks
import "Styles.js" as Styles

Singleton {
    id: root

    // --- the look ------------------------------------------------------------

    readonly property string lookName: Looks.looks[Settings.look] ? Settings.look : Looks.fallback
    readonly property var look: Looks.looks[lookName]

    // what the style and its dials decide (Styles.resolve)
    readonly property var resolved: Styles.resolve({
        style: Settings.style, styleOptions: Settings.styleOptions, radius: Settings.radius, barStyle: Settings.barStyle,
        barHeight: Settings.barHeight, spacing: Settings.spacing, seeThrough: Settings.seeThrough, shadows: Settings.shadows,
        heavyLines: Settings.heavyLines, flyoutAnim: Settings.flyoutAnim, barChips: Settings.barChips })
    // the style in force
    readonly property string style: resolved.styleName
    // one of the style's own options, on or off
    function opt(id) { return Styles.has(Settings.styleOptions, id) }

    // The look's ramp, with Appearance's per-role overrides in grayscale,
    // or the wallpaper's palette in wallpaper mode.
    readonly property var gray: {
        var p = look.palette, out = {}
        for (var r in p) {
            var v = Settings["palette" + r.charAt(0).toUpperCase() + r.slice(1)]
            out[r] = v ? v : p[r]
        }
        return out
    }
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

    // a light theme overall, told by base's lightness
    readonly property bool isLight: base.hslLightness > 0.5

    // status hues never follow the wallpaper, so they always read
    readonly property color good:    Settings.colourGood || look.good
    readonly property color alert:   Settings.colourAlert || look.alert

    // the look's one hue, for marks (ticks, focus, current item); the
    // wallpaper's bright in wallpaper mode
    readonly property bool hasAccent: Settings.accent !== "" && Settings.colourMode !== "wallpaper"
    readonly property color accent: hasAccent ? Settings.accent : bright

    // --- semantic colours -----------------------------------------------------
    // named for the state; components prefer these over the ramp

    // emphasised text: values, titles, hovered labels
    readonly property color textStrong:    bright
    // a row or button under the pointer
    readonly property color hoverFill:     overlay
    // a smaller control under the pointer, or a chip/tab that's lit
    readonly property color hoverFillSoft: surface
    readonly property color selectedFill:  overlay
    readonly property color selectedStroke: hasAccent ? accent : muted
    // text on an accent fill: white unless the accent is too bright (by
    // perceived brightness), or as Appearance pins it. Not named onAccent:
    // QML reads on<Name> as a signal handler.
    readonly property color textOnAccent: Settings.accentText === "white" ? "#ffffff"
        : Settings.accentText === "dark" ? "#111111"
        : 0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b > 0.65 ? "#111111" : "#ffffff"
    // the inner half of a double frame
    readonly property color frameStroke:   muted
    // a field's ground: inputs, key-capture boxes
    readonly property color fieldFill:     surface
    // Glass draws one light hairline instead of the ramp's border
    readonly property bool glass: resolved.glass
    readonly property color stroke: glass ? (isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.14))
        : border
    readonly property color strokeHover:   muted
    readonly property color strokeFocus:   hasAccent ? accent : subtext
    readonly property color textDisabled:  muted
    readonly property color meterTrack:    base
    readonly property color meterStroke:   surface
    // level colour: meters, sliders and the bar's level chips
    readonly property color meterFill:     Settings.levelColour === "good" ? good
        : Settings.levelColour === "text" ? text : accent
    readonly property color gaugeFill:     meterFill
    // text on a level-colour fill, chosen as textOnAccent is
    readonly property color textOnMeter: 0.299 * meterFill.r + 0.587 * meterFill.g + 0.114 * meterFill.b > 0.65 ? "#111111" : "#ffffff"
    // the dimming behind full-screen overlays
    readonly property color scrim:         Qt.rgba(0, 0, 0, Settings.scrim / 100)
    // the ground of flyouts, windows, cards and the bar (See-through)
    readonly property real panelOpacity:   resolved.opacity / 100
    // Glass's accent-tinted option takes a little of the accent into it
    readonly property color panelTone: glass && opt("tint") ? Qt.tint(panel, Qt.rgba(accent.r, accent.g, accent.b, 0.18)) : panel
    readonly property color panelFill:     Qt.rgba(panelTone.r, panelTone.g, panelTone.b, panelOpacity)
    // Glass's glow option: lit things glow in the accent
    readonly property bool glow: glass && opt("glow")

    // --- type ------------------------------------------------------------------

    // One font for text and icons, always a non-Mono Nerd Font: "Mono"
    // squeezes every icon into one cell, so mixed icons look mismatched.
    readonly property string fontText: Fonts.resolve(Settings.fontFamily)
    readonly property string fontIcon: fontText

    // Font Size as a factor of 16px; every font size and text row goes
    // through fs(), so rows grow with their text.
    readonly property real fontScale: Settings.fontSize / Settings.fontSizeBase

    function fs(n) { return Math.round(n * fontScale) }

    // the bar's labels and icons, which follow Font size too
    function barFs(n) { return fs(n) }

    // The type scale, in pixels (rows are laid out in pixels too).
    readonly property int fontEyebrow:  fs(11)   // the spaced-out line over a window's title
    readonly property int fontCaption:  fs(12)   // a row's second line, key hints
    readonly property int fontSmall:    fs(14)   // headings, captions, secondary lines
    readonly property int fontBody:     fs(16)   // labels, values, chips, inputs
    readonly property int fontIconSize: fs(16)   // Nerd Font glyphs inside rows
    readonly property int fontTitle:    fs(22)   // a flyout's headline figure (temperature)
    readonly property int fontDisplay:  fs(26)   // placeholder art glyphs
    readonly property int fontHero:     fs(34)   // the one big glyph a flyout leads with

    // Section headings (FlyoutHeading), written in caps; title-case looks
    // lower them with heading().
    readonly property bool headingBold:    true
    readonly property bool headingUpper:   Settings.headingUpper
    readonly property real headingSpacing: headingUpper ? 1 : 0
    readonly property bool headingRule:    Settings.headingRule
    readonly property color headingColor:  bright
    // drawn before every heading, "" for none, in its own colour; a
    // "shape-" mark draws a shape instead of text: "bar" an accent stroke,
    // "brackets" the label in brackets, "tab" the label in a notch of the
    // rule, "tag" the label on an accent pill ("text" otherwise)
    readonly property string headingShape: Settings.headingMark.indexOf("shape-") === 0
        ? Settings.headingMark.slice(6) : "text"
    readonly property string headingPrefix: headingShape === "text" ? Settings.headingMark : ""
    readonly property color headingMarkColor: Settings.headingMarkColour === "text" ? text
        : Settings.headingMarkColour === "muted" ? muted
        : hasAccent ? Qt.lighter(accent, 1.4) : subtext
    // the headings' size against body text
    readonly property int fontHeadingSize: Settings.headingSize === "larger" ? fs(18)
        : Settings.headingSize === "same" ? fontBody : fontSmall
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
    // flyouts, windows and cards; and a floating bar or islands
    readonly property int panelRadius: resolved.panelRadius
    readonly property int barRadius:   resolved.barRadius
    // one step in from the outer stroke, floored at 0
    readonly property int radiusInner: Math.max(0, radius - 2)
    // a page's blocks in Settings and System: section frames, the tab strip,
    // previews and the bars at a page's foot
    readonly property int sectionRadius: radius > 0 ? radius + 3 : 0
    // small controls inside a row: stepper buttons, drag handles
    readonly property int radiusSmall: Math.max(0, radius - 3)
    // a pill, dot or capsule `size` px across: round only as far as Roundness
    function pill(size) { return Math.min(size / 2, radius) }
    // "double": a second stroke inset; "single": the outer one; "none": no
    // stroke, the ground marks the edge
    readonly property string frameStyle: resolved.frameStyle
    readonly property bool frameDouble: frameStyle === "double"
    readonly property bool frameNone:   frameStyle === "none"
    // "channel": outer line, dark groove, inner line (Channel.qml)
    readonly property bool frameChannel: frameStyle === "channel"
    // every style but None draws the plain outer stroke
    readonly property bool frameStroked: !frameNone
    // rows inside a panel are framed (SectionRuns) in every style but Flat
    readonly property bool sectionFramed: style !== "flat"
    // from a section frame's edge in to its ground, past its innermost line
    readonly property int sectionDepth: frameChannel ? channelWidth
        : frameDouble ? 2 + borderWidth : frameStroked ? borderWidth : 0
    // that innermost line's colour
    readonly property color sectionLine: frameChannel ? channelInner : frameDouble ? frameStroke : stroke

    // the channel's bands, outside in; channelWidth is all of them
    readonly property color channelOuter: muted
    readonly property color channelGroove: base
    readonly property color channelInner: border
    readonly property int channelGrooveWidth: 2
    readonly property int channelWidth: borderWidth * 2 + channelGrooveWidth
    // the inside corner where a channel's width changes (grown flyouts)
    readonly property int channelFillet: 7
    // a channel-framed panel's corners, square at Roundness 0
    readonly property int channelPanelRadius: panelRadius > 0 ? panelRadius + frameInset + channelWidth : 0
    // a panel's outer corners in the current frame (Hyprland's rounding)
    readonly property int panelFrameRadius: frameChannel ? channelPanelRadius : panelRadius
    // Hyprland's windows: rounded like the panels, bordered like the strokes,
    // unless Appearance's Desktop tab sets them its own way
    readonly property int windowRadius: Settings.windowRounding === "own" ? Settings.windowRadius : panelFrameRadius
    readonly property int windowBorderWidth: Settings.windowBorderWidth === "style" ? borderWidth
        : Number(Settings.windowBorderWidth)
    readonly property color windowBorderActive: Settings.windowBorderFocused === "text" ? text
        : Settings.windowBorderFocused === "custom" && Settings.windowBorderFocusedHex !== "" ? Settings.windowBorderFocusedHex
        : strokeFocus
    readonly property color windowBorderInactive: Settings.windowBorderUnfocused === "none" ? "transparent"
        : Settings.windowBorderUnfocused === "custom" && Settings.windowBorderUnfocusedHex !== "" ? Settings.windowBorderUnfocusedHex
        : border
    // their shadow: the style's (with Shadows on), none, or a set size
    readonly property string windowShadow: Settings.windowShadow === "style" ? shadow
        : Settings.windowShadow === "off" ? "none" : Settings.windowShadow
    // A control's stroke in a panel (chips, fields, steppers, cards): under
    // None only where a lit or focused state shows.
    function controlBorder(c) {
        if (frameStroked) return borderWidth
        return Qt.colorEqual(c, stroke) || Qt.colorEqual(c, "transparent") ? 0 : borderWidth
    }
    function controlStroke(c) {
        if (frameChannel && Qt.colorEqual(c, stroke)) return channelOuter
        if (frameChannel && Qt.colorEqual(c, strokeHover)) return subtext
        return c
    }
    // under None a control with no ground gets the field's
    function controlFill(c) {
        return frameNone && Qt.colorEqual(c, "transparent") ? fieldFill : c
    }
    readonly property int borderWidth: resolved.borderWidth
    // how far the inner stroke sits inside a panel's outer one
    readonly property int frameInset:  3
    // how a list marks its current row: "tick" or "tint"
    readonly property string rowMark: style === "solid" ? "tint" : "tick"
    // the left-edge bar marking the current row in a list
    readonly property int indicatorWidth: 2
    readonly property int meterHeight: 6

    // --- spacing ---------------------------------------------------------------

    // Spacing on every gap and padding, Row height on rows
    readonly property real density: Settings.spacing / 100
    function sp(n) { return Math.round(n * density) }
    // a text-bearing row: scaled with the font and Row height
    readonly property real densityHalf: Settings.rowScale / 100
    function row(n) { return Math.round(fs(n) * densityHalf) }
    // a box that holds text: grows with roomy rows, never shrinks
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
    // the size Settings and System open at: fixed, scaled by Font Size only
    readonly property size windowSize: Qt.size(fs(1044), fs(755))
    // between a flyout and the screen edge it's clamped against
    readonly property int edgeMargin: 6

    // control heights, so controls side by side line up
    readonly property int rowHeight:      row(24)   // list rows, steppers
    readonly property int rowHeightDense: row(22)   // packed lists: packages, gauges, calendar days
    readonly property int rowHeightTall:  row(26)   // action rows, inputs
    readonly property int fieldHeight:    row(28)   // settings fields, section rows
    readonly property int chipHeight:     row(20)   // chips, segmented strips
    readonly property int controlSize:    chipHeight // square +/-, icon buttons
    // on/off switches (Switch.qml)
    readonly property int switchWidth:   row(28)
    readonly property int switchHeight:  row(16)
    readonly property int headingHeight: Math.max(fs(16), fontHeadingSize + 2)
    // the faint surface a window's framed panels sit on (WindowPanel.qml)
    readonly property color panelTint: Qt.rgba(surface.r, surface.g, surface.b, 0.35)
    // the scrim under a caption over an image
    readonly property color captionScrim: Qt.rgba(base.r, base.g, base.b, 0.75)
    // the column an icon sits in at the start of a row
    readonly property int iconCell:      fs(20)

    // --- motion ----------------------------------------------------------------

    // Every duration goes through dur(); 0 makes them instant. A look can
    // opt out (its `motion` factor).
    readonly property real animFactor: look.motion * Settings.animTime / 100 * Settings.animShell / 100
    function dur(ms) { return Math.round(ms * animFactor) }
    // named steps: colour and hover changes / things appearing / meters filling
    readonly property int durFast:   dur(110)
    readonly property int durMedium: dur(150)
    readonly property int durSlow:   dur(250)
    // the busy pulse's half-cycle; not scaled, it's a status signal
    readonly property int durPulse:  600

    readonly property int ease: Easing.OutCubic

    // --- the bar ---------------------------------------------------------------

    // Bar geometry. Settings.set() is the one way to change these; flyouts
    // anchor to barHeight and icons size off it.
    readonly property string barPosition: Settings.barPosition
    readonly property int barHeight:  resolved.barHeight
    // Floating and Islands sit barMargin in from the screen edges (the
    // windows' edge gap); barExtent is where things anchored to the bar start.
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
    // one format per clock style; thin spaces around the divider (a mono
    // space is too wide)
    readonly property var clockFormats: ({
        stamp: "HH:mm:ss\u2009|\u2009MM/dd/yy",
        time:  "HH:mm",
        day:   "ddd d MMM\u2002HH:mm",
        long:  "dddd, MMMM d\u2002\u00b7\u2002HH:mm",
        seconds: "HH:mm:ss",
        iso:   "yyyy-MM-dd\u2002HH:mm",
        custom: Settings.clockFormat || "HH:mm",
    })
    // the Control Centre button's glyph
    readonly property var controlGlyphs: ({
        arch: "󰣇", menu: "󰍜", dashboard: "󰕮", cog: "󰒓", home: "󰋜", star: "󰓎",
        vortex: "󰢘", horizon: "󰺕", blackhole: "󰀘", atom: "󰝨", rocket: "󰑣", ghost: "󰊠",
        planet: "󰇧", sparkle: "󰙴", infinity: "󰛤",
        radar: "󰐷", moon: "󰖔",
    })
    readonly property string controlGlyph: controlGlyphs[Settings.controlIcon] || "󰣇"
    // the open-windows strip and app icons in the bar -- see Looks.js
    readonly property string windowStyle: Settings.windowStyle
    // ALT+Tab reaching every workspace widens the bar's strip too
    readonly property string windowScope: Settings.altTabScope === "all" ? "all" : Settings.windowScope
    readonly property string windowMark: resolved.windowMark
    readonly property string iconTint: Settings.iconTint
    // under panels and solid chips -- see Looks.js and flyouts/Shadow.qml
    readonly property string shadow: resolved.shadow
    // the bar's audio visualizer -- see Looks.js
    readonly property string vizStyle: Settings.vizStyle
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
    readonly property string altTabScope: Settings.altTabScope
    // between the bar's modules, and the room each gap takes with one
    readonly property string barSeparator: Settings.barSeparator
    readonly property int moduleSpacing: moduleGap + (barSeparator === "none" ? 0 : spaceL)
    // notification popups -- see Looks.js and NotificationCard
    readonly property string notifStyle: Settings.notifStyle
    readonly property bool launcherDetails: Settings.launcherDetails
    readonly property string launcherPosition: Settings.launcherPosition
    // the launcher -- see Looks.js and flyouts/Launcher.qml
    readonly property string launcherLayout: Settings.launcherLayout
    readonly property string flyoutAttach: resolved.flyoutAttach
    // how flyouts open and where they sit -- see Looks.js and FlyoutPanel
    readonly property string flyoutAnim: resolved.flyoutAnim
    // a Qt date format, 12-hour when Date & Time asks; every clock uses it
    function hours(fmt) {
        return Settings.clock24 ? fmt : fmt.replace(/HH:mm(:ss)?/g, "h:mm$1 AP")
    }
    readonly property string timeFormat: hours("HH:mm")
    // how the bar's chips are drawn -- see Looks.js
    readonly property string moduleStyle: resolved.moduleStyle
    // "grouped": each bar section is one channel holding bare chips
    readonly property bool moduleGrouped: moduleStyle === "grouped"
    // "taskbar": bare full-height slots, an accent rule on the open one
    readonly property bool moduleTaskbar: moduleStyle === "taskbar"
    // the styles whose open chip fills with the accent
    readonly property bool moduleOpenFill: moduleStyle === "filled"
    readonly property int groupHeight: moduleHeight + 2
    readonly property int groupRadius: radius > 0 ? radius + channelWidth : 0
    // "grown": a flyout hangs off its module's group, one outline round both
    readonly property bool flyoutGrown: flyoutAttach === "grown" && moduleGrouped && frameChannel
    // from the bar's screen edge to a flyout's near edge: flush lays the
    // box's stroke over the bar's edge line, floating leaves a gap
    readonly property real flyoutOffset: barHeight + barMargin - borderWidth
    // every bar flyout's width, before FlyoutPanel scales it by the font
    // and Flyout width
    readonly property int flyoutMenuWidth: 300
        + (flyoutAttach === "floating" ? spaceM + borderWidth : 0)
    // between a flyout's rows, and round its headings
    readonly property int flyoutSpacing: spaceS

    readonly property real barOpacity: panelOpacity
    // chips follow the bar's height, floored so the frame doesn't eat them
    readonly property int moduleHeight: moduleTaskbar ? barHeight : Math.max(18, barHeight - 6)
    readonly property int modulePadH:   sp(Settings.modulePad + (moduleTaskbar ? 4 : 0))
    // gap between adjacent modules, the same on both sides of the bar
    readonly property int moduleGap:    resolved.moduleGap
    // the gauge modules' shared width, so their fills compare
    readonly property int moduleWidth:  54
    // the space inside the chip's frame, capped to it
    readonly property int iconSize:     Math.min(moduleHeight - 8, barFs(Settings.barIconSize))
    // one size for every bar label (clock, media, counts), capped the same way
    readonly property int barLabelSize: Math.min(moduleHeight - 8, barFs(15))
}
