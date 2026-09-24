// Singularity - Quickshell
// ~/.config/quickshell/services/Settings.qml
//
// The handful of shell values the user can change at runtime, persisted to
// JSON so they survive a restart. Everything here is written from the
// Appearance pages (the Control Centre's, and the Settings window's) and the
// few flyouts noted below; nothing else should assign to it.
//
// Theme reads these rather than exposing them directly, so the rest of the
// shell keeps importing one geometry source (Theme.barHeight) and doesn't
// have to know which values happen to be user-editable this week.
//
// Persistence is FileView + JsonAdapter: onAdapterUpdated fires whenever a
// property on the adapter changes, so a write follows every edit without
// any call site remembering to save. watchChanges + reload() is the other
// half -- editing the file by hand (or a second shell instance writing it)
// is picked up live rather than being silently overwritten.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks

Singleton {
    id: root

    // "top" or "bottom" -- which screen edge the bar is anchored to
    readonly property alias barPosition: adapter.barPosition
    readonly property alias barHeight:   adapter.barHeight
    readonly property alias moduleGap:   adapter.moduleGap
    readonly property alias radius:      adapter.radius
    readonly property alias barOpacity:  adapter.barOpacity
    // The base text size in px -- the size of body text, which every other
    // size in the shell, wofi and swaync is scaled from (Theme.fontScale).
    readonly property alias fontSize:    adapter.fontSize
    readonly property int fontSizeBase: 16
    // "normal", "fast" or "off"
    readonly property alias animSpeed:   adapter.animSpeed
    // "grayscale" or "wallpaper"
    readonly property alias colourMode:  adapter.colourMode
    // a matugen scheme type; only read in wallpaper mode
    readonly property alias colourScheme: adapter.colourScheme
    // "dark" or "light", likewise
    readonly property alias colourVariant: adapter.colourVariant
    // pick a random wallpaper at login instead of restoring the last one.
    // Mirrored into the wallpaper state file by Wallpaper.qml, since the
    // login script can't read this JSON.
    readonly property alias wallpaperShuffle: adapter.wallpaperShuffle
    // The active look (Looks.js), and the parts of it the Appearance page can
    // override. Choosing a look writes all four of these, plus the bar and
    // radius values it carries, so a look always arrives whole.
    readonly property alias look:        adapter.look
    // "double" or "single" -- the inner stroke on panels and bar modules
    readonly property alias frameStyle:  adapter.frameStyle
    // "compact", "normal" or "roomy"
    readonly property alias density:     adapter.density
    readonly property alias fontFamily:  adapter.fontFamily
    // GTK/Qt apps' font -- independent of fontFamily above, which is only the
    // shell's own (bar, launcher, notifications). Not part of a look and not
    // touched by reset()/isDefault, same as nightLightKelvin: it's a system
    // preference, not an appearance the shell designs.
    readonly property alias systemFontFamily: adapter.systemFontFamily
    // The pointer and the apps' icons, system preferences in the same way:
    // a theme's directory name (DesktopThemes), and the pointer's size in px.
    readonly property alias cursorTheme: adapter.cursorTheme
    readonly property alias cursorSize:  adapter.cursorSize
    readonly property alias iconTheme:   adapter.iconTheme
    // "outline", "filled", "flat" or "pill"
    readonly property alias moduleStyle: adapter.moduleStyle
    // "full", "floating", "islands" or "bare"
    readonly property alias barStyle:    adapter.barStyle
    // "pills", "numbers" or "blocks" -- the workspace indicator
    readonly property alias workspaceStyle: adapter.workspaceStyle
    // "stamp", "time" or "day" -- what the clock chip shows
    readonly property alias clockStyle:  adapter.clockStyle
    // The look's adjustable fixed half (Looks.adjustable): its accent as a
    // hex, "" for none; flyouts' and windows' ground opacity and the
    // overlay dimming, both in percent; every stroke's width in px; and how
    // section headings are set.
    readonly property alias accent:       adapter.accent
    readonly property alias panelOpacity: adapter.panelOpacity
    readonly property alias borderWidth:  adapter.borderWidth
    readonly property alias scrim:        adapter.scrim
    readonly property alias headingUpper: adapter.headingUpper
    readonly property alias headingBold:  adapter.headingBold
    readonly property alias headingRule:  adapter.headingRule
    readonly property alias headingAccent: adapter.headingAccent

    // What the accent picker offers: every look's own accent, in look order.
    readonly property var accents: {
        var out = []
        for (var i = 0; i < LookStore.order.length; i++) {
            var a = LookStore.looks[LookStore.order[i]].accent
            if (a && out.indexOf(a) === -1) out.push(a)
        }
        return out
    }

    // Cycled through by the Appearance page's choice rows, in this order.
    readonly property var choices: ({
        animSpeed:    ["normal", "fast", "off"],
        colourMode:   ["grayscale", "wallpaper"],
        colourScheme: ["scheme-neutral", "scheme-tonal-spot", "scheme-vibrant", "scheme-expressive"],
        colourVariant: ["dark", "light"],
        look:         LookStore.order,
        frameStyle:   ["double", "single", "bevel", "none"],
        density:      ["compact", "normal", "roomy"],
        fontFamily:   Fonts.available,
        systemFontFamily: Looks.systemFonts,
        cursorTheme:  DesktopThemes.cursors,
        iconTheme:    DesktopThemes.icons,
        moduleStyle:  ["outline", "filled", "flat", "pill", "bracket", "underline"],
        barStyle:     ["full", "floating", "islands", "bare", "notch"],
        workspaceStyle: ["pills", "numbers", "blocks", "roman"],
        clockStyle:   ["stamp", "time", "day", "long"],
    })
    readonly property var choiceLabels: ({
        "normal": "Normal", "fast": "Fast", "off": "Off",
        "grayscale": "Grayscale", "wallpaper": "Wallpaper", "dark": "Dark", "light": "Light",
        "scheme-neutral": "Subtle", "scheme-tonal-spot": "Balanced",
        "scheme-vibrant": "Vivid", "scheme-expressive": "Expressive",
        "double": "Double", "single": "Single", "bevel": "Bevel", "none": "None",
        "compact": "Compact", "roomy": "Roomy",
        "outline": "Outline", "filled": "Filled", "flat": "Flat", "pill": "Pill",
        "bracket": "Brackets", "underline": "Underline",
        "full": "Full width", "floating": "Floating", "islands": "Islands", "bare": "Bare",
        "notch": "Notch",
        "pills": "Pills", "numbers": "Numbers", "blocks": "Blocks", "roman": "Roman",
        "stamp": "Time + date", "time": "Time", "day": "Day + time", "long": "Full date",
    })

    // A choice's display name: the table above, then the look's or font's
    // own name, then the raw value.
    function choiceLabel(v) {
        if (choiceLabels[v]) return choiceLabels[v]
        if (LookStore.looks[v]) return LookStore.looks[v].name
        return Looks.fontLabels[v] || Looks.systemFontLabels[v] || v
    }

    function cycle(key, direction) {
        var list = choices[key]
        direction = direction || 1
        var currentIndex = list.indexOf(adapter[key])
        var newIndex = (currentIndex + direction) % list.length
        if (newIndex < 0) newIndex += list.length
        set(key, list[newIndex])
    }

    function setWallpaperShuffle(on) { adapter.wallpaperShuffle = on }
    // The clock chip briefly turns into the volume/brightness level, the
    // layout just switched to, a new track or new notifications -- instead
    // of those showing as separate toasts under the bar.
    readonly property alias clockIsland: adapter.clockIsland
    function setClockIsland(on) { adapter.clockIsland = on }
    // whether the island is actually showing those, rather than the toasts
    readonly property bool islandActive: clockIsland && widgetVisible("clock")
    // Night Light colour temperature in kelvin. Lower is warmer. Lives here
    // for persistence only -- it isn't part of Appearance, so reset() and
    // isDefault below leave it alone.
    readonly property alias nightLightKelvin: adapter.nightLightKelvin
    // "F" or "C", switched from the weather flyout
    readonly property alias weatherUnits: adapter.weatherUnits
    function setWeatherUnits(u) { adapter.weatherUnits = (u === "C") ? "C" : "F" }

    // --- Bar Widgets ---------------------------------------------------
    // Order and visibility of the bar's modules, edited from the Control
    // Centre's Bar Widgets page. Stored as what the user changed, and read
    // back only through widgetOrder()/widgetVisible(), which reconcile it
    // against the defaults below -- so a module added to the bar in a later
    // update still appears, instead of being missing from a saved order that
    // predates it.

    readonly property var widgetDefaults: ({
        left:   ["controlcentre", "workspaces", "overview", "windows"],
        centre: ["visualizer", "media", "clock", "weather"],
        right:  ["privacy", "failed", "updates", "claude", "notifications", "tray",
                 "bluetooth", "network", "volume", "brightness", "battery"],
    })

    // Every module's name and icon on the Bar Widgets page. A new module
    // needs an entry here, one in widgetDefaults above, and its item in
    // BarModules.widgetItems -- shell.qml warns at load when the three
    // disagree, rather than the page showing a blank icon and a raw key.
    readonly property var widgetMeta: ({
        controlcentre: { label: "Control Centre", icon: "󰣇" },
        workspaces:    { label: "Workspaces",     icon: "󰇘" },
        overview:      { label: "Window Overview", icon: "󰕰" },
        windows:       { label: "Open Windows",   icon: "󰀻" },
        clock:         { label: "Clock",          icon: "󰅐" },
        bluetooth:     { label: "Bluetooth",      icon: "󰂯" },
        network:       { label: "Network",        icon: "󰤨" },
        volume:        { label: "Volume",         icon: "󰕾" },
        brightness:    { label: "Brightness",     icon: "󰃠" },
        battery:       { label: "Battery",        icon: "󰁹" },
        tray:          { label: "System Tray",    icon: "󰀻" },
        media:         { label: "Media Player",   icon: "󰝚" },
        visualizer:    { label: "Audio Visualizer", icon: "󰺢" },
        weather:       { label: "Weather",        icon: "󰖐" },
        notifications: { label: "Notifications",  icon: "󰂚" },
        privacy:       { label: "Privacy",        icon: "󰍬" },
        failed:        { label: "Failed Services", icon: "󰀦" },
        updates:       { label: "Updates",        icon: "󰚰" },
        claude:        { label: "Claude",         icon: "󰚩" },
    })

    // Can't be hidden: the control centre button is the only way back to
    // the page that would un-hide it.
    readonly property var lockedWidgets: ["controlcentre"]

    // Workspaces 1..n have SUPER+n binds and are the only valid targets for a
    // window rule. Must match MAX_WORKSPACES in hyprland.lua.
    readonly property int workspaceCount: 5

    readonly property var widgetSections: ["left", "centre", "right"]

    // The effective layout: every known module in exactly one section, in
    // order. A module goes where it was saved (first section wins if a hand
    // edit lists it twice). Unknown keys in the file are dropped.
    //
    // A module that was never saved -- added to the bar since the layout was
    // written -- goes beside its default neighbours: before the next module
    // that follows it in the defaults, or after the one before it, or at the
    // end if neither is in that section. Appending instead would put every
    // new module after the battery at the far edge.
    function widgetLayout() {
        var saved = adapter.barLayout || {}
        var known = [], homeOf = {}
        for (var s0 = 0; s0 < widgetSections.length; s0++) {
            var d = widgetDefaults[widgetSections[s0]]
            for (var k = 0; k < d.length; k++) { known.push(d[k]); homeOf[d[k]] = widgetSections[s0] }
        }
        var out = { left: [], centre: [], right: [] }, placed = {}
        for (var s1 = 0; s1 < widgetSections.length; s1++) {
            var sec = widgetSections[s1]
            var list = saved[sec] || []
            for (var i = 0; i < list.length; i++) {
                var key = list[i]
                if (known.indexOf(key) === -1 || placed[key]) continue
                out[sec].push(key)
                placed[key] = true
            }
        }
        for (var j = 0; j < known.length; j++) {
            var key2 = known[j]
            if (placed[key2]) continue
            var home = homeOf[key2], defs = widgetDefaults[home], row = out[home]
            var at = -1, di = defs.indexOf(key2)
            for (var a = di + 1; a < defs.length && at < 0; a++)
                if (placed[defs[a]] && row.indexOf(defs[a]) !== -1) at = row.indexOf(defs[a])
            for (var b = di - 1; b >= 0 && at < 0; b--)
                if (placed[defs[b]] && row.indexOf(defs[b]) !== -1) at = row.indexOf(defs[b]) + 1
            if (at < 0) row.push(key2)
            else row.splice(at, 0, key2)
            placed[key2] = true
        }
        return out
    }

    function widgetOrder(section) {
        return widgetLayout()[section] || []
    }

    function widgetSection(key) {
        var l = widgetLayout()
        for (var i = 0; i < widgetSections.length; i++)
            if (l[widgetSections[i]].indexOf(key) !== -1) return widgetSections[i]
        return "left"
    }

    function widgetVisible(key) {
        return lockedWidgets.indexOf(key) !== -1
            || (adapter.barHidden || []).indexOf(key) === -1
    }

    function setWidgetVisible(key, on) {
        if (lockedWidgets.indexOf(key) !== -1) return
        var h = (adapter.barHidden || []).filter(k => k !== key)
        if (!on) h.push(key)
        adapter.barHidden = h
    }

    // The whole layout at once, since a move between sections changes two
    // of them. A fresh object, not a mutation: the adapter only notices --
    // and writes, and the bar only repositions -- on reassignment.
    function setWidgetLayout(layout) {
        adapter.barLayout = {
            left:   (layout.left   || []).slice(),
            centre: (layout.centre || []).slice(),
            right:  (layout.right  || []).slice(),
        }
    }

    // The centre module pinned to the exact middle of the bar. The other
    // centre modules stack outward from it -- those before it in the order to
    // its left, those after to its right -- so a media title appearing never
    // nudges the clock. "" (or a module that isn't in the centre, or is
    // hidden) centres the whole group instead.
    readonly property alias centreAnchor: adapter.centreAnchor
    function setCentreAnchor(key) { adapter.centreAnchor = key }

    function resetWidgets() {
        adapter.barLayout = {}
        adapter.barHidden = []
        adapter.centreAnchor = "clock"
    }

    // Reads both properties on every evaluation, with no early return. A
    // binding only re-runs when something it *read last time* changes: an
    // early `return false` on a hidden widget skipped reading the order, so
    // resetting the order afterwards never re-ran this and it stuck at false.
    readonly property bool widgetsDefault: {
        var noneHidden = (adapter.barHidden || []).length === 0
            && adapter.centreAnchor === "clock"
        var ordersMatch = true
        for (var section in widgetDefaults)
            if (JSON.stringify(widgetOrder(section)) !== JSON.stringify(widgetDefaults[section]))
                ordersMatch = false
        return noneHidden && ordersMatch
    }

    // The bounds the Appearance page clamps to. Kept here next to the
    // values rather than in the menu, so a hand-edited JSON file that is
    // out of range is corrected by the same numbers the UI enforces.
    readonly property var limits: ({
        barHeight: { min: 24, max: 48 },
        moduleGap: { min: 0,  max: 12 },
        radius:    { min: 0,  max: 14 },
        barOpacity: { min: 40, max: 100 },
        fontSize:  { min: 12, max: 22 },
        panelOpacity: { min: 50, max: 100 },
        borderWidth:  { min: 1,  max: 3 },
        scrim:        { min: 0,  max: 80 },
        nightLightKelvin: { min: 2500, max: 6000 },
        cursorSize:   { min: 16, max: 48 },
    })

    // Stock: the fallback look, with its own settings layered over the values
    // no look sets.
    readonly property var stockDefaults: {
        var d = {
            look: Looks.fallback,
            fontSize: 16,
            animSpeed: "normal",
            colourMode: "grayscale",
            colourScheme: "scheme-tonal-spot",
            colourVariant: "dark",
        }
        var ls = Looks.looks[Looks.fallback].settings
        for (var k in ls) d[k] = ls[k]
        return d
    }

    // What Reset returns to: stock, overlaid with whatever was last saved
    // with "Set as default". Only keys stock knows are taken from the saved
    // set, so a hand-edited or outdated file can't smuggle in anything else,
    // and a key added to stock later still has a value.
    readonly property var defaults: {
        var d = {}, u = adapter.userDefaults || {}
        for (var k in stockDefaults)
            d[k] = u[k] !== undefined ? u[k] : stockDefaults[k]
        return d
    }

    readonly property bool hasUserDefault: Object.keys(adapter.userDefaults || {}).length > 0

    // The current appearance becomes the default. A fresh object, so the
    // adapter notices and writes it.
    function saveAsDefault() {
        var snap = {}
        for (var k in stockDefaults) snap[k] = adapter[k]
        adapter.userDefaults = snap
    }

    // Forget the saved default and go back to stock.
    function factoryReset() {
        adapter.userDefaults = {}
        root.applyLayout(adapter.look, stockDefaults.look)
        for (var k in stockDefaults) adapter[k] = stockDefaults[k]
    }

    // Everything the look carries, written at once. The bar's opacity is only
    // taken in grayscale mode: in wallpaper mode it keeps the lower wallpaper
    // default (see barOpacityDefaults), which a look's value would undo.
    function applyLook(name) {
        var l = LookStore.looks[name]
        if (!l) return
        root.applyLayout(adapter.look, name)
        adapter.look = name
        for (var k in l.settings) {
            if (k === "barOpacity" && adapter.colourMode === "wallpaper") continue
            adapter[k] = l.settings[k]
        }
    }

    // A look's own module layout (Looks.js `layout`) replaces Bar Widgets'.
    // The user's arrangement is set aside on the way in and put back on the
    // way out to a look without one.
    function applyLayout(from, to) {
        var a = LookStore.looks[from], b = LookStore.looks[to]
        var lay = b && b.layout
        var hadOwn = !(a && a.layout)
        if (!lay) {
            if (hadOwn) return
            var own = adapter.ownLayout || {}
            if (!own.barLayout) { resetWidgets(); return }
            adapter.barLayout = own.barLayout
            adapter.barHidden = own.barHidden || []
            adapter.centreAnchor = own.centreAnchor !== undefined ? own.centreAnchor : "clock"
            adapter.ownLayout = {}
            return
        }
        if (hadOwn)
            adapter.ownLayout = { barLayout: adapter.barLayout, barHidden: adapter.barHidden,
                                  centreAnchor: adapter.centreAnchor }
        setWidgetLayout(lay)
        adapter.barHidden = (lay.hidden || []).slice()
        adapter.centreAnchor = lay.anchor !== undefined ? lay.anchor : "clock"
    }

    // true while every value the look carries is still the look's own --
    // what the Appearance page shows as "as designed" vs "customised"
    readonly property bool lookPristine: {
        var l = LookStore.looks[adapter.look]
        if (!l) return false
        var diffs = Object.keys(l.settings).filter(k =>
            !(k === "barOpacity" && adapter.colourMode === "wallpaper") && adapter[k] !== l.settings[k])
        return diffs.length === 0
    }

    function clamp(key, v) {
        var l = limits[key]
        return Math.max(l.min, Math.min(l.max, Math.round(v)))
    }

    // Single entry point for the menu, so clamping can't be forgotten at a
    // call site and every write goes through one place.
    function set(key, v) {
        if (key === "barPosition") adapter.barPosition = (v === "bottom") ? "bottom" : "top"
        else if (key === "colourMode") setColourMode(v)
        else if (key === "look") applyLook(v)
        else if (key === "accent") adapter.accent = /^#[0-9a-fA-F]{6}$/.test(v) ? v : ""
        else if (typeof adapter[key] === "boolean") adapter[key] = !!v
        else if (choices[key]) { if (choices[key].indexOf(v) !== -1) adapter[key] = v }
        else adapter[key] = clamp(key, v)
    }

    // The bar's opacity defaults lower on the wallpaper palette, so the
    // wallpaper shows through a bar tinted to match it. Switching palette
    // always moves to the new palette's opacity: a see-through bar kept
    // after switching to grayscale still shows the wallpaper's colours
    // through it, which reads as the switch not having happened. Opacity
    // sits right under the palette switch to adjust afterwards. Here rather
    // than in an on-changed handler, which would also fire on a reload of
    // the file. Grayscale's default is the look's own.
    readonly property var barOpacityDefaults: ({
        grayscale: (LookStore.looks[adapter.look] || Looks.looks[Looks.fallback]).settings.barOpacity,
        wallpaper: 85,
    })

    function setColourMode(v) {
        if (choices.colourMode.indexOf(v) === -1 || v === adapter.colourMode) return
        adapter.barOpacity = barOpacityDefaults[v]
        adapter.colourMode = v
    }

    function step(key, delta) { set(key, adapter[key] + delta) }

    // A file written before the look's fixed half was adjustable has none of
    // those keys, so the adapter's declared defaults -- Neutrino's -- would
    // strip another look of its accent and headings. Filled in once from the
    // look in use; `adjustableSeeded` stops it redoing that over later edits.
    function seedAdjustable() {
        if (adapter.adjustableSeeded) return
        var l = LookStore.looks[adapter.look] || Looks.looks[Looks.fallback]
        var a = Looks.adjustable(l)
        for (var k in a) adapter[k] = a[k]
        adapter.adjustableSeeded = true
    }

    function reset() {
        root.applyLayout(adapter.look, defaults.look)
        for (var key in defaults) adapter[key] = defaults[key]
    }

    // Back to the current look as designed, keeping the look itself and the
    // values no look sets (font size, motion, colour mode).
    function resetLook() { applyLook(adapter.look) }

    // Deletes a look from looks.json. Anything still pointing at it -- the
    // look in use, or the saved default -- moves to the fallback first, so
    // nothing is left naming a look that no longer exists.
    // done(ok, message)
    function removeLook(name, done) {
        if (!LookStore.removable(name)) return
        if (adapter.look === name) applyLook(Looks.fallback)
        var u = adapter.userDefaults || {}
        if (u.look === name) {
            var c = {}
            for (var k in u) c[k] = u[k]
            c.look = Looks.fallback
            adapter.userDefaults = c
        }
        LookStore.remove(name, done)
    }

    // filter, not every(): every() stops at the first difference, and a
    // binding only re-runs for what it read last time (see widgetsDefault)
    readonly property bool isDefault:
        Object.keys(defaults).filter(key => adapter[key] !== defaults[key]).length === 0

    // No mkdir for the state directory: FileView's writes (writeAdapter and
    // setText, atomic or not) create any missing parent directories
    // themselves -- checked against Quickshell on 2026-09-18.

    // Writes are held until the first read has landed. Without this the
    // adapter's declared defaults count as an update the moment it is
    // constructed, so the very first thing the shell does on startup is
    // save 32/top/2/6 over whatever the user had -- the settings appear to
    // work until you restart, then silently reset. blockLoading makes that
    // first read synchronous, so by the time this component is complete the
    // adapter already holds the file's values and writing is safe.
    property bool ready: false

    // Writes are coalesced: a burst of changes (a reset assigns several
    // properties back to back) becomes one write a moment after the last.
    // Writing per change raced with watchChanges -- the first write's
    // change notification made the file reload *between* the writes, which
    // read the half-finished state back over the newer in-memory values. The
    // file ended up right while the running shell kept the stale one.
    Timer {
        id: saveTimer
        interval: 150
        onTriggered: view.writeAdapter()
    }

    FileView {
        id: view
        path: Quickshell.statePath("appearance.json")
        // preload, or nothing ever reads the file: a FileView is lazy and
        // only loads when someone asks for text()/data(), which nothing
        // here does -- the adapter is the only consumer. Without it the
        // saved values sit on disk and the shell silently runs on the
        // adapter's declared defaults.
        preload: true
        // ...and blocking, so the values are in the adapter before Theme
        // binds to them, rather than the bar rendering at the defaults and
        // jumping a frame later.
        blockLoading: true
        watchChanges: true
        // Expected on a fresh install: there is no file until the first
        // edit, and the defaults on the adapter are the right answer.
        printErrors: false

        // The gate opens once the first read has resolved one way or the
        // other -- loaded with the file's values, or failed because there
        // is no file yet and the declared defaults are already correct.
        // (Neither this object nor the singleton root has a Component
        // attached object to hook instead.)
        onLoaded: {
            root.ready = true
            // Font size used to be a percentage. Carried over once, then the
            // old key is parked at 100 so this never runs again.
            if (adapter.fontScale !== 100) {
                adapter.fontSize = root.clamp("fontSize", root.fontSizeBase * adapter.fontScale / 100)
                adapter.fontScale = 100
            }
            root.seedAdjustable()
        }
        onLoadFailed: {
            root.ready = true
            root.seedAdjustable()
        }

        onFileChanged: reload()
        onAdapterUpdated: if (root.ready) saveTimer.restart()

        JsonAdapter {
            id: adapter
            property string barPosition: "top"
            property int barHeight: 32
            property int moduleGap: 2
            property int radius: 6
            property int barOpacity: 100
            property int fontSize: 16
            // superseded by fontSize; read once to migrate (see onLoaded)
            property int fontScale: 100

            property string animSpeed: "normal"
            property string colourMode: "grayscale"
            property string colourScheme: "scheme-tonal-spot"
            property string colourVariant: "dark"
            property string look: "neutrino"
            property string frameStyle: "double"
            property string density: "normal"
            property string fontFamily: "UbuntuMono Nerd Font"
            property string systemFontFamily: "Ubuntu Nerd Font"
            property string cursorTheme: "Bibata-Modern-Classic"
            property int cursorSize: 20
            property string iconTheme: "kora"
            property string moduleStyle: "outline"
            property string barStyle: "full"
            property string workspaceStyle: "pills"
            property string clockStyle: "stamp"
            property string accent: ""
            property int panelOpacity: 100
            property int borderWidth: 1
            property int scrim: 40
            property bool headingUpper: true
            property bool headingBold: true
            property bool headingRule: true
            property bool headingAccent: false
            property bool adjustableSeeded: false

            property bool wallpaperShuffle: true
            property bool clockIsland: true
            property int nightLightKelvin: 4000
            property string weatherUnits: "F"
            property string centreAnchor: "clock"
            property var barLayout: ({})
            property var barHidden: []
            // Bar Widgets' arrangement, held while a look with its own
            // layout is on (applyLayout)
            property var ownLayout: ({})
            // the appearance saved with "Set as default"; {} means stock
            property var userDefaults: ({})

        }
    }
}
