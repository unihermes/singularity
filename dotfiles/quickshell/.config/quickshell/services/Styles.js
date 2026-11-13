// The Styles: each a complete way of drawing the chrome. resolve() turns
// Settings.style and its dials into everything Theme hands out (the look
// cards use it too). Each style:
//   frame    panel and chip strokes: channel, double, single, none,
//            rail, notch, ruled, bevel (StyleFrame.qml)
//   modules  bar chips: "grouped", "outline", "filled", "taskbar" ("bare" only
//            from Settings.barChips)
//   mark     the strip's focused window: "pill" or "ground"
//   shadow   what Shadows turns on: "none", "soft" or "hard"
//   controls optional shared control family (Capsule uses Solid's pills)
//   lines    whether it has strokes (Heavy lines)
//   attach   flyouts "grown", "floating", or "auto" (flush on a full bar)
//   anim     how flyouts open when left to the style
//   glass    grounds 30% more see-through, light hairline
//   square   every corner square
//   finish   the Finish switches picking it sets
//   options  its own switches { id, label, hint, on }; one with `key` stands
//            for a shared Finish setting (with `value`/`off`), the rest are
//            Settings.styleOptions ids read with Theme.opt(id)
//   layout   optional bar arrangement the style's option of that id turns on:
//            "taskbar" (centre moved right, clock last) or "menubar" (the same,
//            with the open windows left to the Dock)
//   bar      optional { left, right }: the arrangement its layout option turns
//            on, every module named (the centre stays empty; any left out
//            joins the right), plus `hidden`, modules it never shows. Modules only such an arrangement names
//            (Settings.styleOnlyWidgets) appear only under it
//   windows  optional { focusedOpacity, unfocusedOpacity, terminalOpacity }
//   settings optional stock values over `stock` below
// Controls draw per style too (Switch, Slider, FlyoutSegmented, FlyoutChip).
//
// A style owns every Appearance setting but the look's colours
// (Looks.colourKeys): picking it sets them all to its default, its stock
// (stockOf) unless Save as default replaced it (Settings.userDefaults).

.pragma library

