// Singularity - Quickshell
// ~/.config/quickshell/services/Styles.js
//
// The Styles: each a complete way of drawing the chrome. resolve() turns
// Settings.style and its dials into everything Theme hands out (the look
// cards use it too). Each style:
//   frame    panel and chip strokes: "channel", "double", "single", "none"
//   modules  bar chips: "grouped", "outline", "filled", "taskbar" ("bare" only
//            from Settings.barChips)
//   mark     the strip's focused window: "pill" or "ground"
//   shadow   what Shadows turns on: "none" or "soft"
//   lines    whether it has strokes (Heavy lines)
//   attach   flyouts "grown", "floating", or "auto" (flush on a full bar)
//   anim     how flyouts open when left to the style
//   glass    grounds 30% more see-through, light hairline
//   square   every corner square
//   finish   the Finish switches picking it sets
//   options  its own switches { id, label, hint, on }; one with `key` stands
//            for a shared Finish setting (with `value`/`off`), the rest are
//            Settings.styleOptions ids read with Theme.opt(id)
//   windows  optional { focusedOpacity, unfocusedOpacity, terminalOpacity }
//   settings optional stock values over `stock` below
// Controls draw per style too (Switch, Slider, FlyoutSegmented, FlyoutChip).
//
// A style owns every Appearance setting but the look's colours
// (Looks.colourKeys): picking it sets them all to its default, its stock
// (stockOf) unless Save as default replaced it (Settings.userDefaults).

.pragma library

var order = ["channel", "double", "solid", "glass", "flat"]

