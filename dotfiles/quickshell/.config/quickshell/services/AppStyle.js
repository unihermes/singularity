// Singularity - Quickshell
// ~/.config/quickshell/services/AppStyle.js
//
// The current style (Styles.js) drawn onto other toolkits' widgets: a GTK
// sheet for adw-gtk3 and libadwaita, and a Qt stylesheet for qt6ct's
// Fusion. AppearanceSync appends gtk() to the colour sheets it writes and
// points qt6ct at qss().
//
// Both take one plain object, t:
//   c          hex colours: the ramp (base … bright), accent, onAccent
//   isLight    the ramp's ground is light
//   r          Styles.resolve()'s result
//   st         the style's own table (Styles.get)
//   density    "compact", "normal" or "roomy"
//
// What carries over: corners (Roundness; Capsule's pills, Terminal's
// square), Density's control heights, and the style's frame on controls
// and panels -- single, double or channel strokes, Retro's bevels, none --
// with hover drawn the style's way. Shadows, see-through, title bars and
// heading case stay the toolkit's, so apps keep their own legibility.
//
// A user sheet outranks the theme's rules whatever their selectors, so
// every rule here sets only the properties it means to change, and states
// the theme draws (hover, checked, suggested) are restated where a rule
// here would otherwise flatten them.

.pragma library

function rgb(hex) {
    var n = parseInt(hex.slice(1, 7), 16)
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}
function toHex(v) {
    return "#" + v.map(x => ("0" + Math.max(0, Math.min(255, Math.round(x))).toString(16)).slice(-2)).join("")
}
// Qt.lighter / Qt.darker on a grey-ish colour: every channel scaled
function scale(hex, f) { return toHex(rgb(hex).map(x => x * f)) }
function mix(a, b, t) {
    var x = rgb(a), y = rgb(b)
    return toHex(x.map((v, i) => v + (y[i] - v) * t))
}
function alpha(hex, a) { var v = rgb(hex); return "rgba(" + v.join(", ") + ", " + a + ")" }

var heights = { compact: 28, normal: 34, roomy: 42 }

function setup(t) {
    var c = t.c, r = t.r, st = t.st
    var pill = st.modules === "pill"
    var w = r.borderWidth
    var o = {
        c: c, r: r, st: st, w: w,
        frame: r.frameStyle,
        ctl: pill ? 9999 : r.radius,
        panel: pill ? Math.max(12, r.radius) : r.radius,
        round: r.radius === 0 ? 0 : 9999,
        check: pill ? 9999 : Math.min(r.radius, 4),
        h: heights[t.density] || heights.normal,
        // a control's resting stroke, and the one it takes under the pointer
        stroke: r.frameStyle === "channel" ? c.muted : c.border,
        strokeHover: r.frameStyle === "channel" ? c.subtext : c.muted,
        bevelLight: scale(c.border, 1.8), bevelDark: scale(c.border, 1 / 1.8),
    }
    o.pad = Math.max(1, Math.round((o.h - 24) / 2))
    o.padX = Math.round(10 * ({ compact: 0.8, normal: 1, roomy: 1.3 }[t.density] || 1))
    return o
}

// box-shadow strokes, outermost first: [[width, colour], …] from the edge in
function rings(list) {
    var out = [], at = 0
    for (var i = 0; i < list.length; i++) {
        at += list[i][0]
        out.push("inset 0 0 0 " + at + "px " + list[i][1])
    }
    return out
}
function bevel(o, sunken) {
    var a = sunken ? o.bevelDark : o.bevelLight, b = sunken ? o.bevelLight : o.bevelDark
    return ["inset " + o.w + "px " + o.w + "px " + a, "inset -" + o.w + "px -" + o.w + "px " + b]
}
// a panel's frame drawn on ground `bg`: cards, boxed lists, popovers, frames
function panelFrame(o, bg) {
    var c = o.c, w = o.w
    switch (o.frame) {
    case "single": return rings([[w, c.border]])
    case "double": return rings([[w, c.border], [2, bg], [w, c.muted]])
    case "channel": return rings([[w, c.muted], [2, c.base], [w, c.border]])
    case "bevel": return bevel(o, false)
    case "none": return []
    }
    return null
}
function controlFrame(o, colour) {
    if (o.frame === "bevel") return bevel(o, false)
    if (o.frame === "none") return []
    return rings([[o.w, colour]])
}
function shadowList(list) { return list.length ? list.join(", ") : "none" }
function block(sel, props) {
    var body = ""
    for (var k in props) if (props[k] !== undefined && props[k] !== null) body += "  " + k + ": " + props[k] + ";\n"
    return body ? sel + " {\n" + body + "}\n" : ""
}