var order = ["channel", "double", "solid", "glass", "flat", "rail", "notch", "pane", "capsule", "bevel"]

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
            notifStyle: "compact", powerStyle: "list", levelStyle: "edge",
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
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 100 },
    },
    glass: {
        name: "Glass", hint: "Frosted menu bar and a floating Dock, as on a Mac",
        frame: "single", modules: "bare", mark: "ground",
        shadow: "soft", lines: false, attach: "floating", anim: "scale", glass: true, layout: "menubar",
        // as the macOS menu bar: the app's name by the logo, then status
        // items running to the clock
        bar: {
            left: ["controlcentre", "activeapp", "workspaces"],
            // as the menu bar reads: live indicators, background services,
            // the tray, media and weather, then the system controls with the
            // network and battery nearest the search, notifications and clock
            right: ["privacy", "recorder", "failed", "updates", "drives", "phone", "vpn", "claude", "tray",
                    "visualizer", "weather", "bluetooth", "volume", "brightness", "network", "battery", "search",
                    "notifications", "clock"],
        },
        settings: {
            radius: 12, fontFamily: "Liberation Sans", fontSize: 14, controlIcon: "apple",
            barHeight: 28, barIconSize: 16, modulePad: 5, windowIconSize: 22,
            workspaceStyle: "dots", windowStyle: "icons", clockStyle: "long", launcherLayout: "spotlight",
            notifStyle: "compact", altTabStyle: "previews", overviewLayout: "strip", overviewBackdrop: "clear",
            powerStyle: "full", windowAnim: "zoom",
        },
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false, headingMark: "", clockIsland: false },
        options: [
            { id: "menubar", label: "Menu bar layout", hint: "Status and the clock packed at the right, apps in the Dock", on: true },
            { id: "dock", label: "Dock", hint: "A floating Dock of pinned and open apps along the bottom", on: true },
            { id: "autohide", label: "Auto-hide Dock", hint: "Slides away over the windows; point at the bottom edge to bring it back", on: true },
            { id: "blur", label: "Heavy blur", hint: "Grounds a further step see-through", on: true },
            { id: "tint", label: "Accent-tinted glass", hint: "The frost takes a little of the accent", on: false },
            { id: "glow", label: "Glow on accents", hint: "Lit switches, thumbs and chips glow", on: true },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 80 },
    },
    flat: {
        name: "Flat", hint: "Square and flat; a taskbar along the bottom",
        // quicker, as a desktop OS's taskbar is
        settings: {
            workspaceStyle: "numbers", vizStyle: "line", altTabStyle: "previews", powerStyle: "list",
            levelStyle: "edge", windowAnim: "rise", animShell: 75, animWindows: 75,
        },
        frame: "single", modules: "taskbar", mark: "pill",
        shadow: "soft", lines: true, attach: "auto", anim: "drop", square: true, layout: "taskbar",
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false, headingMark: "", clockIsland: false },
        options: [
            // Settings.widgetLayout() rearranges the bar while this is on
            { id: "taskbar", label: "Taskbar layout", hint: "Status and the clock packed at the right", on: true },
            { key: "barPosition", value: "bottom", off: "top", label: "Bar at the bottom", hint: "Along the screen's bottom edge", on: true },
            { key: "shadows", label: "Shadows", hint: "Soft shadows under flyouts", on: true },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
    rail: {
        name: "Rail", hint: "Leading spines, ruled groups and underline switches",
        frame: "rail", modules: "grouped", mark: "pill",
        shadow: "none", lines: true, attach: "floating", anim: "drop",
        settings: { radius: 3, workspaceStyle: "pills", windowStyle: "icons" },
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false, headingMark: "shape-bar", clockIsland: true },
        options: [],
    },
    notch: {
        name: "Notch", hint: "Cut corners, bracket headings and angular controls",
        frame: "notch", modules: "outline", mark: "pill",
        shadow: "none", lines: true, attach: "floating", anim: "drop", square: true,
        settings: { workspaceStyle: "blocks", windowStyle: "segmented", vizStyle: "rise" },
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: false, headingMark: "shape-brackets", clockIsland: true },
        options: [],
    },
    pane: {
        name: "Pane", hint: "A desktop taskbar: Start menu, search box, square flat tiles along the bottom",
        // quicker, as a desktop OS's taskbar is
        settings: {
            fontFamily: "Noto Sans", fontSize: 14, barHeight: 44, barIconSize: 22, windowIconSize: 28, windowIconPadding: 8, modulePad: 1, controlIcon: "windows",
            workspaceStyle: "numbers", windowStyle: "icons", clockStyle: "stack", vizStyle: "line", altTabStyle: "previews",
            powerStyle: "list", levelStyle: "edge", windowAnim: "rise", launcherLayout: "start", animShell: 75, animWindows: 75,
        },
        frame: "single", modules: "taskbar", mark: "pill",
        shadow: "soft", lines: true, attach: "auto", anim: "drop", square: true, layout: "taskbar",
        // as the Windows taskbar: Start, the search box, Task View, then the
        // open windows; the tray, the clock and the Action Centre at the right
        bar: {
            left: ["controlcentre", "search", "taskview", "workspaces", "windows"],
            right: ["tray", "recorder", "privacy", "drives", "phone", "vpn", "failed", "updates", "claude",
                    "visualizer", "weather", "bluetooth", "network", "battery", "clock", "notifications", "desktop"],
            // Windows keeps these in its flyouts, not the taskbar
            hidden: ["volume", "brightness"],
        },
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false, headingMark: "", clockIsland: false },
        options: [
            { id: "taskbar", label: "Taskbar layout", hint: "Start, search and Task View at the left; the clock at the right", on: true },
            { key: "barPosition", value: "bottom", off: "top", label: "Bar at the bottom", hint: "Along the screen's bottom edge", on: true },
            { key: "shadows", label: "Shadows", hint: "Soft shadows under flyouts", on: true },
        ],
        windows: { focusedOpacity: 100, unfocusedOpacity: 100, terminalOpacity: 90 },
    },
    capsule: {
        name: "Capsule", hint: "Rounded islands, soft sections and pill controls",
        frame: "none", modules: "filled", mark: "ground", controls: "solid",
        shadow: "soft", lines: false, attach: "floating", anim: "scale",
        settings: { radius: 14, barStyle: "islands", workspaceStyle: "dots", clockStyle: "time", launcherLayout: "grid", altTabStyle: "previews" },
        finish: { barSeparator: "none", gradient: false, headingUpper: false, headingRule: false, headingMark: "", clockIsland: true },
        options: [{ key: "shadows", label: "Shadows", hint: "Soft shadows under islands and panels", on: true }],
    },
    bevel: {
        name: "Bevel", hint: "Raised edges, recessed controls and crisp offset shadows",
        frame: "bevel", modules: "outline", mark: "pill",
        shadow: "hard", lines: true, attach: "floating", anim: "drop",
        settings: { radius: 2, workspaceStyle: "blocks", windowStyle: "segmented", vizStyle: "rise" },
        finish: { barSeparator: "none", gradient: false, headingUpper: true, headingRule: true, headingMark: "::", clockIsland: true },
        options: [{ key: "shadows", label: "Shadows", hint: "Crisp offset shadows under panels and chips", on: true }],
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
    windowIconSize: 18,
    windowIconPadding: 3,
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
    plain: false,
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
    altTabStyle: "previews",
    altTabScope: "all",
    altTabBlur: false,
    aiPlacement: "sidebar",
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
//      barChips, plain }; barChips other than "auto" frames the bar's chips its own way under any
// style. Plain flattens any style: bare chips on a full bar, flyouts flush
// under it, no shadows, hairlines only (Theme.plain does the rest).
function resolve(s) {
    var st = styles[s.style]
    var modules = s.barChips && s.barChips !== "auto" ? s.barChips : s.plain ? "bare" : st.modules
    var attach = s.plain ? "flush"
        : st.attach === "auto" ? (s.barStyle === "full" ? "flush" : "floating") : st.attach
    var radius = st.square ? 0 : s.radius
    var see = st.glass ? (has(s.styleOptions, "blur") ? 0.6 : 0.7) : 1
    return {
        styleName: s.style,
        controlStyle: st.controls || s.style,
        frameStyle: st.frame,
        moduleStyle: modules,
        windowMark: st.mark,
        shadow: s.shadows && !s.plain ? st.shadow : "none",
        borderWidth: s.heavyLines && st.lines && !s.plain ? 2 : 1,
        radius: radius,
        barRadius: radius,
        flyoutAttach: attach,
        flyoutAnim: !s.flyoutAnim || s.flyoutAnim === "auto" ? st.anim : s.flyoutAnim,
        barHeight: s.barHeight,
        // the gap between bar modules follows Spacing, never closing up;
        // Glass's square chips sit flush
        moduleGap: modules === "taskbar" || st.glass ? 0 : Math.max(1, Math.round(2 * s.spacing / 100)),
        opacity: Math.round(s.seeThrough * see),
        glass: !!st.glass,
    }
}