var styles = {
    channel: {
        name: "Channel", hint: "Grooved bands; flyouts grow from the bar groups",
        frame: "channel", modules: "grouped", mark: "pill",
        shadow: "none", lines: true, attach: "grown", anim: "fade",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: true, headingMark: "//", clockIsland: true },
        // the bar, panels and motion as `stock`
        options: [],
        // solid windows; the terminal a touch see-through, as it always was
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
    double: {
        name: "Double", hint: "Outlined chips, a stroke inside each",
        settings: {
            workspaceStyle: "blocks", windowStyle: "segmented", clockStyle: "day", vizStyle: "rise",
            notifStyle: "compact", altTabStyle: "titled", powerStyle: "list", levelStyle: "edge",
            windowAnim: "fold",
        },
        frame: "double", modules: "outline", mark: "pill",
        shadow: "none", lines: true, attach: "auto", anim: "drop",
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: true, clockIsland: true },
        options: [
            { id: "lit", label: "Inner stroke always lit", hint: "Not only on the open chip", on: false },
            { key: "heavyLines", label: "Heavy lines", hint: "Every stroke 2px, windows' borders too", on: false },
            { key: "headingMark", value: "//", off: "", label: "// before headings", hint: "An accent // ahead of each heading", on: true },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
    solid: {
        name: "Solid", hint: "Filled blocks, no strokes",
        settings: {
            radius: 10,
            windowStyle: "lift", clockStyle: "time", vizStyle: "rise", launcherLayout: "grid",
            altTabStyle: "previews", powerStyle: "full",
        },
        frame: "none", modules: "filled", mark: "ground",
        shadow: "soft", lines: false, attach: "floating", anim: "scale",
        finish: { barSeparator: "none", headingUpper: true, headingRule: false, headingMark: "", clockIsland: true },
        options: [
            { key: "shadows", label: "Shadows", hint: "Soft shadows under chips and panels", on: true },
            { id: "tint", label: "Accent-tinted chips", hint: "The bar's chips take a little of the accent", on: false },
            { key: "gradient", label: "Shaded grounds", hint: "A faint shade down the bar and panels", on: false },
            // Theme.barPlain; Settings.setStyleOption sets its other pieces
            { id: "plain", label: "Plain bar", hint: "Full width and flat, levels as text, like a classic text bar", on: false },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 100 },
    },
    glass: {
        name: "Glass", hint: "Frosted grounds over the blur, a light hairline",
        frame: "single", modules: "filled", mark: "ground",
        shadow: "soft", lines: false, attach: "floating", anim: "fade", glass: true,
        settings: {
            radius: 10,
            workspaceStyle: "dots", windowStyle: "spotlight", clockStyle: "time", launcherLayout: "grid",
            notifStyle: "compact", altTabStyle: "previews", overviewLayout: "strip", overviewBackdrop: "clear",
            powerStyle: "full", windowAnim: "zoom",
        },
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: false, headingMark: "", clockIsland: true },
        options: [
            { id: "blur", label: "Heavy blur", hint: "Grounds a further step see-through", on: true },
            { id: "tint", label: "Accent-tinted glass", hint: "The frost takes a little of the accent", on: false },
            { id: "glow", label: "Glow on accents", hint: "Lit switches, thumbs and chips glow", on: true },
        ],
        windows: { focusedOpacity: 95, unfocusedOpacity: 85, terminalOpacity: 75 },
    },
    flat: {
        name: "Flat", hint: "Square and flat; a taskbar along the bottom",
        // quicker, as a desktop OS's taskbar is
        settings: {
            workspaceStyle: "numbers", vizStyle: "line", altTabStyle: "previews", powerStyle: "list",
            levelStyle: "edge", windowAnim: "rise", animShell: 75, animWindows: 75,
        },
        frame: "single", modules: "taskbar", mark: "pill",
        shadow: "soft", lines: true, attach: "auto", anim: "drop", square: true,
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false, headingMark: "", clockIsland: false },
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

// the stock values every style starts from, settings' units as in
// Settings.limits
var stock = {
    radius: 6,
    fontFamily: "UbuntuMono Nerd Font",
    fontSize: 16,
    headingSize: "smaller",
    animTime: 100,
    animWindows: 100,
    animWorkspaces: 100,
    animShell: 100,
    windowAnim: "popin",
    spacing: 100,
    rowScale: 100,
    barHeight: 32,
    barIconSize: 17,
    modulePad: 6,
    windowRounding: "shell",
    windowRadius: 6,
    tabBar: "shell",
    flyoutWidth: 100,
    launcherRows: 8,
    notifWidth: 380,
    barStyle: "full",
    barPosition: "top",
    seeThrough: 100,
    shadows: true,
    heavyLines: false,
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

// a style's stock default: `stock`, what picking it sets (finish, windows),
// then its own `settings`
function stockOf(name) {
    var out = { style: name }, k
    for (k in stock) out[k] = stock[k]
    var fin = finish(name)
    for (k in fin) out[k] = fin[k]
    var win = windows(name)
    for (k in win) out[k] = win[k]
    var own = get(name).settings || {}
    for (k in own) out[k] = own[k]
    if (out.edgeGap === undefined) out.edgeGap = edgeGaps[out.barStyle] || 0
    return out
}

var windowDefaults = { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 }

// the window opacity picking the style sets, with windowDefaults filled in
function windows(name) {
    var w = get(name).windows || {}, out = {}
    for (var k in windowDefaults) out[k] = w[k] !== undefined ? w[k] : windowDefaults[k]
    return out
}

// the settings that can draw a part their own way, at the value that
// leaves it to the style
var deferred = { barChips: "auto", flyoutAnim: "auto", windowBorderWidth: "style", windowShadow: "style" }

// what picking the style sets: Finish switches and styleOptions (ids on),
// and every part drawn its own way handed back to the style (`deferred`).
// A setting another style's option stands for is put back too, so leaving
// that style undoes it: a valued one (Flat's bar at the bottom) to its off
// value, a switch to its default.
function finish(name) {
    var st = get(name), out = {}
    for (var d in deferred) out[d] = deferred[d]
    for (var n in styles) {
        var others = styles[n].options
        for (var j = 0; j < others.length; j++) {
            var p = others[j]
            if (p.key && !(p.key in out)) out[p.key] = p.value !== undefined ? offValue(p) : p.on
        }
    }
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

// s: { style, styleOptions, radius, barStyle, barHeight, spacing, seeThrough, shadows, heavyLines, flyoutAnim,
//      barChips }; barChips other than "auto" frames the bar's chips its own way under any style
function resolve(s) {
    var st = styles[s.style]
    var modules = s.barChips && s.barChips !== "auto" ? s.barChips : st.modules
    var attach = st.attach === "auto" ? (s.barStyle === "full" ? "flush" : "floating") : st.attach
    var radius = st.square ? 0 : s.radius
    var see = st.glass ? (has(s.styleOptions, "blur") ? 0.6 : 0.7) : 1
    return {
        styleName: s.style,
        frameStyle: st.frame,
        moduleStyle: modules,
        windowMark: st.mark,
        shadow: s.shadows ? st.shadow : "none",
        borderWidth: s.heavyLines && st.lines ? 2 : 1,
        radius: radius,
        barRadius: radius,
        flyoutAttach: attach,
        flyoutAnim: !s.flyoutAnim || s.flyoutAnim === "auto" ? st.anim : s.flyoutAnim,
        barHeight: s.barHeight,
        // the gap between bar modules follows Spacing, never closing up
        moduleGap: modules === "taskbar" ? 0 : Math.max(1, Math.round(2 * s.spacing / 100)),
        opacity: Math.round(s.seeThrough * see),
        glass: !!st.glass,
    }
}