// The GTK sheet. v: 3 or 4 -- GTK3 (adw-gtk3) and GTK4 (libadwaita) name a
// few nodes differently.
function gtk(t, v) {
    var o = setup(t), c = o.c, css = ""
    var px = n => n + "px"
    var popover = v === 4 ? "popover > contents, popover.menu > contents" : "popover, menu, .menu, .context-menu"
    var slider = v === 4 ? "switch > slider" : "switch slider"
    var buttons = "button:not(.flat):not(.circular):not(.titlebutton), menubutton > button:not(.flat), dropdown > button, combobox button.combo, spinbutton > button"
    var fields = "entry, spinbutton, searchbar entry"

    // --- corners and density ---
    css += block("button, menubutton > button, dropdown > button, combobox button.combo, " + fields, { "border-radius": px(o.ctl) })
    css += block("button, menubutton > button, dropdown > button, combobox button.combo", {
        "min-height": px(o.h - 2 * o.pad), "padding-top": px(o.pad), "padding-bottom": px(o.pad),
        "padding-left": px(o.padX), "padding-right": px(o.padX) })
    css += block("button.image-button, button.circular", { "min-width": px(o.h - 2 * o.pad), "padding-left": px(o.pad), "padding-right": px(o.pad) })
    css += block("button.circular, button.osd, button.titlebutton", { "border-radius": px(o.round) })
    css += block(fields, { "min-height": px(o.h) })
    // linked groups keep square inner joins
    css += block(".linked:not(.vertical) > :not(:first-child), .linked:not(.vertical) > :not(:first-child) > button",
        { "border-top-left-radius": "0", "border-bottom-left-radius": "0" })
    css += block(".linked:not(.vertical) > :not(:last-child), .linked:not(.vertical) > :not(:last-child) > button",
        { "border-top-right-radius": "0", "border-bottom-right-radius": "0" })
    css += block(".linked.vertical > :not(:first-child)", { "border-top-left-radius": "0", "border-top-right-radius": "0" })
    css += block(".linked.vertical > :not(:last-child)", { "border-bottom-left-radius": "0", "border-bottom-right-radius": "0" })
    css += block(popover + ", tooltip, tooltip > contents, .card, list.boxed-list, list.content, frame, frame > border, notebook, .view.frame, textview.frame, scrolledwindow.frame",
        { "border-radius": px(o.panel) })
    css += block("list.boxed-list > row:first-child, list.content > row:first-child", { "border-top-left-radius": px(o.panel), "border-top-right-radius": px(o.panel) })
    css += block("list.boxed-list > row:last-child, list.content > row:last-child", { "border-bottom-left-radius": px(o.panel), "border-bottom-right-radius": px(o.panel) })
    css += block("modelbutton, " + (v === 4 ? "popover.menu > contents > * row, popover.menu modelbutton" : "menuitem") + ", .navigation-sidebar > row, placessidebar row, stacksidebar row",
        { "border-radius": px(Math.max(0, o.ctl === 9999 ? 9999 : o.panel - 2)) })
    css += block("check", { "border-radius": px(o.check) })
    css += block("switch, " + slider, { "border-radius": px(o.round === 0 ? 0 : o.ctl === 9999 ? 9999 : Math.max(o.ctl, 2)) })
    css += block("scale trough, scale highlight, scale fill, progressbar trough, progressbar progress, levelbar trough, levelbar block",
        { "border-radius": px(o.round === 0 ? 0 : 9999) })
    css += block("scale slider", { "border-radius": px(o.round === 0 ? 0 : 9999) })
    css += block("notebook > header > tabs > tab, tabbar tab", { "border-radius": px(o.ctl === 9999 ? 9999 : o.ctl) })
    css += block("headerbar", { "min-height": px(o.h + 12) })


    // --- each style's strokes, bevels and hover ---
    var rest = controlFrame(o, o.stroke)
    var hoverOutline = t.r.hoverStyle === "outline"
    css += block(buttons + ", " + fields + ", check, radio, switch", { "box-shadow": shadowList(rest) })
    css += block("button.flat, button.titlebutton, button.circular.flat, headerbar button:not(.suggested-action):not(.destructive-action)", { "box-shadow": "none" })
    if (o.frame !== "bevel" && o.frame !== "none") {
        css += block("button:not(.flat):hover, menubutton > button:not(.flat):hover, dropdown > button:hover, combobox button.combo:hover" + (hoverOutline ? ", button.flat:hover" : ""),
            { "box-shadow": shadowList(rings([[o.w, o.strokeHover]])) })
        css += block("check:checked, radio:checked, switch:checked, button.suggested-action, button.destructive-action",
            { "box-shadow": "none" })
    }
    if (hoverOutline) css += block("button.flat:hover, button:not(.suggested-action):not(.destructive-action):hover, modelbutton:hover, .navigation-sidebar > row:hover",
        { "background-color": "transparent", "background-image": "none" })
    if (o.frame === "bevel") {
        css += block("button:active, button:checked, button.flat:active, button.flat:checked", { "box-shadow": shadowList(bevel(o, true)) })
        css += block(fields + ", check, radio, switch, scale trough, progressbar trough", { "box-shadow": shadowList(bevel(o, true)) })
        css += block("button.flat:hover", { "box-shadow": shadowList(bevel(o, false)) })
    }
    // with no strokes, a control is found by its ground alone
    if (o.frame === "none") {
        css += block("button:not(.flat):not(.circular):not(.titlebutton):not(.suggested-action):not(.destructive-action):not(:checked):not(:hover):not(:active), " + fields,
            { "background-color": c.overlay })
        css += block("check:not(:checked), radio:not(:checked)", { "background-color": c.overlay })
    }
    // focus as the accent, the way the shell's fields draw it
    css += block(fields.split(", ").map(s => s + ":focus-within").join(", "),
        { "box-shadow": shadowList(rings([[o.w, c.accent]])), "outline": "none" })

    var surf = c.surface, pop = t.isLight ? c.panel : c.overlay
    var cardFrame = panelFrame(o, surf), popFrame = panelFrame(o, pop)
    var cardSel = ".card, list.boxed-list, list.content, frame > border, .view.frame, scrolledwindow.frame, notebook"
    css += block(cardSel, { "box-shadow": shadowList(cardFrame), "border": "none" })
    if (v === 3) css += block("frame > border", { "border": "none" })
    css += block(popover, { "box-shadow": shadowList(popFrame), "border": "none" })
    css += block("tooltip, tooltip > contents", { "box-shadow": shadowList(controlFrame(o, c.border)) })
    // the headerbar's lower edge in the panel's frame
    var edge = {
        single: ["inset 0 -" + o.w + "px " + c.border],
        double: ["inset 0 -" + o.w + "px " + c.border, "inset 0 -" + (o.w + 2) + "px " + c.surface, "inset 0 -" + (2 * o.w + 2) + "px " + c.muted],
        channel: ["inset 0 -" + o.w + "px " + c.border, "inset 0 -" + (o.w + 2) + "px " + c.base, "inset 0 -" + (2 * o.w + 2) + "px " + c.muted],
        bevel: bevel(o, false),
        none: [],
    }[o.frame]
    css += block("headerbar", { "box-shadow": shadowList(edge), "border-bottom": "none" })

    // separators and section rules in the stroke colour
    css += block("separator", { "background-color": o.frame === "none" ? alpha(c.border, 0.5) : c.border })
    css += block("list.boxed-list > row:not(:last-child), list.content > row:not(:last-child)",
        { "border-bottom": o.frame === "none" ? "none" : o.w + "px solid " + c.border })
    return css
}

