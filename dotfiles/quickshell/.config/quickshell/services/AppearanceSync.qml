// Singularity - Quickshell
// ~/.config/quickshell/services/AppearanceSync.qml
//
// Carries the Appearance page's settings out to the apps that draw the same
// chrome as the bar -- corner radius, the palette (the look's or the
// wallpaper's), font, font size and frame style -- so the fallback launcher
// and the other apps change with it.
//
// Everything lands in ~/.local/state/singularity/, never in ~/.config: those
// directories are stow links into the repo, and generated files there would
// show up as changes to commit.
//
//   wofi.css    -- wofi's own stylesheet, rewritten. wofi parses CSS from a
//                  string, so it can't @import anything; hyprland.lua
//                  launches it with --style pointed here. Every hex from the
//                  reference look's ramp (Looks.reference -- the one the
//                  template is written in) becomes the current colour for
//                  that role, the font family becomes the current one, and
//                  values tagged `@radius` / `@font` are recomputed.
//   alacritty.toml -- the terminal's colours, imported by alacritty.toml.
//                  alacritty watches imports, so open windows follow along.
//   nvim.lua    -- the editor's palette, read by nvim's colors/singularity.lua.
//                  nvim watches it and recolours open sessions.
//   ~/.claude/themes/singularity.json -- a Claude Code theme; Claude Code
//                  only reads themes from there, and watches it.
//   hyprlock.conf -- hyprlang variables (colours, font, radius, stroke) that
//                  hypr/hyprlock.conf sources. hyprlock reads it at each lock.
//   gtk3.css, gtk4.css -- the look's ramp, accent and status hues as
//                  libadwaita's named colours (renderGtkCss), @imported by
//                  gtk-3.0/gtk.css and gtk-4.0/gtk.css. GTK reads them at
//                  each app's launch.
//   qt6ct-colors.conf -- the same colours as a full QPalette (renderQtScheme);
//                  qt6ct.conf points at it.
//   term-colors.sh -- the ramp, accent, text on the accent and heading colour
//                  as "r;g;b" triples in shell variables, and the capsule
//                  shape (T_ROUND) and heading case (T_UPPER), sourced by
//                  starship-path.sh and fastfetch's row.sh.
//   starship.toml, fastfetch.jsonc -- the repo's own configs, recoloured
//                  (recolour). .bashrc points starship (STARSHIP_CONFIG) and
//                  fastfetch (-c) at them when they exist.
//   zathura     -- zathura's colours, included by zathurarc.
//
// Zen's and Floorp's active profiles get dark or light and the accent as
// Gecko's selection and accent colours, in a marked block of their user.js
// (browserPrefs), and Floorp its chrome in the look's colours in one of
// chrome/userChrome.css (browserChrome). Floorp's two files are rebuilt from
// the repo's floorp/singularity/ copies each time; the rest of Zen's is left
// alone. Read at each browser start.
//
// GTK and Qt apps get dark or light, the icon and cursor themes, and the
// system font -- this is the only place any of those are set. Not the
// shell's own font (Settings.fontFamily/Theme.fontText), which is for the
// shell's chrome alone (wofi and the bar): GTK/Qt use systemFontFamily
// and systemFontSize below.
//   gsettings   -- gtk-theme/color-scheme, the icon and cursor themes, and the
//                  system font, written live to dconf (no file, so
//                  nothing to watch -- GTK apps read dconf directly, and
//                  xdg-desktop-portal-gtk forwards color-scheme to portal-aware
//                  Qt/GTK4 apps). GTK3's theme is adw-gtk3, libadwaita's look
//                  ported to GTK3 with its colours left as named ones, so GTK3
//                  and GTK4 apps draw the same widgets in the same colours.
//   qt6ct.conf  -- Qt apps (QT_QPA_PLATFORMTHEME=qt6ct, hyprland.lua) have no
//                  live dconf-style path, so this is a real file, read at each
//                  Qt app's next launch: Fusion, the palette above, the icon
//                  theme and the system font.
//   ~/.local/share/icons/default/index.theme -- the XCursor fallback,
//                  inheriting the cursor theme (writeCursor).

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks

