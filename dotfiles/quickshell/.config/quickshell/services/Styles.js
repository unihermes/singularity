// Singularity - Quickshell
// ~/.config/quickshell/services/Styles.js
//
// The Styles: each one a complete way of drawing the shell's chrome, so no
// mix of settings can put one style's chips beside another's flyouts.
// Settings.style names one; resolve() turns it and the few dials beside it
// (roundness, bar shape, density, see-through, the Finish switches) into
// every value Theme hands out. Theme and the Appearance page's look cards
// both go through resolve(), so a card draws exactly what picking it gives.
//
// Each style:
//   frame      how panels and chips are stroked (Theme.frame*): "channel",
//              "double", "single", "bevel" or "none"
//   modules    the bar chips (ModuleFrame): "grouped", "outline", "filled",
//              "pill", "ghost", "underline" or "bracket"
//   hover      a bar module under the pointer: "none", "fill" or "outline"
//   gauge      the level chips: "fill" or "segments"
//   mark       how the open-windows strip marks the focused window
//   title      a flyout's first heading: "none" or "titlebar"
//   shadow     the kind the Shadows switch turns on: "none", "soft", "hard"
//   lines      whether it has strokes, i.e. whether Heavy lines does anything
//   attach     where flyouts sit: "grown" from the bar group, "tab" hung
//              from the bar, "floating", or "auto": flush on a full-width
//              bar, floating on the others
//   anim       how flyouts open when Flyouts open is left to the style
//   prefix     drawn in the accent before every heading
//   glass      grounds a further 30% see-through, with a light hairline
//   finish     what picking the style sets the Finish switches to

.pragma library

var order = ["channel", "lined", "flat", "retro", "minimal", "basic", "capsule", "glass", "tabbed", "terminal"]

var styles = {
    channel: {
        name: "Channel", hint: "Grooved bands; flyouts grow from the bar groups",
        frame: "channel", modules: "grouped", hover: "fill", gauge: "fill", mark: "pill", title: "none",
        shadow: "none", lines: true, attach: "grown", anim: "fade", prefix: "//",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: true },
    },
    lined: {
        name: "Lined", hint: "Two fine strokes on every chip and panel",
        frame: "double", modules: "outline", hover: "outline", gauge: "fill", mark: "pill", title: "none",
        shadow: "none", lines: true, attach: "auto", anim: "drop", prefix: "",
        finish: { barSeparator: "line", gradient: false, headingUpper: true, headingRule: true },
    },
    flat: {
        name: "Flat", hint: "Solid grounds, no strokes, soft shadows",
        frame: "none", modules: "filled", hover: "fill", gauge: "fill", mark: "ground", title: "none",
        shadow: "soft", lines: false, attach: "auto", anim: "scale", prefix: "",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: false },
    },
    retro: {
        name: "Retro", hint: "Raised bevels, title bars, hard shadows",
        frame: "bevel", modules: "outline", hover: "none", gauge: "fill", mark: "box", title: "titlebar",
        shadow: "hard", lines: true, attach: "auto", anim: "none", prefix: "",
        finish: { barSeparator: "double", gradient: true, headingUpper: false, headingRule: true },
    },
    minimal: {
        name: "Minimal", hint: "Bare chips over a rule, hairline panels",
        frame: "single", modules: "underline", hover: "fill", gauge: "fill", mark: "above", title: "none",
        shadow: "soft", lines: true, attach: "auto", anim: "drop", prefix: "",
        finish: { barSeparator: "dot", gradient: false, headingUpper: true, headingRule: true },
    },
    basic: {
        name: "Basic", hint: "No outlines or marks: grounds and text only",
        frame: "none", modules: "ghost", hover: "fill", gauge: "fill", mark: "ground", title: "none",
        shadow: "none", lines: false, attach: "auto", anim: "fade", prefix: "",
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false },
    },
    capsule: {
        name: "Capsule", hint: "Every chip, control and island a pill",
        frame: "none", modules: "pill", hover: "fill", gauge: "fill", mark: "pill", title: "none",
        shadow: "soft", lines: false, attach: "floating", anim: "scale", prefix: "",
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false },
    },
    glass: {
        name: "Glass", hint: "Frosted grounds over the blur, a light hairline",
        frame: "single", modules: "filled", hover: "fill", gauge: "fill", mark: "ground", title: "none",
        shadow: "soft", lines: false, attach: "floating", anim: "fade", prefix: "", glass: true,
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: false },
    },
    tabbed: {
        name: "Tabbed", hint: "Flyouts hang from the bar like tabs",
        frame: "single", modules: "ghost", hover: "fill", gauge: "fill", mark: "above", title: "none",
        shadow: "soft", lines: true, attach: "tab", anim: "drop", prefix: "",
        finish: { barSeparator: "line", gradient: false, headingUpper: true, headingRule: true },
    },
    terminal: {
        name: "Terminal", hint: "Bracketed modules, block meters, square edges",
        frame: "single", modules: "bracket", hover: "none", gauge: "segments", mark: "box", title: "none",
        shadow: "none", lines: true, attach: "auto", anim: "none", prefix: ">",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: false },
    },
}

// bar height and the gap between modules, by density
var densityBar = { compact: { height: 28, gap: 2 }, normal: { height: 32, gap: 2 }, roomy: { height: 36, gap: 4 } }

function get(name) { return styles[name] || styles.channel }

// s: { style, radius, barStyle, density, seeThrough, shadows, heavyLines, flyoutAnim }
function resolve(s) {
    var st = get(s.style)
    var bar = densityBar[s.density] || densityBar.normal
    var attach = st.attach === "auto" ? (s.barStyle === "full" ? "flush" : "floating") : st.attach
    return {
        frameStyle: st.frame,
        moduleStyle: st.modules,
        hoverStyle: st.hover,
        gaugeStyle: st.gauge,
        windowMark: st.mark,
        flyoutTitle: st.title,
        shadow: s.shadows ? st.shadow : "none",
        borderWidth: s.heavyLines && st.lines ? 2 : 1,
        panelRadius: s.radius,
        barRadius: s.radius,
        flyoutAttach: attach,
        flyoutAnim: !s.flyoutAnim || s.flyoutAnim === "auto" ? st.anim : s.flyoutAnim,
        barHeight: bar.height,
        moduleGap: bar.gap,
        opacity: Math.round(s.seeThrough * (st.glass ? 0.7 : 1)),
        headingPrefix: st.prefix,
        glass: !!st.glass,
    }
}