// The Qt stylesheet. Qt has no layered shadows, so double and channel are
// a `double` border and bevels are two-tone borders; Fusion draws whatever
// a rule here doesn't take over.
function qss(t) {
    var o = setup(t), c = o.c, css = ""
    var px = n => (n === 9999 ? Math.round(o.h / 2) : n) + "px"
    var ctlR = px(o.ctl), panelR = px(o.panel)
    var buttons = "QPushButton, QToolButton[popupMode], QComboBox"
    // spin boxes stay Fusion's: a sheet on them drops their arrows
    var fields = "QLineEdit, QComboBox:editable, QPlainTextEdit, QTextEdit"
    var lineW = o.w
    function border(col) {
        if (o.frame === "none") return "1px solid transparent"
        return lineW + "px solid " + col
    }
    function bevelEdges(sunken) {
        var a = sunken ? o.bevelDark : o.bevelLight, b = sunken ? o.bevelLight : o.bevelDark
        return { "border-style": "solid", "border-width": lineW + "px",
            "border-top-color": a, "border-left-color": a, "border-bottom-color": b, "border-right-color": b }
    }
    function rest(col) { return o.frame === "bevel" ? bevelEdges(false) : { "border": border(col) } }
    function merge(a, b) { var out = {}; for (var k in a) out[k] = a[k]; for (var k2 in b) out[k2] = b[k2]; return out }

    css += block(buttons, merge(rest(o.stroke), {
        "background": c.surface, "color": c.text, "border-radius": ctlR,
        "min-height": px(o.h - 2 * o.pad - 2), "padding": px(o.pad) + " " + px(o.padX) }))
    var hover = t.r.hoverStyle === "outline" ? { "border-color": o.strokeHover }
        : t.r.hoverStyle === "none" ? {} : { "background": c.overlay }
    if (o.frame !== "bevel" && o.frame !== "none" && t.r.hoverStyle !== "outline") hover["border-color"] = o.strokeHover
    css += block("QPushButton:hover, QToolButton[popupMode]:hover, QComboBox:hover", hover)
    css += block("QPushButton:pressed, QPushButton:checked, QToolButton:checked",
        merge(o.frame === "bevel" ? bevelEdges(true) : {}, { "background": c.overlay }))
    css += block("QPushButton:default", { "background": c.accent, "color": c.onAccent, "border-color": c.accent })
    css += block("QPushButton:disabled, QComboBox:disabled, QLineEdit:disabled", { "color": c.muted })
    css += block("QToolButton", { "border-radius": ctlR, "padding": px(Math.max(2, o.pad - 1)) })
    css += block("QToolButton:hover", { "background": c.overlay })

    css += block(fields, merge(o.frame === "bevel" ? bevelEdges(true) : { "border": border(o.stroke) }, {
        "background": c.bar, "color": c.text, "border-radius": ctlR, "min-height": px(o.h - 8),
        "padding": "0 " + px(Math.round(o.padX * 0.8)),
        "selection-background-color": c.accent, "selection-color": c.onAccent }))
    css += block("QPlainTextEdit, QTextEdit", { "border-radius": panelR, "padding": px(4) })
    css += block("QLineEdit:focus, QPlainTextEdit:focus, QTextEdit:focus", { "border": lineW + "px solid " + c.accent })

    css += block("QCheckBox::indicator, QRadioButton::indicator, QAbstractItemView::indicator", merge(
        o.frame === "bevel" ? bevelEdges(true) : { "border": lineW + "px solid " + o.stroke },
        { "width": "14px", "height": "14px", "background": o.frame === "none" ? c.overlay : c.bar, "border-radius": px(o.check === 9999 ? 8 : o.check) }))
    css += block("QRadioButton::indicator", { "border-radius": o.round === 0 ? "0px" : "8px" })
    css += block("QCheckBox::indicator:checked, QRadioButton::indicator:checked, QAbstractItemView::indicator:checked",
        { "background": c.accent, "border-color": c.accent })

    // panels: group boxes, tab panes, lists, menus, tooltips
    var panelBorder = o.frame === "double" ? (2 * lineW + 1) + "px double " + c.muted
        : o.frame === "channel" ? (2 * lineW + 2) + "px double " + c.muted
        : o.frame === "none" ? "1px solid transparent"
        : lineW + "px solid " + c.border
    var panel = o.frame === "bevel" ? bevelEdges(false) : { "border": panelBorder }
    css += block("QGroupBox", merge(panel, { "border-radius": panelR, "margin-top": "1.4em", "padding": px(Math.round(o.padX * 0.8)), "background": c.surface }))
    css += block("QGroupBox::title", { "subcontrol-origin": "margin", "left": px(o.padX), "padding": "0 4px", "color": c.bright })
    css += block("QTabWidget::pane", merge(panel, { "border-radius": panelR, "top": "-1px", "background": c.surface }))
    css += block("QTabBar::tab", {
        "background": "transparent", "color": c.subtext, "padding": px(o.pad) + " " + px(o.padX + 2),
        "border-radius": ctlR, "margin": "2px", "min-height": px(o.h - 2 * o.pad - 6) })
    css += block("QTabBar::tab:selected", { "background": c.accent, "color": c.onAccent })
    css += block("QTabBar::tab:hover:!selected", { "background": c.overlay, "color": c.text })
    css += block("QListView, QTreeView, QTableView, QListWidget, QTreeWidget", merge(o.frame === "bevel" ? bevelEdges(true) : { "border": panelBorder },
        { "border-radius": panelR, "background": c.bar, "padding": "2px",
          "selection-background-color": c.accent, "selection-color": c.onAccent }))
    css += block("QListView::item, QTreeView::item", { "border-radius": px(Math.max(0, o.ctl === 9999 ? 9999 : o.panel - 2)), "padding": px(Math.round(o.pad * 0.8)) + " " + px(6) })
    css += block("QListView::item:hover, QTreeView::item:hover", { "background": c.overlay })
    css += block("QListView::item:selected, QTreeView::item:selected", { "background": c.accent, "color": c.onAccent })
    css += block("QMenu", merge(panel, { "background": t.isLight ? c.panel : c.overlay, "border-radius": panelR, "padding": "4px" }))
    css += block("QMenu::item", { "padding": px(o.pad) + " " + px(o.padX + 6), "border-radius": px(Math.max(0, o.ctl === 9999 ? 9999 : o.panel - 2)) })
    css += block("QMenu::item:selected", { "background": c.accent, "color": c.onAccent })
    css += block("QToolTip", { "border": border(c.border), "background": c.overlay, "color": c.text, "border-radius": panelR, "padding": "4px" })

    // levels
    var round = o.round === 0 ? "0px" : "4px"
    css += block("QProgressBar", { "border": "none", "background": c.base, "border-radius": round, "max-height": "8px", "text-align": "center", "color": "transparent" })
    css += block("QProgressBar::chunk", { "background": c.accent, "border-radius": round })
    css += block("QSlider::groove:horizontal", { "height": "6px", "background": c.base, "border-radius": o.round === 0 ? "0px" : "3px" })
    css += block("QSlider::sub-page:horizontal", { "background": c.accent, "border-radius": o.round === 0 ? "0px" : "3px" })
    css += block("QSlider::handle:horizontal", { "width": "16px", "margin": "-5px 0", "background": c.bright, "border-radius": o.round === 0 ? "0px" : "8px" })
    css += block("QScrollBar:vertical", { "width": "10px", "background": "transparent" })
    css += block("QScrollBar::handle:vertical", { "background": c.muted, "border-radius": o.round === 0 ? "0px" : "4px", "min-height": "24px", "margin": "2px" })
    css += block("QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page", { "background": "none", "border": "none", "height": "0px" })
    return css
}