Scope {
    id: root

    readonly property string dir: Settings.stateDir

    readonly property var roleNames: ["base", "bar", "panel", "surface", "overlay",
                                      "border", "muted", "subtext", "text", "bright"]

    function hex(c) { return String(c).substring(0, 7) }
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", "
            + Math.round(c.b * 255) + ", " + a + ")"
    }
    // Replace the value just before a `/* @tag */` comment, keeping the tag
    // so the next render finds it again.
    function tagged(src, tag, valuePattern, value) {
        var re = new RegExp("(" + valuePattern + ")(\\s*)\\/\\*\\s*@" + tag + "\\s*\\*\\/", "g")
        return src.replace(re, (m, v, sp) => value + sp + "/* @" + tag + " */")
    }
    function px(offset) { return Math.max(0, Theme.panelRadius - offset) + "px" }
    function triple(c) {
        return Math.round(c.r * 255) + ";" + Math.round(c.g * 255) + ";" + Math.round(c.b * 255)
    }

    // A config written in the reference look's colours (Looks.reference),
    // in the current one: each ramp, accent or alert hex, and each ANSI
    // truecolour triple (38;2;r;g;b or 48;2;r;g;b), becomes the current
    // colour for its role.
    function recolour(text) {
        var look = Looks.looks[Looks.reference], ref = look.palette
        var roles = roleNames.map(r => [ref[r], Theme[r]]).concat([[look.accent, Theme.accent], [look.alert, Theme.alert]])
        var byHex = {}, byTriple = {}
        for (var i = roles.length - 1; i >= 0; i--) {
            var h = roles[i][0], c = roles[i][1]
            byHex[h] = c
            byTriple[[1, 3, 5].map(k => parseInt(h.substr(k, 2), 16)).join(";")] = c
        }
        return text
            .replace(/#[0-9a-fA-F]{6}\b/g, m => byHex[m.toLowerCase()] ? hex(byHex[m.toLowerCase()]) : m)
            .replace(/\b([34]8;2;)(\d+;\d+;\d+)/g, (m, p, t) => byTriple[t] ? p + triple(byTriple[t]) : m)
    }

    function renderWofi() {
        var tpl = wofiTemplate.text()
        if (!tpl) return
        var out = tpl.replace(/\d+px(\s*)\/\*\s*@radius(?:-(\d+))?\s*\*\//g,
            (m, sp, off) => px(parseInt(off || "0")) + sp + "/* @radius" + (off ? "-" + off : "") + " */")
        out = out.replace(/(\d+)px(\s*)\/\*\s*@font\s*\*\//g,
            (m, n, sp) => Theme.fs(parseInt(n)) + "px" + sp + "/* @font */")
        out = recolour(out).replace(/font-family:\s*"[^"]*"/g, 'font-family: "' + Theme.fontText + '"')
        out = tagged(out, "frame", "#[0-9a-fA-F]{6}",
            Theme.frameDouble ? hex(Theme.frameStroke) : hex(Theme.panel))
        out = tagged(out, "accent", "#[0-9a-fA-F]{6}", hex(Theme.accent))
        out = tagged(out, "focus", "#[0-9a-fA-F]{6}", hex(Theme.strokeFocus))
        out = tagged(out, "hover", "#[0-9a-fA-F]{6}", hex(Theme.hoverFill))
        out = tagged(out, "panel-bg", "#[0-9a-fA-F]{6}|rgba\\([^)]*\\)", rgba(Theme.panel, Theme.panelOpacity))
        out = tagged(out, "bw", "\\d+px", Theme.borderWidth + "px")
        wofiOut.setText(out)
    }

    // a + (b - a) * t per channel, as a colour; mix() as a hex
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }
    function mix(a, b, t) { return hex(mixColor(a, b, t)) }

    // The ANSI slots as a lightness ramp in the look's tones, the way the
    // repo's grayscale terminal always was: normal climbs muted -> text,
    // bright climbs subtext -> bright, each ending on its role exactly.
    function renderAlacritty() {
        var ansi = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
        var q = s => '"' + s + '"'
        var lines = ["# Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten.",
            "", "[colors.primary]",
            "background = " + q(hex(Theme.base)),
            "foreground = " + q(hex(Theme.text)),
            "dim_foreground = " + q(hex(Theme.subtext)),
            "bright_foreground = " + q(hex(Theme.bright)),
            "", "[colors.cursor]",
            "cursor = " + q(hex(Theme.bright)),
            "text = " + q(hex(Theme.base)),
            "", "[colors.selection]",
            "background = " + q(hex(Theme.accent)),
            "text = " + q(hex(onAccent())),
            "", "[colors.normal]",
            "black = " + q(hex(Theme.surface))]
        for (var i = 1; i < 7; i++)
            lines.push(ansi[i] + " = " + q(mix(Theme.muted, Theme.text, i / 7)))
        lines.push("white = " + q(hex(Theme.text)), "", "[colors.bright]",
            "black = " + q(hex(Theme.border)))
        for (i = 1; i < 7; i++)
            lines.push(ansi[i] + " = " + q(mix(Theme.subtext, Theme.bright, i / 7)))
        lines.push("white = " + q(hex(Theme.bright)))
        // one atomic rename, so alacritty's watcher never reads half a file
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/alacritty.toml", transform: () => text })
    }

    // nvim's palette as a Lua table: the ten roles plus the look's accent and
    // status hues. colors/singularity.lua builds every highlight from it, and
    // nvim watches the file, so open editors recolour like the terminal.
    function renderNvim() {
        var q = c => '"' + hex(c) + '"'
        var lines = ["-- Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten.",
            "return {"]
        for (var i = 0; i < roleNames.length; i++)
            lines.push("  " + roleNames[i] + " = " + q(Theme[roleNames[i]]) + ",")
        lines.push("  accent = " + q(Theme.accent) + ",",
            "  good = " + q(Theme.good) + ",",
            "  alert = " + q(Theme.alert) + ",",
            "}")
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/nvim.lua", transform: () => text })
    }

    // A Claude Code theme over its own dark or light base: the look's ramp
    // for text and chrome, the accent wherever Claude marks something (its
    // name, prompts, spinners, meters), good and alert for success and
    // error. Diff and subagent colours stay Claude's, since those hues carry
    // meaning. Claude Code watches the directory, so open sessions recolour.
    function renderClaude() {
        var rgb = c => "rgb(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + ")"
        var a = rgb(Theme.accent)
        var shimmer = rgb(mixColor(Theme.accent, Theme.bright, 0.4))
        var o = {
            text: rgb(Theme.text), inverseText: rgb(Theme.base),
            inactive: rgb(Theme.subtext), inactiveShimmer: rgb(Theme.text),
            subtle: rgb(Theme.border),
            promptBorder: rgb(Theme.muted), promptBorderShimmer: rgb(Theme.subtext),
            bashBorder: rgb(Theme.bright),
            planMode: rgb(Theme.subtext), ide: rgb(Theme.subtext),
            success: rgb(Theme.good), error: rgb(Theme.alert),
            userMessageBackground: rgb(Theme.surface),
            userMessageBackgroundHover: rgb(Theme.overlay),
            composerSidebarBackground: rgb(Theme.surface),
            bashMessageBackgroundColor: rgb(Theme.overlay),
            memoryBackgroundColor: rgb(Theme.overlay),
            selectionBg: a, rate_limit_empty: rgb(Theme.border),
            clawd_background: rgb(Theme.base),
        }
        var accented = ["claude", "clawd_body", "briefLabelClaude", "briefLabelYou",
            "permission", "suggestion", "remember", "autoAccept", "skill", "merged",
            "effortUltra", "rate_limit_fill", "claudeBlue_FOR_SYSTEM_SPINNER"]
        for (var i = 0; i < accented.length; i++) o[accented[i]] = a
        var shimmers = ["claudeShimmer", "permissionShimmer", "autoAcceptShimmer",
            "claudeBlueShimmer_FOR_SYSTEM_SPINNER"]
        for (i = 0; i < shimmers.length; i++) o[shimmers[i]] = shimmer
        var text = JSON.stringify({ name: "Singularity", base: Theme.isLight ? "light" : "dark",
            overrides: o }, null, 2) + "\n"
        AtomicFileWrite.write({
            path: Quickshell.env("HOME") + "/.claude/themes/singularity.json",
            transform: () => text,
        })
    }

    // For shell scripts that draw in the look: one N_<ROLE>='r;g;b' per role,
    // plus N_ACCENT, to drop into an SGR sequence after 38;2; or 48;2;.
    function renderTermColors() {
        var lines = ["# Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten."]
        for (var i = 0; i < roleNames.length; i++)
            lines.push("N_" + roleNames[i].toUpperCase() + "='" + triple(Theme[roleNames[i]]) + "'")
        lines.push("N_ACCENT='" + triple(Theme.accent) + "'")
        lines.push("N_ON_ACCENT='" + triple(onAccent()) + "'")
        lines.push("N_HEADING='" + triple(Theme.headingColor) + "'")
        lines.push("T_ROUND=" + (Theme.radius > 0 ? 1 : 0))
        lines.push("T_UPPER=" + (Theme.headingUpper ? 1 : 0))
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/term-colors.sh", transform: () => text })
    }

    // zathura's chrome on the ramp, and search highlights in the accent.
    function renderZathura() {
        var q = c => '"' + hex(c) + '"'
        var set = (k, v) => "set " + k + " " + v
        var lines = ["# Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten.",
            set("recolor-darkcolor", q(Theme.text)), set("recolor-lightcolor", q(Theme.base)),
            set("default-bg", q(Theme.base)), set("default-fg", q(Theme.text)),
            set("statusbar-bg", q(Theme.bar)), set("statusbar-fg", q(Theme.subtext)),
            set("inputbar-bg", q(Theme.bar)), set("inputbar-fg", q(Theme.bright)),
            set("notification-bg", q(Theme.bar)), set("notification-fg", q(Theme.text)),
            set("notification-error-bg", q(Theme.bar)), set("notification-error-fg", q(Theme.alert)),
            set("completion-bg", q(Theme.surface)), set("completion-fg", q(Theme.text)),
            set("completion-highlight-bg", q(Theme.accent)), set("completion-highlight-fg", q(onAccent())),
            set("highlight-color", '"' + rgba(Theme.accent, 0.3) + '"'),
            set("highlight-active-color", '"' + rgba(Theme.accent, 0.5) + '"')]
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/zathura", transform: () => text })
    }

    // hyprlock's colours as rgba(rrggbbaa), which is the only form hyprlang
    // takes for a colour; the rest is the look's font, corners and strokes.
    function renderHyprlock() {
        var c = (col, a) => "rgba(" + hex(col).slice(1) + (a || "ff") + ")"
        var lines = ["# Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten.",
            "$n_base = " + c(Theme.base),
            "$n_surface = " + c(Theme.surface),
            "$n_border = " + c(Theme.border),
            "$n_subtext = " + c(Theme.subtext),
            "$n_text = " + c(Theme.text),
            "$n_bright = " + c(Theme.bright),
            "$n_focus = " + c(Theme.strokeFocus),
            "$n_accent = " + c(Theme.accent),
            "$n_alert = " + c(Theme.alert),
            "$n_font = " + Theme.fontText,
            "$n_radius = " + Theme.radius,
            "$n_bw = " + Theme.borderWidth,
            "$n_fs = " + Theme.fs(16),
            "$n_fs_clock = " + clockSize]
        // the clock and the info line under it, placed as Lock Screen says
        var place = Settings.lockClockPlace
        if (place === "top")
            lines.push("$n_clock_pos = 0, -60", "$n_clock_halign = center", "$n_clock_valign = top",
                "$n_info_pos = 0, " + -Math.round(60 + clockSize * 1.5), "$n_info_halign = center", "$n_info_valign = top")
        else if (place === "corner")
            lines.push("$n_clock_pos = 60, " + Math.round(60 + Theme.fs(16) * 2), "$n_clock_halign = left", "$n_clock_valign = bottom",
                "$n_info_pos = 62, 60", "$n_info_halign = left", "$n_info_valign = bottom")
        else
            lines.push("$n_clock_pos = 0, " + Math.round(50 + clockSize * 0.6), "$n_clock_halign = center", "$n_clock_valign = center",
                "$n_info_pos = 0, 34",
                "$n_info_halign = center", "$n_info_valign = center")
        lines.push("$n_info_args = " + (Settings.lockDate ? "date" : "none"))
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/hyprlock.conf", transform: () => text })
    }

    readonly property int clockSize: Theme.fs(Settings.lockClockSize === "small" ? 40
        : Settings.lockClockSize === "huge" ? 110 : 64)

    // What the lock screen's info line shows besides the date: the track
    // playing and the unread count, kept in a file lock-info.sh reads, since
    // hyprlock can't ask the shell. Empty when both are off.
    readonly property string lockInfo: {
        var out = []
        var p = Media.player
        if (Settings.lockMedia && p && p.isPlaying)
            out.push("󰝚  " + (p.trackArtist ? p.trackArtist + " – " : "") + (p.trackTitle || p.identity))
        if (Settings.lockNotifs && Notifications.unread > 0)
            out.push("󰂚  " + Notifications.unread + " unread")
        return out.join("\n")
    }
    onLockInfoChanged: lockInfoWrite.restart()
    Timer {
        id: lockInfoWrite
        interval: 500
        onTriggered: AtomicFileWrite.write({ path: root.dir + "/lock-info", transform: () => root.lockInfo + "\n" })
    }

    Connections {
        target: Settings
        function onLockClockSizeChanged() { debounce.restart() }
        function onLockClockPlaceChanged() { debounce.restart() }
        function onLockDateChanged() { debounce.restart() }
    }

    // The accent, and whichever of base or bright reads better on it -- the
    // text colour for anything drawn on an accent fill (a text selection).
    function luminance(c) {
        var lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }
    function contrast(a, b) {
        var la = luminance(a), lb = luminance(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }
    function onAccent() { return onColor(Theme.accent) }

    // Whichever of base or bright reads better on a fill of c.
    function onColor(c) {
        return contrast(c, Theme.base) >= contrast(c, Theme.bright) ? Theme.base : Theme.bright
    }

    // The look in libadwaita's named colours, laid out the way the shell uses
    // its ramp: windows and dialogs on panel, views (lists, text areas) a step
    // down on bar, headerbars, sidebars, cards and tooltips a step up on
    // surface, popovers lifted clear of the window. adw-gtk3 (GTK3) reads
    // these as @define-color names and derives its older theme_* names from
    // them; libadwaita (GTK4) reads them as CSS variables.
    function gtkColours() {
        var text = hex(Theme.text), a = hex(Theme.accent), t = hex(onAccent())
        var alert = hex(Theme.alert), onAlert = hex(onColor(Theme.alert))
        var good = hex(Theme.good), onGood = hex(onColor(Theme.good))
        var shade = Theme.isLight ? "rgba(0, 0, 0, 0.07)" : "rgba(0, 0, 0, 0.36)"
        return {
            window_bg_color: hex(Theme.panel), window_fg_color: text,
            view_bg_color: hex(Theme.bar), view_fg_color: text,
            headerbar_bg_color: hex(Theme.surface), headerbar_fg_color: text,
            headerbar_border_color: hex(Theme.border),
            headerbar_backdrop_color: hex(Theme.panel),
            headerbar_shade_color: shade,
            headerbar_darker_shade_color: Theme.isLight ? "rgba(0, 0, 0, 0.12)" : "rgba(0, 0, 0, 0.9)",
            sidebar_bg_color: hex(Theme.surface), sidebar_fg_color: text,
            sidebar_backdrop_color: hex(Theme.panel), sidebar_border_color: hex(Theme.border),
            sidebar_shade_color: shade,
            secondary_sidebar_bg_color: hex(Theme.panel), secondary_sidebar_fg_color: text,
            secondary_sidebar_backdrop_color: hex(Theme.bar),
            secondary_sidebar_border_color: hex(Theme.border),
            secondary_sidebar_shade_color: shade,
            card_bg_color: hex(Theme.surface), card_fg_color: text, card_shade_color: shade,
            dialog_bg_color: hex(Theme.panel), dialog_fg_color: text,
            popover_bg_color: hex(Theme.isLight ? Theme.panel : Theme.overlay),
            popover_fg_color: text, popover_shade_color: shade,
            thumbnail_bg_color: hex(Theme.surface), thumbnail_fg_color: text,
            shade_color: shade,
            accent_bg_color: a, accent_fg_color: t, accent_color: a,
            destructive_bg_color: alert, destructive_fg_color: onAlert, destructive_color: alert,
            error_bg_color: alert, error_fg_color: onAlert, error_color: alert,
            success_bg_color: good, success_fg_color: onGood, success_color: good,
        }
    }

    function renderGtkCss() {
        var o = gtkColours()
        var header = "/* Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten. */\n"
        var named = "", vars = ":root {\n"
        for (var k in o) {
            named += "@define-color " + k + " " + o[k] + ";\n"
            vars += "  --" + k.replace(/_/g, "-") + ": " + o[k] + ";\n"
        }
        vars += "}\n"
        // Stock Adwaita, the fallback when adw-gtk3 isn't installed, has its
        // colours compiled into its rules; this at least carries the accent.
        var selection = "selection, *:selected, *:selected:focus, row:selected, treeview.view:selected,\n"
            + "entry selection, textview text selection, label selection {\n"
            + "  background-color: " + o.accent_bg_color + ";\n  color: " + o.accent_fg_color + ";\n}\n"
        // GTK4 without libadwaita still reads the named colours
        var gtk3 = header + named + selection, gtk4 = header + vars + named
        AtomicFileWrite.write({ path: root.dir + "/gtk3.css", transform: () => gtk3 })
        AtomicFileWrite.write({ path: root.dir + "/gtk4.css", transform: () => gtk4 })
    }

    // Gecko takes any of its system colours from a ui.<name> pref. Zen's
    // accent (zen.theme.accent-color) defaults to AccentColor, so it follows
    // ui.accentcolor unless it was picked by hand in Zen's own settings.
    // The chrome is dark or light with the look (toolbar-theme: 0 dark,
    // 1 light), and pages follow the chrome (content-override 2) -- unless a
    // theme extension is on, whose colours decide both instead.
    readonly property string browserMark: "singularity: begin -- generated by quickshell AppearanceSync, edits are overwritten"

    function browserPrefs() {
        var a = hex(Theme.accent), t = hex(onAccent())
        var pref = (k, v) => 'user_pref("' + k + '", ' + v + ');'
        var str = v => '"' + v + '"'
        var scheme = Theme.isLight ? "1" : "0"
        return [pref("browser.theme.toolbar-theme", scheme),
            pref("layout.css.prefers-color-scheme.content-override", "2"),
            pref("ui.highlight", str(a)), pref("ui.highlighttext", str(t)),
            pref("ui.selecteditem", str(a)), pref("ui.selecteditemtext", str(t)),
            pref("ui.accentcolor", str(a)), pref("ui.accentcolortext", str(t)),
            pref("toolkit.legacyUserProfileCustomizations.stylesheets", "true")]
    }

    // Floorp's chrome in the look: the variables a theme (browser.theme, or
    // the Firefox Color extension) would set, laid out like gtkColours -- the
    // tab strip on bar, the toolbar and selected tab a step up on surface,
    // the address bar on overlay, popups as GTK's popovers. All text is the
    // look's text, not bright. userChrome.css is
    // a user sheet, so its !important outranks a theme's inline values.
    // Floorp's lightweight theme also hard-codes cyan (the urlbar's focus
    // ring, links, primary buttons) and blue (the selected urlbar result) in
    // place of the system colours above. They're all variables on :root;
    // unlayered !important here outranks the browser's layered tokens.
    // The line over the selected tab (.tab-context-line, Floorp's Photon UI)
    // is --tab-line-color, which Lepton sets on #tabbrowser-tabs and on the
    // line itself rather than inheriting it from :root, so it's set on all three.
    // Lepton tells the selected tab by [selected="true"], but Gecko now sets
    // `selected` bare, so its rules hide the line there (and grey it on hover);
    // the last rule shows it on the tabs that are actually selected.
    // The sound badge on tabs (its rules are in the repo's userChrome.css)
    // is a disc between border and muted with a speaker halfway from subtext
    // to bright -- #3a3a3a and #b4b4b4 on singularity.
    function browserChrome() {
        var a = hex(Theme.accent), t = hex(onAccent())
        var popup = hex(Theme.isLight ? Theme.panel : Theme.overlay)
        var vars = {
            "--lwt-accent-color": hex(Theme.bar),
            "--lwt-text-color": hex(Theme.text),
            "--text-color": hex(Theme.text),
            "--toolbox-background-color": hex(Theme.bar),
            "--toolbox-background-color-inactive": hex(Theme.bar),
            "--toolbox-text-color": hex(Theme.text),
            "--toolbox-text-color-inactive": hex(Theme.subtext),
            "--toolbar-background-color": hex(Theme.surface),
            "--toolbar-text-color": hex(Theme.text),
            "--toolbarbutton-icon-fill": hex(Theme.text),
            "--toolbarbutton-background-color-hover": hex(Theme.hoverFill),
            "--toolbarbutton-background-color-active": mix(Theme.selectedFill, Theme.border, 0.5),
            "--toolbar-field-background-color": hex(Theme.overlay),
            "--toolbar-field-text-color": hex(Theme.text),
            "--toolbar-field-border-color": "transparent",
            "--toolbar-field-background-color-focus": hex(Theme.overlay),
            "--toolbar-field-text-color-focus": hex(Theme.text),
            "--toolbar-field-border-color-focus": a,
            "--lwt-toolbar-field-highlight": a,
            "--lwt-toolbar-field-highlight-text": t,
            "--tab-background-color-selected": hex(Theme.surface),
            "--tab-selected-textcolor": hex(Theme.text),
            "--tab-loading-fill": a,
            "--tabs-navbar-separator-color": "transparent",
            "--toolbarseparator-color": hex(Theme.border),
            "--chrome-content-separator-color": hex(Theme.border),
            "--panel-background-color": popup,
            "--panel-text-color": hex(Theme.text),
            "--panel-border-color": hex(Theme.border),
            "--sidebar-background-color": hex(Theme.surface),
            "--sidebar-text-color": hex(Theme.text),
            "--sidebar-border-color": hex(Theme.border),
            // behind a page that hasn't drawn yet
            "--tabpanel-background-color": hex(Theme.base),
            "--focus-outline-color": a,
            "--color-accent-primary": a,
            "--color-accent-primary-hover": a,
            "--color-accent-primary-active": a,
            "--color-accent-primary-selected": a,
            "--button-text-color-primary": t,
            "--urlbarview-background-color-selected": a,
            "--urlbarview-text-color-selected": t,
            "--sound-badge-background-color": mix(Theme.border, Theme.muted, 0.35),
            "--sound-badge-background-color-hover": mix(Theme.border, Theme.muted, 0.9),
            "--sound-badge-icon-color": mix(Theme.subtext, Theme.bright, 0.515),
        }
        var lines = [":root {"]
        for (var k in vars) lines.push("  " + k + ": " + vars[k] + " !important;")
        lines.push("}", ":root, #tabbrowser-tabs, .tab-context-line {",
            "  --tab-line-color: " + a + " !important;",
            "  --lwt-tab-line-color: " + a + " !important;",
            "}",
            // context menus: toolkit sets these on each popup from GTK's
            // Menu/MenuText, so :root alone doesn't reach them
            "menupopup, panel:not([type=\"arrow\"]) {",
            "  --panel-background-color: " + popup + " !important;",
            "  --panel-text-color: " + hex(Theme.text) + " !important;",
            "  --panel-border-color: " + hex(Theme.border) + " !important;",
            "}",
            ".tabbrowser-tab:is([selected], [multiselected]) .tab-context-line {",
            "  background-color: " + a + " !important;",
            "  opacity: 1 !important;",
            "  transform: none !important;",
            "}")
        return lines
    }

    // Swaps the marked block in text for the new one, or appends it, leaving
    // everything else in the file as it was.
    function withBlock(text, open, close, lines) {
        var esc = x => x.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        // a block from before the rename says "neutrino" where this says
        // "singularity"; either is replaced
        var re = new RegExp("\\n?" + esc(open) + "(?:neutrino|singularity)"
            + esc(browserMark.replace(/^singularity/, "")) + "[\\s\\S]*?"
            + esc(open) + "(?:neutrino|singularity)" + esc(": end" + close) + "\\n?")
        var rest = text.replace(re, "\n").replace(/\n+$/, "")
        var block = [open + browserMark + close].concat(lines, [open + "singularity: end" + close])
        return (rest ? rest + "\n" : "") + block.join("\n") + "\n"
    }

    // The profile the browser opens: installs.ini's Default, else the one
    // profiles.ini marks Default=1. "" when the browser has never run.
    function activeProfile(base, installs, profiles) {
        var path = ""
        var m = /^Default=(.+)$/m.exec(installs)
        if (m) path = m[1].trim()
        else {
            var sections = profiles.split(/^\[/m)
            for (var i = 0; i < sections.length; i++) {
                if (!/^Default=1\s*$/m.test(sections[i])) continue
                var p = /^Path=(.+)$/m.exec(sections[i])
                if (p) path = p[1].trim()
            }
        }
        if (!path) return ""
        return path.charAt(0) === "/" ? path : base + "/" + path
    }

    // The profile file with the marked block swapped in: built on the
    // repo's copy (source) when the browser has one, else on the file itself.
    function writeProfileFile(path, source, open, close, lines) {
        var base = source && source.ready ? source.text() : null
        AtomicFileWrite.write({
            path: path,
            transform: text => withBlock(base !== null ? base : text, open, close, lines),
        })
    }

    function renderBrowsers() {
        var prefs = browserPrefs(), chrome = browserChrome()
        for (var i = 0; i < browsers.length; i++) {
            var b = browsers[i]
            var profile = activeProfile(b.base, b.installs.text(), b.profiles.text())
            if (!profile) continue
            writeProfileFile(profile + "/user.js", b.userJs, "// ", "", prefs)
            if (b.chrome)
                writeProfileFile(profile + "/chrome/userChrome.css", b.chrome, "/* ", " */", chrome)
        }
    }

    // GTK/Qt apps' font size, and the fixed monospace face used for both
    // toolkits' "fixed"/monospace slot. Independent of the bar's own font
    // picker (Theme.fontText) -- only the family for general/UI text
    // (Settings.systemFontFamily, set from Settings -> Appearance) is
    // user-editable; everything else here stays put.
    readonly property int systemFontSize: 11
    readonly property string systemMonoFontFamily: "UbuntuMono Nerd Font"

    // GTK apps read font-name/document-font-name/gtk-theme/color-scheme
    // straight from dconf -- so a value written here sticks live, the same
    // way install.sh's one-time `gsettings set` did at install. Only the
    // general-text keys follow Settings.systemFontFamily; monospace-font-name
    // stays on systemMonoFontFamily regardless, and neither follows the bar's
    // own font (Theme.fontText).
    // One shell command, like writeHyprAnimations: several `gsettings set`
    // calls in a row each start a fresh dbus round trip, and a change made
    // mid-burst (a slider dragged across several steps) would otherwise
    // launch one per step.
    function renderGtk() {
        var font = Settings.systemFontFamily + " " + systemFontSize
        var monoFont = systemMonoFontFamily + " " + systemFontSize
        var scheme = Theme.isLight ? "prefer-light" : "prefer-dark"
        var suffix = Theme.isLight ? "" : "-dark"
        var iface = "org.gnome.desktop.interface"
        var q = s => "'" + String(s).replace(/'/g, "'\\''") + "'"
        gtkSync.command = ["sh", "-c",
            "gsettings set " + iface + " font-name " + q(font) + "; " +
            "gsettings set " + iface + " document-font-name " + q(font) + "; " +
            "gsettings set " + iface + " monospace-font-name " + q(monoFont) + "; " +
            // adw-gtk3 where it's installed, else Adwaita, which GTK3 at
            // least draws dark rather than falling back to light
            "t=adw-gtk3" + suffix + "; for d in /usr/share/themes \"$HOME/.local/share/themes\" \"$HOME/.themes\"; do " +
            "[ -d \"$d/$t/gtk-3.0\" ] && f=1; done; [ \"$f\" ] || t=Adwaita" + suffix + "; " +
            "gsettings set " + iface + " gtk-theme \"$t\"; " +
            "gsettings set " + iface + " color-scheme " + q(scheme) + "; " +
            "gsettings set " + iface + " icon-theme " + q(Settings.iconTheme) + "; " +
            "gsettings set " + iface + " cursor-theme " + q(Settings.cursorTheme) + "; " +
            "gsettings set " + iface + " cursor-size " + Settings.cursorSize]
        gtkSync.running = true
    }

    // Qt apps (QT_QPA_PLATFORMTHEME=qt6ct) have no dconf-style live path, so
    // this is a real file -- picked up at each Qt app's next launch. `general`
    // follows Settings.systemFontFamily the same way GTK's font-name does;
    // `fixed` stays on systemMonoFontFamily. Neither follows the bar's own
    // font picker. custom_palette has to be on, or qt6ct falls back to its
    // style's own palette and color_scheme_path is ignored.

    // The GTK colours above as QPalette's 21 roles, in its enum order: Window
    // is GTK's window, Base its view, Button its headerbar and cards. Light
    // through Shadow are Fusion's bevels, derived from Button the way
    // QPalette's own constructor does. Accent (Qt 6.6's 22nd) is left out,
    // so Qt takes it from Highlight.
    function qtColours(disabled) {
        var fg = disabled ? Theme.muted : Theme.text
        var button = Theme.surface
        return [fg, button, Qt.lighter(button, 1.5), Qt.lighter(button, 1.25),
            Qt.darker(button, 2), Qt.darker(button, 1.5), fg, Theme.bright, fg,
            Theme.bar, Theme.panel, "#000000",
            disabled ? Theme.overlay : Theme.accent, disabled ? Theme.subtext : onAccent(),
            Theme.accent, mix(Theme.accent, Theme.subtext, 0.5),
            mix(Theme.bar, Theme.surface, 0.5), Theme.base,
            Theme.surface, Theme.text, Theme.subtext]
    }

    function renderQtScheme() {
        var argb = c => "#ff" + hex(c).slice(1)
        var row = d => qtColours(d).map(argb).join(", ")
        var text = ["[ColorScheme]",
            "active_colors=" + row(false),
            "disabled_colors=" + row(true),
            "inactive_colors=" + row(false)].join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/qt6ct-colors.conf", transform: () => text })
    }

    function renderQt() {
        var generalSpec = Settings.systemFontFamily + "," + systemFontSize + ",-1,5,50,0,0,0,0,0"
        var fixedSpec = systemMonoFontFamily + "," + systemFontSize + ",-1,5,50,0,0,0,0,0"
        var lines = ["[Appearance]",
            "color_scheme_path=" + root.dir + "/qt6ct-colors.conf",
            "custom_palette=true",
            "icon_theme=" + Settings.iconTheme,
            "style=Fusion",
            "",
            "[Fonts]",
            "fixed=\"" + fixedSpec + "\"",
            "general=\"" + generalSpec + "\""]
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({
            path: Quickshell.env("HOME") + "/.config/qt6ct/qt6ct.conf",
            transform: () => text,
        })
    }

    // Coalesced like Settings' own save: the steppers fire several steps in
    // a row, and each step would rewrite every file.
    Timer {
        id: debounce
        interval: 200
        onTriggered: {
            root.renderWofi(); root.renderAlacritty(); root.renderNvim(); root.renderClaude()
            root.renderHyprlock(); root.renderTermColors(); root.renderZathura()
            starshipTemplate.render(); fastfetchTemplate.render()
            root.renderGtk(); root.renderGtkCss(); root.renderQtScheme(); root.renderQt()
            root.renderBrowsers()
        }
    }

    Connections {
        target: Theme
        function onRadiusChanged() { debounce.restart() }
        function onPanelRadiusChanged() { debounce.restart() }
        function onRolesChanged() { debounce.restart() }
        function onFontScaleChanged() { debounce.restart() }
        function onFontTextChanged() { debounce.restart() }
        function onFrameDoubleChanged() { debounce.restart() }
        function onLookChanged() { debounce.restart() }
        function onAccentChanged() { debounce.restart() }
        function onIsLightChanged() { debounce.restart() }
        function onBorderWidthChanged() { debounce.restart() }
        function onPanelOpacityChanged() { debounce.restart() }
        function onHeadingColorChanged() { debounce.restart() }
        function onHeadingBoldChanged() { debounce.restart() }
        function onHeadingUpperChanged() { debounce.restart() }
    }

    Process { id: gtkSync }


    // watched, so editing ~/.config/wofi/style.css regenerates the copy wofi uses
    FileView {
        id: wofiTemplate
        path: Quickshell.env("HOME") + "/.config/wofi/style.css"
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: debounce.restart()
    }

    // Repo configs re-rendered in the current colours; watched, so editing
    // one regenerates its copy.
    component Template: FileView {
        property string out
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: debounce.restart()
        function render() {
            var t = text()
            if (t) AtomicFileWrite.write({ path: root.dir + "/" + out, transform: () => root.recolour(t) })
        }
    }
    Template { id: starshipTemplate;  path: Quickshell.env("HOME") + "/.config/starship.toml"; out: "starship.toml" }
    Template { id: fastfetchTemplate; path: Quickshell.env("HOME") + "/.config/fastfetch/config.jsonc"; out: "fastfetch.jsonc" }

    // Each browser's profile lists, re-read when it adds or switches profile.
    readonly property var browsers: [
        { base: Quickshell.env("HOME") + "/.config/zen", installs: zenInstalls, profiles: zenProfiles },
        { base: Quickshell.env("HOME") + "/.config/floorp", installs: floorpInstalls, profiles: floorpProfiles,
          userJs: floorpUserJs, chrome: floorpChrome },
    ]
    component ProfileList: FileView {
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: debounce.restart()
    }
    ProfileList { id: zenInstalls;    path: Quickshell.env("HOME") + "/.config/zen/installs.ini" }
    ProfileList { id: zenProfiles;    path: Quickshell.env("HOME") + "/.config/zen/profiles.ini" }
    ProfileList { id: floorpInstalls; path: Quickshell.env("HOME") + "/.config/floorp/installs.ini" }
    ProfileList { id: floorpProfiles; path: Quickshell.env("HOME") + "/.config/floorp/profiles.ini" }

    // Floorp's own prefs and chrome, kept in the repo beside its profiles:
    // the profile's user.js and userChrome.css are these plus the look's
    // block, so they're linked into whichever profile is active, whatever
    // its random name. Watched, so editing one rewrites the profile's copy.
    component ProfileSource: FileView {
        property bool ready: false
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { ready = true; debounce.restart() }
        onLoadFailed: ready = false
    }
    ProfileSource { id: floorpUserJs; path: Quickshell.env("HOME") + "/.config/floorp/singularity/user.js" }
    ProfileSource { id: floorpChrome; path: Quickshell.env("HOME") + "/.config/floorp/singularity/userChrome.css" }

    FileView { id: wofiOut;   path: root.dir + "/wofi.css"; printErrors: false }

    // Animation time reaches Hyprland through a state file its Lua config
    // reads on load, then a config-only reload (no monitor re-probe, so no
    // flicker). Written in one shell command so the reload can't run before
    // the write lands. At startup the file is only written, not reloaded:
    // Hyprland read the same value when it started.
    function writeHyprAnimations(reload) {
        var time = String(Settings.animTime)
        AtomicFileWrite.write({
            path: root.dir + "/animations",
            transform: () => time + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // The pointer and icon themes reach Hyprland the same way, for the
    // environment it gives apps at login: `cursor` holds "<theme> <size>",
    // `icons` the icon theme. The pointer Hyprland draws itself changes live
    // through setcursor; apps take a new cursor or icon theme from gsettings
    // (renderGtk) or qt6ct (renderQt).
    function writeCursor(apply) {
        var line = Settings.cursorTheme + " " + Settings.cursorSize
        AtomicFileWrite.write({
            path: root.dir + "/cursor",
            transform: () => line + "\n",
            after: apply ? "hyprctl setcursor '" + String(Settings.cursorTheme).replace(/'/g, "'\\''") + "' "
                + Settings.cursorSize + " >/dev/null" : "",
        })
        // The XCursor fallback, for apps that read neither gsettings nor
        // XCURSOR_THEME -- older X11 clients, some Qt and Electron apps under
        // XWayland -- which would otherwise draw Adwaita's pointer. libXcursor
        // searches ~/.local/share/icons before ~/.icons, and this one isn't a
        // link into the repo.
        var index = "[Icon Theme]\nName=Default\nComment=Default cursor theme\nInherits="
            + Settings.cursorTheme + "\n"
        AtomicFileWrite.write({
            path: Quickshell.env("HOME") + "/.local/share/icons/default/index.theme",
            transform: () => index,
        })
    }
    function writeIcons() {
        var theme = Settings.iconTheme
        AtomicFileWrite.write({ path: root.dir + "/icons", transform: () => theme + "\n" })
    }

    // The window animation style and the border colours (the accent for the
    // focused window, the ramp's border for the rest): state files
    // hyprland.lua reads on load, then a config-only reload.
    function writeWindowAnim(reload) {
        var style = Settings.windowAnim
        AtomicFileWrite.write({
            path: root.dir + "/window-anim",
            transform: () => style + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }
    function writeBorders(reload) {
        var line = "rgba(" + hex(Theme.strokeFocus).slice(1) + "ff) rgba(" + hex(Theme.border).slice(1) + "ff)"
        AtomicFileWrite.write({
            path: root.dir + "/borders",
            transform: () => line + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // Window corners, rounded like the shell's panels, so its own windows'
    // frames fill Hyprland's clip and every other window matches them.
    function writeRounding(reload) {
        var r = String(Theme.panelFrameRadius)
        AtomicFileWrite.write({
            path: root.dir + "/rounding",
            transform: () => r + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // The tab bar over hyprland.lua's grouped windows, always in the look's
    // colours: the lit tab like a selected row with an accent line over it,
    // the rest like the bar.
    function writeGroupbar(reload) {
        var rgba = c => "rgba(" + hex(c).slice(1) + "ff)"
        var line = [Theme.selectedFill, Theme.bar, Theme.text, Theme.subtext, Theme.accent].map(rgba).join(" ")
        AtomicFileWrite.write({
            path: root.dir + "/groupbar",
            transform: () => line + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // The windows' gap from the screen's edges, which a floating bar keeps too
    function writeGaps(reload) {
        var g = String(Settings.edgeGap)
        AtomicFileWrite.write({
            path: root.dir + "/gaps",
            transform: () => g + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // Stepping the gap fires once per step; one reload at the end is enough.
    Timer {
        id: gapsDebounce
        interval: 200
        onTriggered: root.writeGaps(true)
    }

    // "<focused> <unfocused>" window opacity, as Hyprland's 0-1 fractions
    function writeWindowOpacity(reload) {
        var line = (Settings.focusedOpacity / 100) + " " + (Settings.unfocusedOpacity / 100)
        AtomicFileWrite.write({
            path: root.dir + "/window-opacity",
            transform: () => line + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // Stepping either fires once per step; one reload at the end is enough.
    Timer {
        id: opacityDebounce
        interval: 200
        onTriggered: root.writeWindowOpacity(true)
    }

    // How much of the screen's top edge the bar takes (0 when it sits at the
    // bottom), for hyprland.lua's rule that opens the sticky notes clear of
    // it. A rule can't read the reserved space itself.
    function writeBarTop(reload) {
        var top = Theme.barPosition === "top" ? Theme.barExtent : 0
        AtomicFileWrite.write({
            path: root.dir + "/bar-top",
            transform: () => top + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // Stepping the height fires once per step; one reload at the end is enough.
    Timer {
        id: barTopDebounce
        interval: 200
        onTriggered: root.writeBarTop(true)
    }

    Connections {
        target: Theme
        function onBarPositionChanged() { barTopDebounce.restart() }
        function onBarExtentChanged() { barTopDebounce.restart() }
    }

    // The windows' border width and shadow, from the style: Heavy lines
    // thickens the border with the shell's strokes, and Shadows picks the
    // style's soft or hard shadow, or none.
    function writeWindowFrame(reload) {
        var line = Theme.borderWidth + " " + Theme.shadow
        AtomicFileWrite.write({
            path: root.dir + "/window-frame",
            transform: () => line + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    Timer {
        id: windowFrameDebounce
        interval: 200
        onTriggered: root.writeWindowFrame(true)
    }

    // Stepping the radius fires once per step; one reload at the end is enough.
    Timer {
        id: roundingDebounce
        interval: 200
        onTriggered: root.writeRounding(true)
    }

    Connections {
        target: Theme
        function onPanelFrameRadiusChanged() { roundingDebounce.restart() }
        function onBorderWidthChanged() { windowFrameDebounce.restart() }
        function onShadowChanged() { windowFrameDebounce.restart() }
    }

    // A look switch changes both colours at once; one reload is enough.
    Timer {
        id: bordersDebounce
        interval: 200
        onTriggered: root.writeBorders(true)
    }

    Connections {
        target: Theme
        function onStrokeFocusChanged() { bordersDebounce.restart() }
        function onBorderChanged() { bordersDebounce.restart() }
    }

    Timer {
        id: groupbarDebounce
        interval: 200
        onTriggered: root.writeGroupbar(true)
    }

    Connections {
        target: Theme
        function onSelectedFillChanged() { groupbarDebounce.restart() }
        function onBarChanged() { groupbarDebounce.restart() }
        function onTextChanged() { groupbarDebounce.restart() }
        function onSubtextChanged() { groupbarDebounce.restart() }
        function onAccentChanged() { groupbarDebounce.restart() }
    }

    // Stepping the size fires once per step; one setcursor at the end is enough.
    Timer {
        id: cursorDebounce
        interval: 200
        onTriggered: root.writeCursor(true)
    }

    // the Animations slider moves in steps; one Hyprland reload per drag
    Timer {
        id: animDebounce
        interval: 200
        onTriggered: root.writeHyprAnimations(true)
    }

    Connections {
        target: Settings
        function onAnimTimeChanged() { animDebounce.restart() }
        function onSystemFontFamilyChanged() { debounce.restart() }
        function onCursorThemeChanged() { cursorDebounce.restart(); debounce.restart() }
        function onCursorSizeChanged() { cursorDebounce.restart(); debounce.restart() }
        function onIconThemeChanged() { root.writeIcons(); debounce.restart() }
        function onWindowAnimChanged() { root.writeWindowAnim(true) }
        function onEdgeGapChanged() { gapsDebounce.restart() }
        function onFocusedOpacityChanged() { opacityDebounce.restart() }
        function onUnfocusedOpacityChanged() { opacityDebounce.restart() }
    }

    // Plus the first sync. root.dir needn't exist yet: FileView.setText and
    // AtomicFileWrite both create missing parent directories.
    Component.onCompleted: {
        writeHyprAnimations(false)
        writeCursor(false)
        writeIcons()
        writeWindowAnim(false)
        writeBorders(false)
        writeGroupbar(false)
        writeBarTop(false)
        writeRounding(false)
        writeGaps(false)
        writeWindowOpacity(false)
        writeWindowFrame(false)
        debounce.restart()
    }
}
