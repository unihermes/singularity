// Singularity - Quickshell
// ~/.config/quickshell/services/Settings.qml
//
// The settings the user changes at runtime, persisted as JSON. Written only
// through set() from Settings, the Control Centre and a few flyouts; Theme
// reads them. FileView + JsonAdapter save on every change and pick up edits
// to the file live (watchChanges).

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks
import "Styles.js" as Styles

Singleton {
    id: root

    // Everything the shell and its scripts save or generate, in one place
    // outside ~/.config: those directories are stow links into the repo.
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/singularity"

    // "top" or "bottom" -- which screen edge the bar is anchored to
    readonly property alias barPosition: adapter.barPosition
    // Roundness: chips, panels, the bar and Hyprland's windows
    readonly property alias radius:      adapter.radius
    // The base text size in px -- the size of body text, which every other
    // size in the shell is scaled from (Theme.fontScale).
    readonly property alias fontSize:    adapter.fontSize
    readonly property int fontSizeBase: 16
    // how long animations take, as a percentage of their normal length:
    // 100 normal, 50 fast, 0 off
    readonly property alias animTime:    adapter.animTime
    // and on top of it, the same for Hyprland's windows, its workspaces,
    // and the shell's own motion (flyouts, hovers, meters)
    readonly property alias animWindows: adapter.animWindows
    readonly property alias animWorkspaces: adapter.animWorkspaces
    readonly property alias animShell:   adapter.animShell
    // "grayscale" or "wallpaper"
    readonly property alias colourMode:  adapter.colourMode
    // a matugen scheme type; only read in wallpaper mode
    readonly property alias colourScheme: adapter.colourScheme
    // "dark" or "light", likewise
    readonly property alias colourVariant: adapter.colourVariant
    // a random wallpaper at login; mirrored to the wallpaper state file for
    // the login script
    readonly property alias wallpaperShuffle: adapter.wallpaperShuffle
    // minutes between random wallpapers while logged in; 0 never changes it
    readonly property alias wallpaperInterval: adapter.wallpaperInterval
    // how the wallpaper fits the screen: swaybg's fill, fit, center or tile
    readonly property alias wallpaperFill: adapter.wallpaperFill
    // The active look (Looks.js): the colours. Choosing one writes all of
    // them and leaves the rest, which is the style's.
    readonly property alias look:        adapter.look
    // how all the chrome is drawn: one of Styles.order (Styles.js); picking
    // one lands on its default (styleDefaultOf)
    readonly property alias style:       adapter.style
    // the style's own options that are on, as comma-joined ids (Styles.js
    // `options`; Theme.opt reads them)
    readonly property alias styleOptions: adapter.styleOptions
    // the bar's and panels' opacity, in percent
    readonly property alias seeThrough:  adapter.seeThrough
    // The Finish switches, safe with any style: its shadow on or off, every
    // stroke 2px, and the colour level fills take ("accent", "good", "text")
    readonly property alias shadows:     adapter.shadows
    readonly property alias heavyLines:  adapter.heavyLines
    // Plain over any style (Theme.plain)
    readonly property alias plain:       adapter.plain
    readonly property alias levelColour: adapter.levelColour
    // Space's dials and the bar's size (Styles.stock); `density` names the
    // preset they match, "custom" for none
    readonly property alias spacing:     adapter.spacing
    readonly property alias rowScale:    adapter.rowScale
    readonly property alias barHeight:   adapter.barHeight
    readonly property alias barIconSize: adapter.barIconSize
    readonly property alias modulePad:   adapter.modulePad
    // How Hyprland draws windows beyond the Hyprland tables (Styles.stock,
    // the border colours Looks.colourBase)
    readonly property alias windowBorderWidth: adapter.windowBorderWidth
    readonly property alias windowBorderFocused: adapter.windowBorderFocused
    readonly property alias windowBorderFocusedHex: adapter.windowBorderFocusedHex
    readonly property alias windowBorderUnfocused: adapter.windowBorderUnfocused
    readonly property alias windowBorderUnfocusedHex: adapter.windowBorderUnfocusedHex
    readonly property alias windowRounding: adapter.windowRounding
    readonly property alias windowRadius: adapter.windowRadius
    readonly property alias windowShadow: adapter.windowShadow
    readonly property alias tabBar:      adapter.tabBar
    // bar flyouts' width (percent), the launcher's rows, the popups' width
    readonly property alias flyoutWidth: adapter.flyoutWidth
    readonly property alias launcherRows: adapter.launcherRows
    readonly property alias notifWidth:  adapter.notifWidth
    readonly property string density: {
        for (var k in Looks.densities) {
            var d = Looks.densities[k]
            if (d.spacing === adapter.spacing && d.rowScale === adapter.rowScale && d.barHeight === adapter.barHeight) return k
        }
        return "custom"
    }
    function setDensity(name) {
        var d = Looks.densities[name]
        if (!d) return
        adapter.spacing = d.spacing
        adapter.rowScale = d.rowScale
        adapter.barHeight = d.barHeight
    }
    readonly property alias fontFamily:  adapter.fontFamily
    // GTK/Qt apps' font, apart from the shell's fontFamily; a system
    // preference, so reset() leaves it
    readonly property alias systemFontFamily: adapter.systemFontFamily
    // The pointer and the apps' icons, system preferences in the same way:
    // a theme's directory name (DesktopThemes), and the pointer's size in px.
    readonly property alias cursorTheme: adapter.cursorTheme
    readonly property alias cursorSize:  adapter.cursorSize
    readonly property alias iconTheme:   adapter.iconTheme
    // how Hyprland's windows open, close and minimize (AppearanceSync), the
    // style's like the rest of Motion
    readonly property alias windowAnim:  adapter.windowAnim
    // "full", "floating" or "islands"
    readonly property alias barStyle:    adapter.barStyle
    // px between the screen's edges and the windows (Hyprland's gaps_out,
    // handed over by AppearanceSync), and a floating bar or its islands
    readonly property alias edgeGap:     adapter.edgeGap
    // Hyprland's focused and unfocused window opacity, in percent (handed
    // over by AppearanceSync)
    readonly property alias focusedOpacity:   adapter.focusedOpacity
    readonly property alias unfocusedOpacity: adapter.unfocusedOpacity
    // The terminal's background opacity, in percent (handed over by
    // AppearanceSync in the config each terminal imports)
    readonly property alias terminalOpacity:  adapter.terminalOpacity
    // "alacritty" or "ghostty"; a system preference, read by `terminal`
    readonly property alias terminalApp: adapter.terminalApp
    readonly property string terminal: Quickshell.env("HOME") + "/.config/singularity/terminal.sh"
    // "pills", "dots", "lines", "blocks", "numbers" or "roman" -- the workspace indicator
    readonly property alias workspaceStyle: adapter.workspaceStyle
    // one of choices.controlIcon -- the Control Centre button's glyph
    readonly property alias controlIcon: adapter.controlIcon
    // "stamp", "time", "seconds", "day", "long" or "iso" -- what the clock chip shows
    readonly property alias clockStyle:  adapter.clockStyle
    readonly property alias windowStyle: adapter.windowStyle
    readonly property alias windowScope: adapter.windowScope
    readonly property alias windowIconSize: adapter.windowIconSize
    readonly property alias windowIconPadding: adapter.windowIconPadding
    // how an app's windows list when its strip icon is clicked
    readonly property alias iconTint:    adapter.iconTint
    readonly property alias vizStyle:    adapter.vizStyle
    // the Music module: whether it shows the spectrum and the track's
    // title, how many bands the spectrum has, and whether it hides once
    // nothing sounds (else it stays while a player is open)
    readonly property alias vizShown:    adapter.vizShown
    readonly property alias musicTitle:  adapter.musicTitle
    readonly property alias vizBars:     adapter.vizBars
    readonly property alias vizHideSilent: adapter.vizHideSilent
    readonly property alias gradient:    adapter.gradient
    readonly property alias levelStyle:  adapter.levelStyle
    readonly property alias powerStyle:  adapter.powerStyle
    readonly property alias overviewBackdrop: adapter.overviewBackdrop
    readonly property alias overviewLayout: adapter.overviewLayout
    readonly property alias altTabStyle: adapter.altTabStyle
    readonly property alias altTabScope: adapter.altTabScope
    readonly property alias lockNotifs:  adapter.lockNotifs
    readonly property alias lockMedia:   adapter.lockMedia
    readonly property alias lockDate:    adapter.lockDate
    readonly property alias lockClockPlace: adapter.lockClockPlace
    readonly property alias lockClockSize: adapter.lockClockSize
    readonly property alias clockFormat: adapter.clockFormat
    readonly property alias trayDrawer:  adapter.trayDrawer
    readonly property alias workspaceNames: adapter.workspaceNames
    readonly property alias barSeparator: adapter.barSeparator
    // how the bar's chips are framed: "auto" the style's own, or bare,
    // outlined, or one strip per group, under any style (Styles.resolve)
    readonly property alias barChips: adapter.barChips
    readonly property alias notifGroup:  adapter.notifGroup
    readonly property alias notifStyle:  adapter.notifStyle
    readonly property alias launcherDetails: adapter.launcherDetails
    readonly property alias launcherPosition: adapter.launcherPosition
    readonly property alias launcherLayout: adapter.launcherLayout
    // how flyouts open: "auto" leaves it to the style
    readonly property alias flyoutAnim:  adapter.flyoutAnim
    // the look's adjustable half (Looks.adjustable): accent hex ("" for
    // none), overlay dimming; then the headings' Finish switches
    readonly property alias accent:       adapter.accent
    // The ramp's roles one by one and the status hues, "" for the look's
    // own; and the text on accent fills (Looks.js)
    readonly property alias paletteBase: adapter.paletteBase
    readonly property alias paletteBar: adapter.paletteBar
    readonly property alias palettePanel: adapter.palettePanel
    readonly property alias paletteSurface: adapter.paletteSurface
    readonly property alias paletteOverlay: adapter.paletteOverlay
    readonly property alias paletteBorder: adapter.paletteBorder
    readonly property alias paletteMuted: adapter.paletteMuted
    readonly property alias paletteSubtext: adapter.paletteSubtext
    readonly property alias paletteText: adapter.paletteText
    readonly property alias paletteBright: adapter.paletteBright
    readonly property alias colourGood:   adapter.colourGood
    readonly property alias colourAlert:  adapter.colourAlert
    readonly property alias accentText:   adapter.accentText
    readonly property alias scrim:        adapter.scrim
    readonly property alias headingUpper: adapter.headingUpper
    readonly property alias headingRule:  adapter.headingRule
    // the mark drawn before every heading ("" for none), its colour, and
    // the headings' size against body text
    readonly property alias headingMark:  adapter.headingMark
    // the marks that draw a shape (Theme.headingShape); longer than a
    // typed mark can be, so the two never meet
    readonly property var headingShapes: ["shape-bar", "shape-brackets", "shape-tab", "shape-tag"]
    readonly property alias headingMarkColour: adapter.headingMarkColour
    readonly property alias headingSize:  adapter.headingSize

    // What the accent picker offers: the look's own accent first, then the
    // presets in Looks.js, then the accent in use if it's a custom one.
    readonly property string lookAccent: {
        var l = Looks.looks[adapter.look]
        return l && l.accent ? l.accent : ""
    }
    readonly property var accents: {
        var out = lookAccent !== "" ? [lookAccent] : []
        for (var i = 0; i < Looks.accents.length; i++)
            if (out.indexOf(Looks.accents[i]) === -1) out.push(Looks.accents[i])
        if (adapter.accent !== "" && out.indexOf(adapter.accent) === -1) out.push(adapter.accent)
        return out
    }

    // Cycled through by the Appearance page's choice rows, in this order.
    readonly property var choices: ({
        colourMode:   ["grayscale", "wallpaper"],
        colourScheme: ["scheme-neutral", "scheme-tonal-spot", "scheme-vibrant", "scheme-expressive"],
        colourVariant: ["dark", "light"],
        accentText:   ["auto", "white", "dark"],
        headingMarkColour: ["accent", "text", "muted"],
        headingSize:  ["smaller", "same", "larger"],
        windowBorderWidth: ["style", "0", "1", "2", "3"],
        windowBorderFocused: ["accent", "text", "custom"],
        windowBorderUnfocused: ["border", "none", "custom"],
        windowRounding: ["shell", "own"],
        windowShadow: ["style", "off", "small", "large"],
        tabBar:       ["shell", "accent"],
        wallpaperFill: ["fill", "fit", "center", "tile"],
        look:         Looks.order,
        style:        Styles.order,
        density:      ["compact", "normal", "roomy", "custom"],
        fontFamily:   Fonts.available,
        systemFontFamily: Looks.systemFonts,
        terminalApp:  ["alacritty", "ghostty"],
        cursorTheme:  DesktopThemes.cursors,
        iconTheme:    DesktopThemes.icons,
        windowAnim:   ["popin", "zoom", "fade", "fold", "slide", "rise", "drop", "none"],
        barStyle:     ["full", "floating", "islands"],
        workspaceStyle: ["pills", "dots", "lines", "blocks", "numbers", "roman", "names", "apps"],
        controlIcon:  ["arch", "menu", "dashboard", "cog", "home", "star", "blackhole", "vortex", "horizon",
                      "atom", "rocket", "ghost", "planet", "sparkle", "infinity", "radar", "moon"],
        clockStyle:   ["stamp", "time", "seconds", "day", "long", "iso", "custom"],
        windowStyle:  ["icons", "titled", "glide", "lift", "inset", "segmented", "spotlight", "tabs", "index", "dots"],
        windowScope:  ["workspace", "all"],
        iconTint:     ["colour", "mono", "accent"],
        vizStyle:     ["mirror", "rise", "dots", "line"],
        levelColour:  ["accent", "good", "text"],
        levelStyle:   ["pill", "edge", "number"],
        powerStyle:   ["row", "list", "full"],
        overviewBackdrop: ["dim", "clear", "solid"],
        overviewLayout: ["grid", "strip"],
        altTabStyle:  ["icons", "titled", "previews"],
        altTabScope:  ["workspace", "all"],
        lockClockPlace: ["centre", "top", "corner"],
        lockClockSize: ["small", "large", "huge"],
        barSeparator: ["none", "line", "double", "dot", "dots", "capped"],
        barChips:     ["auto", "bare", "outline", "grouped"],
        notifStyle:   ["full", "compact", "banner"],
        launcherPosition: ["centre", "top", "full"],
        launcherLayout: ["list", "grid", "line"],
        flyoutAnim:   ["auto", "drop", "fade", "scale", "none"],
    })
    readonly property var choiceLabels: ({
        "normal": "Normal", "auto": "Style's own", "grayscale": "Grayscale",
        "wallpaper": "Wallpaper", "dark": "Dark", "light": "Light", "scheme-neutral": "Subtle",
        "scheme-tonal-spot": "Balanced", "scheme-vibrant": "Vivid",
        "scheme-expressive": "Expressive", "double": "Double", "accent": "Accent", "none": "None",
        "compact": "Compact", "roomy": "Roomy", "pill": "Pill", "full": "Full",
        "floating": "Floating", "islands": "Islands", "pills": "Pills", "dots": "Dots",
        "lines": "Lines", "numbers": "Numbers", "blocks": "Blocks", "roman": "Roman",
        "names": "Names", "apps": "App icons", "popin": "Pop", "zoom": "Zoom", "fade": "Fade",
        "fold": "Fold", "slide": "Slide", "rise": "Rise", "drop": "Drop", "scale": "Scale",
        "stamp": "Time + date", "time": "Time", "seconds": "Seconds", "day": "Day + time",
        "long": "Full date", "iso": "ISO date", "custom": "Custom", "icons": "Icons",
        "titled": "With titles", "tabs": "Tabs", "previews": "Previews", "glide": "Glide",
        "inset": "Inset", "segmented": "Segmented", "spotlight": "Spotlight", "index": "Index",
        "workspace": "This workspace", "all": "All workspaces", "dot": "Dot", "colour": "Colour",
        "mono": "Mono", "mirror": "Mirrored", "line": "Line", "lift": "Lift", "edge": "Screen edge",
        "number": "Number", "row": "Row", "list": "List", "grid": "Grid", "strip": "Strip",
        "dim": "Dimmed", "clear": "Clear", "solid": "Solid", "banner": "Banner", "centre": "Centre",
        "arch": "Arch", "menu": "Menu", "dashboard": "Dashboard", "cog": "Cog", "home": "Home",
        "star": "Star", "blackhole": "Black hole", "vortex": "Vortex", "horizon": "Event horizon",
        "radar": "Radar", "moon": "Moon", "atom": "Atom",
        "rocket": "Rocket", "ghost": "Ghost", "planet": "Planet", "sparkle": "Sparkle",
        "infinity": "Infinity", "white": "White", "smaller": "Smaller", "same": "Same",
        "larger": "Larger", "muted": "Muted", "text": "Text", "alacritty": "Alacritty", "ghostty": "Ghostty", "top": "Top", "corner": "Corner", "small": "Small", "large": "Large", "huge": "Huge",
    })
    // where one value means different things under different settings
    readonly property var keyedLabels: ({
        barStyle: { "full": "Full width" },
        windowStyle: { "titled": "Focused title" },
        barChips: { "bare": "Bare", "outline": "Outlined", "grouped": "Strip" },
        vizStyle: { "rise": "Rising", "line": "One line" },
        barSeparator: { "line": "Lines", "double": "Double lines", "dot": "Dots",
                        "dots": "Stacked dots", "capped": "Capped lines" },
        windowMark: { "pill": "Pill" },
        levelStyle: { "pill": "Bar" },
        levelColour: { "accent": "Accent", "good": "Green", "text": "Text" },
        accentText: { "auto": "Auto" },
        windowBorderWidth: { "style": "Style's", "0": "None", "1": "1px", "2": "2px", "3": "3px" },
        windowBorderFocused: { "custom": "Custom" },
        windowBorderUnfocused: { "border": "Border", "custom": "Custom" },
        windowRounding: { "shell": "Match shell", "own": "Own" },
        windowShadow: { "style": "Style's", "off": "Off", "small": "Small", "large": "Large" },
        tabBar: { "shell": "Shell's colours" },
        wallpaperFill: { "fill": "Fill", "fit": "Fit", "center": "Centre", "tile": "Tile" },
        launcherLayout: { "line": "One line" },
        launcherPosition: { "top": "Under the bar", "full": "Full screen" },
        powerStyle: { "full": "Full screen" },
        overviewLayout: { "strip": "One row" },
    })

    // a choice's display name: the table above, then the look's or font's
    // own, then the raw value. `key`: the setting it belongs to (keyedLabels)
    function choiceLabel(v, key) {
        if (key && keyedLabels[key] && keyedLabels[key][v]) return keyedLabels[key][v]
        if (key === "style") return Styles.get(v).name
        if (choiceLabels[v]) return choiceLabels[v]
        if (Looks.looks[v]) return Looks.looks[v].name
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
    // tray items kept out of the tray drawer, by id
    // the channels' EQ gains the user moved off their defaults, as
    // { channel: { band: dB } } (Channels.eq)
    readonly property alias channelEq: adapter.channelEq
    function setChannelEq(v) { adapter.channelEq = v }
    readonly property alias trayPinned: adapter.trayPinned
    function setTrayPinned(id, on) {
        var l = adapter.trayPinned.filter(x => x !== id)
        if (on) l.push(id)
        adapter.trayPinned = l
    }
    // tray items left out of the tray altogether, by name (Bar.trayName)
    readonly property alias trayHidden: adapter.trayHidden
    function setTrayHidden(name, on) {
        var l = adapter.trayHidden.filter(x => x !== name)
        if (on) l.push(name)
        adapter.trayHidden = l
    }
    // the tray's order, by id, as the icons were last dragged into: apps
    // not running keep their place in it for when they come back
    readonly property alias trayOrder: adapter.trayOrder
    function setTrayOrder(l) { adapter.trayOrder = l }
    // the clock chip briefly shows levels, layouts, tracks and notifications
    // in place of toasts
    readonly property alias clockIsland: adapter.clockIsland
    function setClockIsland(on) { adapter.clockIsland = on }
    // whether the island is actually showing those, rather than the toasts
    readonly property bool islandActive: clockIsland && widgetVisible("clock")
    // Night Light's temperature in kelvin; not Appearance, so reset() leaves it
    readonly property alias nightLightKelvin: adapter.nightLightKelvin
    // Night Light's schedule: "off", "sun" (sunset to sunrise, from the
    // weather) or "custom" (the two times below, minutes after midnight)
    readonly property alias nightLightSchedule: adapter.nightLightSchedule
    readonly property alias nightLightFrom: adapter.nightLightFrom
    readonly property alias nightLightTo: adapter.nightLightTo
    function setNightLightSchedule(v) {
        if (["off", "sun", "custom"].indexOf(v) >= 0) adapter.nightLightSchedule = v
    }
    // a schedule time, stepped with wrap-around past midnight
    function setScheduleTime(key, minutes) {
        if (["nightLightFrom", "nightLightTo", "notifQuietFrom", "notifQuietTo"].indexOf(key) >= 0)
            adapter[key] = ((Math.round(minutes) % 1440) + 1440) % 1440
    }
    // "F" or "C", switched from the weather flyout
    readonly property alias weatherUnits: adapter.weatherUnits
    function setWeatherUnits(u) { adapter.weatherUnits = (u === "C") ? "C" : "F" }
    // Date & Time: the hour format and the calendar's first weekday (0 Sunday);
    // system preferences, untouched by looks and reset
    readonly property alias clock24: adapter.clock24
    readonly property alias weekStart: adapter.weekStart
    function setClock24(on) { adapter.clock24 = !!on }
    function setWeekStart(d) { if (d === 0 || d === 1 || d === 6) adapter.weekStart = d }
    // Recording: instant replay while a game has focus, how many seconds it
    // keeps, and the codec ("av1" where the GPU has it, or "h264")
    readonly property alias replayOn: adapter.replayOn
    readonly property alias replaySeconds: adapter.replaySeconds
    readonly property alias recordCodec: adapter.recordCodec
    function setRecordCodec(c) { adapter.recordCodec = c === "h264" ? "h264" : "av1" }
    function setReplayOn(on) { adapter.replayOn = !!on }
    function setReplaySeconds(s) { adapter.replaySeconds = Math.max(15, Math.min(600, Math.round(s))) }
    // VPN: the server to use, whether it carries everything or only
    // qBittorrent, the kill switch (everything only), reconnecting at login
    // to what was on when last left, and qBittorrent kept on the tunnel
    readonly property alias vpnServer: adapter.vpnServer
    readonly property alias vpnFull: adapter.vpnFull
    readonly property alias vpnKillSwitch: adapter.vpnKillSwitch
    readonly property alias vpnAtLogin: adapter.vpnAtLogin
    readonly property alias vpnWanted: adapter.vpnWanted
    readonly property alias vpnQbit: adapter.vpnQbit
    function setVpnServer(id) { adapter.vpnServer = String(id) }
    function setVpnFull(on) { adapter.vpnFull = !!on }
    function setVpnKillSwitch(on) { adapter.vpnKillSwitch = !!on }
    function setVpnAtLogin(on) { adapter.vpnAtLogin = !!on }
    function setVpnWanted(on) { adapter.vpnWanted = !!on }
    function setVpnQbit(on) { adapter.vpnQbit = !!on }
    // Phone link: the KDE Connect daemon (services/PhoneLink.qml), off until
    // asked for, as it listens on the network
    readonly property alias phoneLinkOn: adapter.phoneLinkOn
    function setPhoneLinkOn(on) { adapter.phoneLinkOn = !!on }
    // Devices: the headset's own settings (Peripherals.headsetFlags keys),
    // only the ones picked, sent to it each time it turns on
    readonly property alias headsetOptions: adapter.headsetOptions
    function setHeadsetOption(key, v) {
        var o = Object.assign({}, adapter.headsetOptions)
        o[key] = v
        adapter.headsetOptions = o
    }
    // Desktop widgets (desktop/), by key: { on, screen, size, fx, fy }.
    // fx and fy place it across the room the screen leaves it (0 the left
    // or top edge, 1 the other); below 0 it sits where it starts out.
    // screen "" is the first screen. Sticky notes keep theirs in Notes.
    // the conky-style column down the primary display's right edge
    // (desktop/DesktopSidebar.qml)
    readonly property alias deskSidebar: adapter.deskSidebar
    readonly property var deskWidgetKeys: ["clock", "weather", "music", "stats", "sysinfo"]
    readonly property var deskWidgetSizes: ["s", "m", "l"]
    function deskWidget(key) {
        var w = (adapter.desktopWidgets || {})[key] || {}
        return { on: w.on === true, screen: String(w.screen || ""),
                 size: deskWidgetSizes.indexOf(w.size) !== -1 ? w.size : "m",
                 fx: typeof w.fx === "number" ? w.fx : -1, fy: typeof w.fy === "number" ? w.fy : -1 }
    }
    function setDeskWidget(key, patch) {
        if (deskWidgetKeys.indexOf(key) === -1) return
        var all = {}, cur = adapter.desktopWidgets || {}
        for (var k in cur) all[k] = cur[k]
        var w = deskWidget(key)
        for (var f in patch) w[f] = patch[f]
        all[key] = w
        adapter.desktopWidgets = all
    }
    // back where they start out, on the first screen at the middle size
    function resetDeskWidgets() {
        var all = {}
        for (var k of deskWidgetKeys) all[k] = { on: deskWidget(k).on }
        adapter.desktopWidgets = all
    }
    // Software Update: minutes between checks (0: only when asked), the AUR,
    // and packages left out
    readonly property alias updateInterval: adapter.updateInterval
    readonly property alias updateAur: adapter.updateAur
    readonly property alias updateIgnore: adapter.updateIgnore
    function setUpdateInterval(m) { adapter.updateInterval = Math.max(0, Math.min(10080, Math.round(m))) }
    function setUpdateAur(on) { adapter.updateAur = !!on }
    function setUpdateIgnore(list) {
        var seen = {}
        adapter.updateIgnore = list.map(n => String(n).trim()).filter(n => /^[a-z0-9@._+-]+$/i.test(n) && !seen[n] && (seen[n] = true)).sort()
    }
    // Notifications: Do Not Disturb, seconds a popup stays by urgency (0
    // until dismissed), and the screen corner or edge popups stack from
    readonly property alias notifDnd: adapter.notifDnd
    readonly property alias notifTimeout: adapter.notifTimeout
    readonly property alias notifTimeoutLow: adapter.notifTimeoutLow
    readonly property alias notifTimeoutCritical: adapter.notifTimeoutCritical
    readonly property alias notifPositionX: adapter.notifPositionX
    readonly property alias notifPositionY: adapter.notifPositionY
    function setNotifDnd(on) { adapter.notifDnd = !!on }
    // Quiet hours: DND on a daily window. notifDndBySchedule marks DND as the
    // schedule's, so its end only undoes what it did.
    readonly property alias notifQuiet: adapter.notifQuiet
    readonly property alias notifQuietFrom: adapter.notifQuietFrom
    readonly property alias notifQuietTo: adapter.notifQuietTo
    readonly property alias notifDndBySchedule: adapter.notifDndBySchedule
    function setNotifQuiet(on) { adapter.notifQuiet = !!on }
    function setNotifDndBySchedule(on) { adapter.notifDndBySchedule = !!on }
    function setNotifTimeout(key, s) {
        if (["notifTimeout", "notifTimeoutLow", "notifTimeoutCritical"].indexOf(key) >= 0)
            adapter[key] = Math.max(0, Math.min(60, Math.round(s)))
    }
    // Apps whose popups are held (by app name): their notifications go
    // straight to the history, except critical ones
    readonly property alias notifSilent: adapter.notifSilent
    function setNotifSilent(app, on) {
        var l = adapter.notifSilent.filter(x => x !== app)
        if (on) l.push(app)
        adapter.notifSilent = l
    }
    function setNotifPosition(x, y) {
        if (["left", "center", "right"].indexOf(x) >= 0) adapter.notifPositionX = x
        if (["top", "bottom"].indexOf(y) >= 0) adapter.notifPositionY = y
    }

    // Media and the visualizer are one Music module now, under the
    // visualizer's key: a saved layout that still lists media drops it, and
    // the module stays shown if either of the two was.
    function foldMedia() {
        var lay = adapter.barLayout || {}
        var has = ["left", "centre", "right"].some(sec => (lay[sec] || []).indexOf("media") !== -1)
        if (!has) return
        var hidden = adapter.barHidden || []
        var shown = hidden.indexOf("media") === -1 || hidden.indexOf("visualizer") === -1
        adapter.barHidden = hidden.filter(k => k !== "media" && (k !== "visualizer" || !shown))
        var out = {}
        for (var sec in lay) out[sec] = (lay[sec] || []).filter(k => k !== "media")
        adapter.barLayout = out
    }

    // --- Bar Widgets ---------------------------------------------------
    // Order and visibility of the bar's modules, stored as what the user
    // changed and read through widgetOrder()/widgetVisible(), which merge in
    // modules added since.

    readonly property var widgetDefaults: ({
        left:   ["controlcentre", "workspaces", "windows"],
        centre: ["visualizer", "clock", "weather"],
        right:  ["bongo", "recorder", "privacy", "drives", "phone", "vpn", "failed", "updates", "claude", "notifications", "tray",
                 "cooling", "bluetooth", "network", "volume", "brightness", "battery", "desktop"],
    })

    // Every module's name and icon. A new module also needs widgetDefaults
    // and BarModules.widgetItems; Bar.qml warns when they disagree.
    readonly property var widgetMeta: ({
        controlcentre: { label: "Control Centre", icon: "󰣇" },
        workspaces:    { label: "Workspaces",     icon: "󰇘" },
        windows:       { label: "Open Windows",   icon: "󰀻" },
        clock:         { label: "Clock",          icon: "󰅐" },
        bluetooth:     { label: "Bluetooth",      icon: "󰂯" },
        network:       { label: "Network",        icon: "󰤨" },
        volume:        { label: "Volume",         icon: "󰕾" },
        brightness:    { label: "Brightness",     icon: "󰃠" },
        battery:       { label: "Battery",        icon: "󰁹" },
        tray:          { label: "System Tray",    icon: "󰀻" },
        // the Music module; the key is the old visualizer's, so saved
        // layouts keep it where it was
        visualizer:    { label: "Music",          icon: "󰝚" },
        weather:       { label: "Weather",        icon: "󰖐" },
        notifications: { label: "Notifications",  icon: "󰂚" },
        privacy:       { label: "Privacy",        icon: "󰍬" },
        recorder:      { label: "Recording",      icon: "󰑋" },
        drives:        { label: "Drives",         icon: "󰕓" },
        bongo:         { label: "Bongo Cat",      icon: "󰄛" },
        // Devices: the phone and the peripherals; the key is the old Phone
        // module's, so saved layouts keep it where it was
        phone:         { label: "Devices",        icon: "󰾰" },
        vpn:           { label: "VPN",            icon: "󰖂" },
        failed:        { label: "Failed Services", icon: "󰀦" },
        updates:       { label: "Updates",        icon: "󰚰" },
        claude:        { label: "Claude",         icon: "󰚩" },
        cooling:       { label: "Cooling",        icon: "󰈐" },
        desktop:       { label: "Show Desktop",   icon: "󰇄" },
    })

    // Can't be hidden: the control centre button is the only way back to
    // the page that would un-hide it.
    readonly property var lockedWidgets: ["controlcentre"]

    // fixed at the corners (Control Centre left, Show Desktop right), so the
    // pointer can be thrown at them
    readonly property var pinnedWidgets: ["controlcentre", "desktop"]

    // Workspaces 1..n have SUPER+n binds and are the only valid targets for a
    // window rule. Must match MAX_WORKSPACES in binds.lua.
    readonly property int workspaceCount: 5

    readonly property var widgetSections: ["left", "centre", "right"]

    // The effective layout: every known module in exactly one section. An
    // unsaved module (new since) goes beside its default neighbours.
    function widgetLayout() {
        if (!taskbarLayoutOn) return resolveLayout(adapter.barLayout)
        var own = adapter.taskbarLayout || {}
        return Object.keys(own).length > 0 ? resolveLayout(own) : taskbarOf(resolveLayout(adapter.barLayout))
    }

    // Flat's Taskbar layout: nothing in the centre. Until rearranged (into
    // taskbarLayout) it's the usual one with the centre moved right.
    readonly property bool taskbarLayoutOn: adapter.style === "flat" && Styles.has(adapter.styleOptions, "taskbar")
    function taskbarOf(l) {
        var lead = l.centre.filter(k => k !== "clock")
        var tail = l.centre.indexOf("clock") !== -1 ? ["clock"] : []
        var right = l.right.filter(k => k !== "desktop")
        return { left: l.left.slice(), centre: [], right: lead.concat(right, tail, ["desktop"]) }
    }

    function resolveLayout(saved) {
        saved = saved || {}
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
            if (di === defs.length - 1) at = row.length
            for (var a = di + 1; a < defs.length && at < 0; a++)
                if (placed[defs[a]] && row.indexOf(defs[a]) !== -1) at = row.indexOf(defs[a])
            for (var b = di - 1; b >= 0 && at < 0; b--)
                if (placed[defs[b]] && row.indexOf(defs[b]) !== -1) at = row.indexOf(defs[b]) + 1
            if (at < 0) row.push(key2)
            else row.splice(at, 0, key2)
            placed[key2] = true
        }
        out.left = out.left.filter(k => k !== "controlcentre")
        out.centre = out.centre.filter(k => k !== "controlcentre")
        out.right = out.right.filter(k => k !== "controlcentre" && k !== "desktop")
        out.left = out.left.filter(k => k !== "desktop")
        out.centre = out.centre.filter(k => k !== "desktop")
        out.left.unshift("controlcentre")
        out.right.push("desktop")
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

    // The whole layout at once, as a fresh object (the adapter writes only on
    // reassignment); the taskbar's own under the Taskbar layout.
    function setWidgetLayout(layout) {
        var l = {
            left:   (layout.left   || []).slice(),
            centre: (layout.centre || []).slice(),
            right:  (layout.right  || []).slice(),
        }
        if (taskbarLayoutOn) adapter.taskbarLayout = l
        else adapter.barLayout = l
    }

    // the centre module pinned to the bar's middle; the others stack outward
    // from it. "" centres the whole group.
    readonly property alias centreAnchor: adapter.centreAnchor
    function setCentreAnchor(key) { adapter.centreAnchor = key }

    function resetWidgets() {
        adapter.barLayout = {}
        adapter.taskbarLayout = {}
        adapter.barHidden = []
        adapter.centreAnchor = "clock"
    }

    // reads both properties every time, with no early return, so the binding
    // re-runs when either changes
    readonly property bool widgetsDefault: {
        var noneHidden = (adapter.barHidden || []).length === 0
            && adapter.centreAnchor === "clock"
        var stock = resolveLayout({})
        if (taskbarLayoutOn) stock = taskbarOf(stock)
        var ordersMatch = JSON.stringify(widgetLayout()) === JSON.stringify(stock)
        return noneHidden && ordersMatch
    }

    // the bounds set() clamps to, hand edits included
    readonly property var limits: ({
        radius:    { min: 0,  max: 14 },
        spacing:   { min: 50, max: 160 },
        rowScale:  { min: 80, max: 130 },
        barHeight: { min: 22, max: 52 },
        barIconSize: { min: 10, max: 28 },
        windowIconSize: { min: 12, max: 28 },
        windowIconPadding: { min: 2, max: 16 },
        modulePad: { min: 0, max: 16 },
        vizBars:   { min: 6, max: 24 },
        flyoutWidth: { min: 80, max: 150 },
        windowRadius: { min: 0, max: 30 },
        launcherRows: { min: 3, max: 16 },
        notifWidth: { min: 280, max: 560 },
        edgeGap:   { min: 0,  max: 30 },
        focusedOpacity:   { min: 50, max: 100 },
        unfocusedOpacity: { min: 50, max: 100 },
        terminalOpacity:  { min: 30, max: 100 },
        seeThrough: { min: 50, max: 100 },
        fontSize:  { min: 12, max: 22 },
        scrim:        { min: 0,  max: 80 },
        nightLightKelvin: { min: 2500, max: 6000 },
        cursorSize:   { min: 16, max: 48 },
        wallpaperInterval: { min: 0, max: 1440 },
        animTime:     { min: 0,  max: 100 },
        animWindows:  { min: 25, max: 200 },
        animWorkspaces: { min: 25, max: 200 },
        animShell:    { min: 25, max: 200 },
    })

    // The named points on the Animations slider, as animTime values.
    readonly property var animTimeMarks: [
        { at: 0, label: "Off" }, { at: 50, label: "Fast" }, { at: 100, label: "Normal" },
    ]

    // Appearance is two halves: the look's colours (Looks.colourKeys) and
    // everything else, which is the style's. Each style has a default: its
    // stock (Styles.stockOf) with what Save as default stored for it laid
    // over. Picking a style lands on its default; picking a look changes
    // only the colours.

    // the keys a style's default holds
    readonly property var styleKeys: Object.keys(Styles.stockOf(Styles.order[0])).filter(k => k !== "style")

    // This machine's own stock, laid over every style's before its saved
    // default: style-defaults.json in the state folder, never the repo, as
    // { "all": { key: value }, "<style>": { key: value } }
    FileView {
        id: machineView
        path: root.stateDir + "/style-defaults.json"
        preload: true
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property var machineStock: {
        try { return JSON.parse(machineView.text()) || {} } catch (e) { return {} }
    }

    // a style's default: its stock, this machine's, then its saved one
    // (style keys only, so an older snapshot's colours are left out)
    function styleDefaultOf(st) {
        var d = Styles.stockOf(st)
        var layers = [machineStock.all || {}, machineStock[st] || {}, (adapter.userDefaults || {})[st] || {}]
        for (var i = 0; i < layers.length; i++)
            for (var k in d)
                if (k !== "style" && layers[i][k] !== undefined) d[k] = layers[i][k]
        return d
    }

    // the current style's saved default, {} when it has none
    readonly property var styleDefault: (adapter.userDefaults || {})[adapter.style] || {}
    readonly property bool hasUserDefault: Object.keys(styleDefault).length > 0

    // What Reset returns to and changes are counted from: the current
    // style's default with the current look's colours as designed.
    readonly property var defaults: {
        var d = styleDefaultOf(adapter.style)
        var l = Looks.looks[adapter.look] || Looks.looks[Looks.fallback]
        for (var k in l.settings) d[k] = l.settings[k]
        d.look = Looks.looks[adapter.look] ? adapter.look : Looks.fallback
        return d
    }

    // whether a key is the look's (a colour) rather than the style's
    function isColourKey(k) { return Looks.colourKeys.indexOf(k) !== -1 }

    // The keys whose value differs from `defaults`, for the Appearance
    // page's list of changes and its fields' markers. See-through is
    // wallpaper mode's own there (seeThroughDefaults). filter(), not
    // every(): a binding only re-runs for what it read last time.
    readonly property var diffs: Object.keys(defaults).filter(k =>
        !(k === "seeThrough" && adapter.colourMode === "wallpaper") && adapter[k] !== defaults[k])
    readonly property bool isDefault: diffs.length === 0
    // whether Save as default would change anything: a style key differs
    readonly property bool styleChanged: diffs.some(k => !isColourKey(k))

    // the current style's settings become its default
    function saveAsDefault() {
        var snap = {}
        for (var i = 0; i < styleKeys.length; i++) snap[styleKeys[i]] = adapter[styleKeys[i]]
        var all = {}, u = adapter.userDefaults || {}
        for (var st in u) all[st] = u[st]
        all[adapter.style] = snap
        adapter.userDefaults = all
    }

    // Forget the current style's saved default and go back to its stock.
    function factoryReset() {
        var all = {}, u = adapter.userDefaults || {}
        for (var st in u) if (st !== adapter.style) all[st] = u[st]
        adapter.userDefaults = all
        reset()
    }

    // values into the adapter; See-through stays wallpaper mode's own
    function applyValues(o) {
        for (var k in o) {
            if (k === "seeThrough" && adapter.colourMode === "wallpaper") continue
            adapter[k] = o[k]
        }
    }

    // The look's colours, leaving the style and everything it holds.
    function applyLook(name) {
        var l = Looks.looks[name]
        if (!l) return
        root.applyLayout(adapter.look, name)
        adapter.look = name
        applyValues(l.settings)
    }

    // a look's own module layout replaces Bar Widgets', which is set aside
    // and put back on leaving
    function applyLayout(from, to) {
        var a = Looks.looks[from], b = Looks.looks[to]
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
        adapter.barLayout = { left: (lay.left || []).slice(), centre: (lay.centre || []).slice(),
                              right: (lay.right || []).slice() }
        adapter.barHidden = (lay.hidden || []).slice()
        adapter.centreAnchor = lay.anchor !== undefined ? lay.anchor : "clock"
    }

    // one setting back to its default
    function resetKey(k) {
        if (defaults[k] !== undefined) set(k, defaults[k])
    }

    function clamp(key, v) {
        var l = limits[key]
        return Math.max(l.min, Math.min(l.max, Math.round(v)))
    }

    // the colours that take a hex or "" (the look's own)
    readonly property var hexKeys: ["windowBorderFocusedHex", "windowBorderUnfocusedHex", "paletteBase", "paletteBar", "palettePanel", "paletteSurface", "paletteOverlay", "paletteBorder", "paletteMuted", "paletteSubtext", "paletteText", "paletteBright", "colourGood", "colourAlert"]

    // Single entry point for the menu, so clamping can't be forgotten at a
    // call site and every write goes through one place.
    function set(key, v) {
        if (key === "barPosition") adapter.barPosition = (v === "bottom") ? "bottom" : "top"
        else if (key === "colourMode") setColourMode(v)
        else if (key === "look") applyLook(v)
        else if (key === "accent" || hexKeys.indexOf(key) !== -1) adapter[key] = /^#[0-9a-fA-F]{6}$/.test(v) ? v : ""
        else if (key === "style") setStyle(v)
        else if (key === "density") setDensity(v)
        else if (key === "headingMark") adapter.headingMark = headingShapes.indexOf(v) !== -1 ? v : String(v).trim().slice(0, 4)
        else if (key === "barStyle") setBarStyle(v)
        else if (key === "plain") setPlain(!!v)
        else if (typeof adapter[key] === "boolean") adapter[key] = !!v
        else if (choices[key]) { if (choices[key].indexOf(v) !== -1) adapter[key] = v }
        // free text, such as the workspace names
        else if (typeof adapter[key] === "string") adapter[key] = String(v)
        else adapter[key] = clamp(key, v)
    }

    // A style arrives as its default, keeping the look's colours.
    function setStyle(v) {
        if (Styles.order.indexOf(v) === -1) return
        applyValues(styleDefaultOf(v))
    }

    // one of the current style's own options (Styles.js), on or off
    function setStyleOption(id, on) {
        var l = adapter.styleOptions.split(",").filter(x => x !== "" && x !== id)
        if (on) l.push(id)
        adapter.styleOptions = l.sort().join(",")
    }

    // Plain starts from a classic text bar's other pieces (line separators,
    // numbered workspaces); each can be changed after
    function setPlain(on) {
        if (on && !adapter.plain) {
            adapter.barSeparator = "line"
            adapter.workspaceStyle = "numbers"
        }
        adapter.plain = on
    }

    // Plain was a bar shape, then Solid's option: either becomes the Plain
    // switch, in the settings and the saved defaults
    function foldPlain() {
        var opts = adapter.styleOptions.split(",")
        if (adapter.barStyle === "plain" || opts.indexOf("plain") !== -1) {
            if (adapter.barStyle === "plain") adapter.barStyle = "full"
            adapter.styleOptions = opts.filter(x => x !== "" && x !== "plain").join(",")
            adapter.plain = true
        }
        var u = adapter.userDefaults || {}, all = {}, moved = false
        for (var st in u) {
            var d = Object.assign({}, u[st])
            var o = (d.styleOptions || "").split(",")
            if (d.barStyle === "plain" || o.indexOf("plain") !== -1) {
                if (d.barStyle === "plain") d.barStyle = "full"
                d.styleOptions = o.filter(x => x !== "" && x !== "plain").join(",")
                d.plain = true
                moved = true
            }
            all[st] = d
        }
        if (moved) adapter.userDefaults = all
    }

    // A bar shape arrives with its edge gap: the default's when it's the
    // default's shape, the shape's usual one otherwise.
    function setBarStyle(v) {
        if (choices.barStyle.indexOf(v) === -1) return
        adapter.barStyle = v
        adapter.edgeGap = defaults.barStyle === v ? defaults.edgeGap : Styles.edgeGaps[v]
    }

    // See-through's default per palette: lower on the wallpaper palette, so
    // it shows through. Switching palette moves to the new one's value.
    readonly property var seeThroughDefaults: ({
        grayscale: defaults.seeThrough,
        wallpaper: 85,
    })

    function setColourMode(v) {
        if (choices.colourMode.indexOf(v) === -1 || v === adapter.colourMode) return
        adapter.seeThrough = seeThroughDefaults[v]
        adapter.colourMode = v
    }

    function step(key, delta) { set(key, adapter[key] + delta) }

    // the style's default and the look's colours, every change undone
    function reset() {
        root.applyLayout(adapter.look, defaults.look)
        applyValues(defaults)
    }


    // Writes wait for the first read: the adapter's declared defaults would
    // otherwise be saved over the file at startup.
    property bool ready: false

    // writes are coalesced: a burst (reset) becomes one write, which also
    // keeps watchChanges from reloading a half-written state
    Timer {
        id: saveTimer
        interval: 150
        onTriggered: view.writeAdapter()
    }

    FileView {
        id: view
        path: root.stateDir + "/appearance.json"
        // preload: a FileView only loads when text() is read, which nothing does
        preload: true
        // blocking, so Theme binds to the saved values from the first frame
        blockLoading: true
        watchChanges: true
        // Expected on a fresh install: there is no file until the first
        // edit, and the defaults on the adapter are the right answer.
        printErrors: false

        // open the gate once the first read resolves, loaded or no file yet;
        // a look that's since been renamed or removed falls back
        onLoaded: {
            root.ready = true
            if (!Looks.looks[adapter.look]) adapter.look = Looks.fallback
            root.foldMedia()
            root.foldPlain()
        }
        onLoadFailed: root.ready = true

        onFileChanged: reload()
        onAdapterUpdated: if (root.ready) saveTimer.restart()

        JsonAdapter {
            id: adapter
            property string barPosition: "top"
            property int radius: 6
            property int fontSize: 16

            property int animTime: 100
            property int animWindows: 100
            property int animWorkspaces: 100
            property int animShell: 100
            property string colourMode: "grayscale"
            property string colourScheme: "scheme-tonal-spot"
            property string colourVariant: "dark"
            property string look: "singularity"
            property string style: "channel"
            property string styleOptions: ""
            property int seeThrough: 100
            property bool shadows: true
            property bool heavyLines: false
            property bool plain: false
            property string levelColour: "accent"
            property int spacing: 100
            property int rowScale: 100
            property int barHeight: 32
            property int barIconSize: 17
            property int modulePad: 6
            property string windowBorderWidth: "style"
            property string windowBorderFocused: "accent"
            property string windowBorderFocusedHex: ""
            property string windowBorderUnfocused: "border"
            property string windowBorderUnfocusedHex: ""
            property string windowRounding: "shell"
            property int windowRadius: 6
            property string windowShadow: "style"
            property string tabBar: "shell"
            property int flyoutWidth: 100
            property int launcherRows: 8
            property int notifWidth: 380
            property string fontFamily: "UbuntuMono Nerd Font"
            property string systemFontFamily: "Ubuntu Nerd Font"
            property string cursorTheme: "Bibata-Modern-Classic"
            property int cursorSize: 20
            property string iconTheme: "kora"
            property string windowAnim: "popin"
            property string barStyle: "full"
            property int edgeGap: 0
            property int focusedOpacity: 100
            property int unfocusedOpacity: 100
            property int terminalOpacity: 90
            property string terminalApp: "alacritty"
            property string workspaceStyle: "pills"
            property string controlIcon: "arch"
            property string clockStyle: "stamp"
            property string windowStyle: "icons"
            property string windowScope: "workspace"
            property int windowIconSize: 18
            property int windowIconPadding: 3
            property string iconTint: "colour"
            property string vizStyle: "mirror"
            property int vizBars: 10
            property bool vizShown: true
            property bool musicTitle: false
            property bool vizHideSilent: false
            property bool gradient: false
            property string levelStyle: "pill"
            property string powerStyle: "row"
            property string overviewBackdrop: "dim"
            property string overviewLayout: "grid"
            property string altTabStyle: "icons"
            property string altTabScope: "workspace"
            property bool lockNotifs: false
            property bool lockMedia: false
            property bool lockDate: false
            property string lockClockPlace: "centre"
            property string lockClockSize: "large"
            property string clockFormat: "ddd HH:mm"
            property bool trayDrawer: false
            property var trayPinned: []
            property var channelEq: ({})
            property var trayHidden: []
            property var trayOrder: []
            property string workspaceNames: ""
            property string barSeparator: "none"
            property string barChips: "auto"
            property bool notifGroup: false
            property string notifStyle: "full"
            property bool launcherDetails: true
            property string launcherPosition: "centre"
            property string launcherLayout: "list"
            property string flyoutAnim: "auto"
            property string accent: "#5555c8"
            property string paletteBase: ""
            property string paletteBar: ""
            property string palettePanel: ""
            property string paletteSurface: ""
            property string paletteOverlay: ""
            property string paletteBorder: ""
            property string paletteMuted: ""
            property string paletteSubtext: ""
            property string paletteText: ""
            property string paletteBright: ""
            property string colourGood: ""
            property string colourAlert: ""
            property string accentText: "auto"
            property int scrim: 40
            property bool headingUpper: true
            property bool headingRule: true
            property string headingMark: "//"
            property string headingMarkColour: "accent"
            property string headingSize: "smaller"

            property bool wallpaperShuffle: true
            property int wallpaperInterval: 0
            property string wallpaperFill: "fill"
            property bool clockIsland: true
            property int nightLightKelvin: 4000
            property string nightLightSchedule: "off"
            property int nightLightFrom: 1200
            property int nightLightTo: 420
            property string weatherUnits: "F"
            property bool clock24: true
            property int weekStart: 1
            property int updateInterval: 30
            property bool replayOn: true
            property int replaySeconds: 60
            property string recordCodec: "av1"
            property string vpnServer: ""
            property bool vpnFull: false
            property bool vpnKillSwitch: false
            property bool vpnAtLogin: true
            property bool vpnWanted: false
            property bool vpnQbit: true
            property bool phoneLinkOn: false
            property var headsetOptions: ({})
            property var desktopWidgets: ({})
            property bool deskSidebar: false
            property bool updateAur: true
            property var updateIgnore: []
            property bool notifDnd: false
            property bool notifQuiet: false
            property int notifQuietFrom: 1320
            property int notifQuietTo: 420
            property bool notifDndBySchedule: false
            property var notifSilent: []
            property int notifTimeout: 8
            property int notifTimeoutLow: 4
            property int notifTimeoutCritical: 16
            property string notifPositionX: "right"
            property string notifPositionY: "top"
            property string centreAnchor: "clock"
            property var barLayout: ({})
            // Flat's Taskbar layout, once rearranged (widgetLayout)
            property var taskbarLayout: ({})
            property var barHidden: []
            // Bar Widgets' arrangement, held while a look with its own
            // layout is on (applyLayout)
            property var ownLayout: ({})
            // each style's appearance saved with "Save as default", by
            // style name; a style missing means its stock
            property var userDefaults: ({})

        }
    }
}
