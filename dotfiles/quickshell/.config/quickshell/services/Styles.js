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
//              "double", "single" or "none"
//   modules    the bar chips (ModuleFrame): "grouped", "outline", "filled"
//              or "taskbar" (bare slots the bar's full height, packed with
//              no gaps)
//   mark       how the open-windows strip marks the focused window:
//              "pill" or "ground"
//   shadow     the kind the Shadows switch turns on: "none" or "soft"
//   lines      whether it has strokes, i.e. whether Heavy lines does anything
//   attach     where flyouts sit: "grown" from the bar group, "floating",
//              or "auto": flush on a full-width bar, floating on the others
//   anim       how flyouts open when Flyouts open is left to the style
//   prefix     drawn in the accent before every heading
//   glass      grounds a further 30% see-through, with a light hairline
//   square     every corner square, whatever Roundness says
//   finish     what picking the style sets the Finish switches to
//   options    the style's own switches, shown on the Style tab under its
//              name. Each is { id, label, hint, on }: `on` is its state
//              when the style is picked. An option with a `key` is one of
//              the shared Finish settings (shadows, gradient, heavyLines,
//              headingUpper, or barSeparator or barPosition with `value`,
//              and `off` for the value it takes when off, "none" if
//              unstated); the rest are ids in Settings.styleOptions, read
//              with Theme.opt(id).
//   windows    optional: window opacity, in percent, as { focusedOpacity,
//              unfocusedOpacity, terminalOpacity } -- Hyprland's focused
//              and unfocused windows, and the terminal's background; left out,
//              windowDefaults'. Picking the style sets them, and they stay
//              adjustable on the Windows tab
//
// Every style also draws its own controls -- switch, slider, segments and
// buttons -- keyed by its name (Switch.qml, Slider.qml, FlyoutSegmented.qml,
// FlyoutChip.qml).

.pragma library

var order = ["channel", "double", "solid", "glass", "flat"]

var styles = {
    channel: {
        name: "Channel", hint: "Grooved bands; flyouts grow from the bar groups",
        frame: "channel", modules: "grouped", mark: "pill",
        shadow: "none", lines: true, attach: "grown", anim: "fade", prefix: "//",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: true },
        options: [],
        // solid windows; the terminal a touch see-through, as it always was
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
    double: {
        name: "Double", hint: "Outlined chips, a stroke inside each",
        frame: "double", modules: "outline", mark: "pill",
        shadow: "none", lines: true, attach: "auto", anim: "drop", prefix: "",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: true },
        options: [
            { id: "lit", label: "Inner stroke always lit", hint: "Not only on the open chip", on: false },
            { key: "heavyLines", label: "Heavy lines", hint: "Every stroke 2px, windows' borders too", on: false },
            { id: "slash", label: "// before headings", hint: "An accent // ahead of each heading", on: true },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
    solid: {
        name: "Solid", hint: "Filled blocks, no strokes",
        frame: "none", modules: "filled", mark: "ground",
        shadow: "soft", lines: false, attach: "floating", anim: "scale", prefix: "",
        finish: { barSeparator: "none", headingUpper: true, headingRule: false },
        options: [
            { key: "shadows", label: "Shadows", hint: "Soft shadows under chips and panels", on: true },
            { id: "tint", label: "Accent-tinted chips", hint: "The bar's chips take a little of the accent", on: false },
            { key: "gradient", label: "Shaded grounds", hint: "A faint shade down the bar and panels", on: false },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 100 },
    },
    glass: {
        name: "Glass", hint: "Frosted grounds over the blur, a light hairline",
        frame: "single", modules: "filled", mark: "ground",
        shadow: "soft", lines: false, attach: "floating", anim: "fade", prefix: "", glass: true,
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: false },
        options: [
            { id: "blur", label: "Heavy blur", hint: "Grounds a further step see-through", on: true },
            { id: "tint", label: "Accent-tinted glass", hint: "The frost takes a little of the accent", on: false },
            { id: "glow", label: "Glow on accents", hint: "Lit switches, thumbs and chips glow", on: true },
        ],
        windows: { focusedOpacity: 95, unfocusedOpacity: 85, terminalOpacity: 75 },
    },
    flat: {
        name: "Flat", hint: "Square and flat; a taskbar along the bottom",
        frame: "single", modules: "taskbar", mark: "pill",
        shadow: "soft", lines: true, attach: "auto", anim: "drop", prefix: "", square: true,
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false },
        options: [
            // Settings.widgetLayout() rearranges the bar while this is on
            { id: "taskbar", label: "Taskbar layout", hint: "Status and the clock packed at the right", on: true },
            { key: "barPosition", value: "bottom", off: "top", label: "Bar at the bottom", hint: "Along the screen's bottom edge", on: true },
            { key: "shadows", label: "Shadows", hint: "Soft shadows under flyouts", on: true },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
}

function get(name) { return styles[name] }

var windowDefaults = { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 }

// the window opacity picking the style sets, with windowDefaults filled in
function windows(name) {
    var w = get(name).windows || {}, out = {}
    for (var k in windowDefaults) out[k] = w[k] !== undefined ? w[k] : windowDefaults[k]
    return out
}

// What picking the style sets: its Finish switches, the shared ones its
// options stand for, and styleOptions -- the ids of its own options that
// start on, comma-joined.
function finish(name) {
    var st = get(name), out = {}
    for (var k in st.finish) out[k] = st.finish[k]
    var ids = []
    for (var i = 0; i < st.options.length; i++) {
        var o = st.options[i]
        if (o.key) out[o.key] = o.value !== undefined ? (o.on ? o.value : offValue(o)) : o.on
        else if (o.on) ids.push(o.id)
    }
    out.styleOptions = ids.join(",")
    return out
}

// what an option with a `value` sets when it's off
function offValue(o) { return o.off !== undefined ? o.off : "none" }

function has(opts, id) { return (opts || "").split(",").indexOf(id) !== -1 }

// s: { style, styleOptions, radius, barStyle, barHeight, spacing, seeThrough, shadows, heavyLines, flyoutAnim }
function resolve(s) {
    var st = styles[s.style]
    var attach = st.attach === "auto" ? (s.barStyle === "full" ? "flush" : "floating") : st.attach
    var radius = st.square ? 0 : s.radius
    var prefix = st.prefix
    if (s.style === "double") prefix = has(s.styleOptions, "slash") ? "//" : ""
    var see = st.glass ? (has(s.styleOptions, "blur") ? 0.6 : 0.7) : 1
    return {
        styleName: s.style,
        frameStyle: st.frame,
        moduleStyle: st.modules,
        windowMark: st.mark,
        shadow: s.shadows ? st.shadow : "none",
        borderWidth: s.heavyLines && st.lines ? 2 : 1,
        radius: radius,
        panelRadius: radius,
        barRadius: radius,
        flyoutAttach: attach,
        flyoutAnim: !s.flyoutAnim || s.flyoutAnim === "auto" ? st.anim : s.flyoutAnim,
        barHeight: s.barHeight,
        // the gap between bar modules follows Spacing, never closing up
        moduleGap: st.modules === "taskbar" ? 0 : Math.max(1, Math.round(2 * s.spacing / 100)),
        opacity: Math.round(s.seeThrough * see),
        headingPrefix: prefix,
        glass: !!st.glass,
    }
}
