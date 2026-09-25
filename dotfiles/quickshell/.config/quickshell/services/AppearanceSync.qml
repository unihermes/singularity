// Singularity - Quickshell
// ~/.config/quickshell/services/AppearanceSync.qml
//
// Carries the Appearance page's settings out to the apps that draw the same
// chrome as the bar -- corner radius, the palette (the look's or the
// wallpaper's), font, font size and frame style -- so the launcher and the
// notifications change with it.
//
// Everything lands in ~/.local/state/neutrino/, never in ~/.config: those
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
//   swaync.css  -- CSS variables only. swaync loads its stylesheet from a
//                  path, so its style.css @imports this and uses var().
//   alacritty.toml -- the terminal's colours, imported by alacritty.toml.
//                  alacritty watches imports, so open windows follow along.
//   nvim.lua    -- the editor's palette, read by nvim's colors/neutrino.lua.
//                  nvim watches it and recolours open sessions.
//   hyprlock.conf -- hyprlang variables (colours, font, radius, stroke) that
//                  hypr/hyprlock.conf sources. hyprlock reads it at each lock.
//   gtk3.css, gtk4.css -- the accent as GTK's selection and accent colours,
//                  @imported by gtk-3.0/gtk.css and gtk-4.0/gtk.css. GTK reads
//                  them at each app's launch.
//   qt6ct-colors.conf -- qt6ct's stock scheme for dark or light with the
//                  accent as Highlight; qt6ct.conf points at it.
//
// Zen's and Floorp's active profiles get the accent as Gecko's selection and
// accent colours, in a marked block of their user.js (browserPrefs), and
// Floorp its theme's own accent variables in one of chrome/userChrome.css
// (browserChrome). The rest of each file is left alone. Read at each
// browser start.
//
// GTK and Qt apps get dark or light, the icon and cursor themes, and the
// system font -- this is the only place any of those are set. Not the
// shell's own font (Settings.fontFamily/Theme.fontText), which is for the
// shell's chrome alone (wofi, swaync, the bar): GTK/Qt use systemFontFamily
// and systemFontSize below.
//   gsettings   -- gtk-theme/color-scheme, the icon and cursor themes, and the
//                  system font, written live to dconf (no file, so
//                  nothing to watch -- GTK apps read dconf directly, and
//                  xdg-desktop-portal-gtk forwards color-scheme to portal-aware
//                  Qt/GTK4 apps).
//   qt6ct.conf  -- Qt apps (QT_QPA_PLATFORMTHEME=qt6ct, hyprland.lua) have no
//                  live dconf-style path, so this is a real file, read at each
//                  Qt app's next launch. It switches between two of qt6ct's
//                  own stock colour schemes rather than a palette built from
//                  Theme's roles -- close enough for light vs dark, and far
//                  less to get wrong than hand-mapping all 21 QPalette roles.
//   ~/.local/share/icons/default/index.theme -- the XCursor fallback,
//                  inheriting the cursor theme (writeCursor).

import Quickshell
import Quickshell.Io
import QtQuick
import "Looks.js" as Looks

Scope {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/neutrino"

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
    function px(offset) { return Math.max(0, Theme.radius - offset) + "px" }

    function renderWofi() {
        var tpl = wofiTemplate.text()
        if (!tpl) return
        var out = tpl.replace(/\d+px(\s*)\/\*\s*@radius(?:-(\d+))?\s*\*\//g,
            (m, sp, off) => px(parseInt(off || "0")) + sp + "/* @radius" + (off ? "-" + off : "") + " */")
        out = out.replace(/(\d+)px(\s*)\/\*\s*@font\s*\*\//g,
            (m, n, sp) => Theme.fs(parseInt(n)) + "px" + sp + "/* @font */")
        var ref = Looks.looks[Looks.reference].palette
        out = out.replace(/#[0-9a-fA-F]{6}\b/g, m => {
            var lower = m.toLowerCase()
            for (var i = 0; i < roleNames.length; i++)
                if (ref[roleNames[i]] === lower) return hex(Theme[roleNames[i]])
            return m
        })
        out = out.replace(/font-family:\s*"[^"]*"/g, 'font-family: "' + Theme.fontText + '"')
        out = tagged(out, "frame", "#[0-9a-fA-F]{6}",
            Theme.frameDouble ? hex(Theme.frameStroke) : hex(Theme.panel))
        out = tagged(out, "accent", "#[0-9a-fA-F]{6}", hex(Theme.accent))
        out = tagged(out, "focus", "#[0-9a-fA-F]{6}", hex(Theme.strokeFocus))
        out = tagged(out, "hover", "#[0-9a-fA-F]{6}", hex(Theme.hoverFill))
        out = tagged(out, "panel-bg", "#[0-9a-fA-F]{6}|rgba\\([^)]*\\)", rgba(Theme.panel, Theme.panelOpacity))
        out = tagged(out, "bw", "\\d+px", Theme.borderWidth + "px")
        wofiOut.setText(out)
    }

    function renderSwaync() {
        var lines = [":root {",
            "  --neutrino-radius: " + px(0) + ";",
            "  --neutrino-radius-inner: " + px(2) + ";",
            // the inner stroke's colour, or nothing when the frame is single
            "  --n-frame: " + (Theme.frameDouble ? hex(Theme.frameStroke) : hex(Theme.panel)) + ";",
            '  --n-font: "' + Theme.fontText + '";',
            // the look's structure: its hue, stroke weight, glassiness,
            // meter colour and heading style
            "  --n-accent: " + hex(Theme.accent) + ";",
            "  --n-focus: " + hex(Theme.strokeFocus) + ";",
            "  --n-meter: " + hex(Theme.meterFill) + ";",
            "  --n-bw: " + Theme.borderWidth + "px;",
            "  --n-panel-bg: " + rgba(Theme.panel, Theme.panelOpacity) + ";",
            "  --n-heading: " + hex(Theme.headingColor) + ";",
            "  --n-heading-weight: " + (Theme.headingBold ? "bold" : "normal") + ";",
            "  --n-heading-spacing: " + Theme.headingSpacing + "px;",
            "  --n-heading-case: " + (Theme.headingUpper ? "uppercase" : "none") + ";"]
        for (var i = 0; i < roleNames.length; i++)
            lines.push("  --n-" + roleNames[i] + ": " + hex(Theme[roleNames[i]]) + ";")
        // swaync's own sheet wants this one as a bare "r, g, b" triple
        var p = Theme.panel
        lines.push("  --noti-bg: " + Math.round(p.r * 255) + ", " + Math.round(p.g * 255) + ", " + Math.round(p.b * 255) + ";")
        // the shell's type scale (Theme.fontSmall / fontBody), so a
        // notification reads the same size as a flyout row
        var sizes = { small: 11, label: 13, body: 13, summary: 13 }
        for (var k in sizes)
            lines.push("  --n-fs-" + k + ": " + Theme.fs(sizes[k]) + "px;")
        lines.push("}")
        swayncOut.setText(lines.join("\n") + "\n")
        // only after the write has landed, or swaync re-reads the old file
        swayncReload.running = true
    }

    // a + (b - a) * t per channel, as a hex
    function mix(a, b, t) {
        return hex(Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                           a.b + (b.b - a.b) * t, 1))
    }

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
            "background = " + q(hex(Theme.border)),
            "text = " + q(hex(Theme.bright)),
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
    // status hues. colors/neutrino.lua builds every highlight from it, and
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
            "$n_fs_clock = " + Theme.fs(64)]
        var text = lines.join("\n") + "\n"
        AtomicFileWrite.write({ path: root.dir + "/hyprlock.conf", transform: () => text })
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
    function onAccent() {
        return contrast(Theme.accent, Theme.base) >= contrast(Theme.accent, Theme.bright)
            ? Theme.base : Theme.bright
    }

    // GTK3's Adwaita has its colours compiled into its rules, so overriding
    // its named colours changes nothing; these are rules of their own. GTK4
    // (libadwaita's variables and GTK's own named colours) takes the colours
    // themselves.
    function renderGtkCss() {
        var a = hex(Theme.accent), t = hex(onAccent())
        var header = "/* Generated by quickshell/services/AppearanceSync.qml -- edits are overwritten. */\n"
        var gtk3 = header
            + "@define-color theme_selected_bg_color " + a + ";\n"
            + "@define-color theme_selected_fg_color " + t + ";\n"
            + "selection, *:selected, *:selected:focus, row:selected, treeview.view:selected,\n"
            + "entry selection, textview text selection, label selection {\n"
            + "  background-color: " + a + ";\n  color: " + t + ";\n}\n"
        var gtk4 = header
            + ":root {\n"
            + "  --accent-bg-color: " + a + ";\n"
            + "  --accent-fg-color: " + t + ";\n"
            + "  --accent-color: " + a + ";\n"
            + "}\n"
            + "@define-color accent_bg_color " + a + ";\n"
            + "@define-color accent_fg_color " + t + ";\n"
            + "@define-color accent_color " + a + ";\n"
            + "@define-color theme_selected_bg_color " + a + ";\n"
            + "@define-color theme_selected_fg_color " + t + ";\n"
        AtomicFileWrite.write({ path: root.dir + "/gtk3.css", transform: () => gtk3 })
        AtomicFileWrite.write({ path: root.dir + "/gtk4.css", transform: () => gtk4 })
    }

    // Gecko takes any of its system colours from a ui.<name> pref. Zen's
    // accent (zen.theme.accent-color) defaults to AccentColor, so it follows
    // ui.accentcolor unless it was picked by hand in Zen's own settings.
    readonly property string browserMark: "neutrino: begin -- generated by quickshell AppearanceSync, edits are overwritten"

    function browserPrefs() {
        var a = hex(Theme.accent), t = hex(onAccent())
        var pref = (k, v) => 'user_pref("' + k + '", ' + v + ');'
        var str = v => '"' + v + '"'
        return [pref("ui.highlight", str(a)), pref("ui.highlighttext", str(t)),
            pref("ui.selecteditem", str(a)), pref("ui.selecteditemtext", str(t)),
            pref("ui.accentcolor", str(a)), pref("ui.accentcolortext", str(t)),
            pref("toolkit.legacyUserProfileCustomizations.stylesheets", "true")]
    }

    // Floorp's lightweight theme hard-codes cyan (the urlbar's focus ring,
    // links, primary buttons) and blue (the selected urlbar result) in place
    // of the system colours above. They're all variables on :root; unlayered
    // !important here outranks the browser's layered tokens.
    // The line over the selected tab (.tab-context-line, Floorp's Photon UI)
    // is --tab-line-color, which Lepton sets on #tabbrowser-tabs and on the
    // line itself rather than inheriting it from :root, so it's set on all three.
    // Lepton tells the selected tab by [selected="true"], but Gecko now sets
    // `selected` bare, so its rules hide the line there (and grey it on hover);
    // the last rule shows it on the tabs that are actually selected.
    function browserChrome() {
        var a = hex(Theme.accent), t = hex(onAccent())
        var vars = {
            "--focus-outline-color": a,
            "--color-accent-primary": a,
            "--color-accent-primary-hover": a,
            "--color-accent-primary-active": a,
            "--color-accent-primary-selected": a,
            "--button-text-color-primary": t,
            "--urlbarview-background-color-selected": a,
            "--urlbarview-text-color-selected": t,
        }
        var lines = [":root {"]
        for (var k in vars) lines.push("  " + k + ": " + vars[k] + " !important;")
        lines.push("}", ":root, #tabbrowser-tabs, .tab-context-line {",
            "  --tab-line-color: " + a + " !important;",
            "  --lwt-tab-line-color: " + a + " !important;",
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
        var re = new RegExp("\\n?" + esc(open + browserMark) + "[\\s\\S]*?"
            + esc(open + "neutrino: end" + close) + "\\n?")
        var rest = text.replace(re, "\n").replace(/\n+$/, "")
        var block = [open + browserMark + close].concat(lines, [open + "neutrino: end" + close])
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

    function renderBrowsers() {
        var prefs = browserPrefs(), chrome = browserChrome()
        for (var i = 0; i < browsers.length; i++) {
            var b = browsers[i]
            var profile = activeProfile(b.base, b.installs.text(), b.profiles.text())
            if (!profile) continue
            AtomicFileWrite.write({
                path: profile + "/user.js",
                transform: text => withBlock(text, "// ", "", prefs),
            })
            if (b.chrome)
                AtomicFileWrite.write({
                    path: profile + "/chrome/userChrome.css",
                    transform: text => withBlock(text, "/* ", " */", chrome),
                })
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
        var gtkTheme = Theme.isLight ? "Adwaita" : "Adwaita-dark"
        var iface = "org.gnome.desktop.interface"
        var q = s => "'" + String(s).replace(/'/g, "'\\''") + "'"
        gtkSync.command = ["sh", "-c",
            "gsettings set " + iface + " font-name " + q(font) + "; " +
            "gsettings set " + iface + " document-font-name " + q(font) + "; " +
            "gsettings set " + iface + " monospace-font-name " + q(monoFont) + "; " +
            "gsettings set " + iface + " gtk-theme " + q(gtkTheme) + "; " +
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
    // font picker -- only the colour scheme follows Theme.
    // custom_palette has to be on, or qt6ct falls back to its style's own
    // palette and color_scheme_path is ignored. The scheme is one of qt6ct's
    // own stock files (see the file header) with the accent swapped in
    // (renderQtScheme), not a palette built from Theme's roles.
    readonly property string qtDarkScheme:  "/usr/share/qt6ct/colors/darker.conf"
    readonly property string qtLightScheme: "/usr/share/qt6ct/colors/ia_ora.conf"

    // The stock scheme with the accent in Highlight and HighlightedText
    // (slots 12 and 13 of QPalette's 21), in every colour group.
    function renderQtScheme() {
        var tpl = (Theme.isLight ? qtLightTemplate : qtDarkTemplate).text()
        if (!tpl) return
        var argb = c => "#ff" + hex(c).slice(1)
        var a = argb(Theme.accent), t = argb(onAccent())
        var out = tpl.replace(/^(\w+_colors=)(.*)$/gm, (m, key, list) => {
            var cols = list.split(/\s*,\s*/)
            if (cols.length > 13) { cols[12] = a; cols[13] = t }
            return key + cols.join(", ")
        })
        AtomicFileWrite.write({ path: root.dir + "/qt6ct-colors.conf", transform: () => out })
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
    // a row, and each swaync reload re-parses its whole stylesheet.
    Timer {
        id: debounce
        interval: 200
        onTriggered: {
            root.renderWofi(); root.renderSwaync(); root.renderAlacritty(); root.renderNvim()
            root.renderHyprlock()
            root.renderGtk(); root.renderGtkCss(); root.renderQtScheme(); root.renderQt()
            root.renderBrowsers()
        }
    }

    Connections {
        target: Theme
        function onRadiusChanged() { debounce.restart() }
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


    // watched, so editing ~/.config/wofi/style.css (not in the repo; wofi is
    // only the fallback launcher) regenerates the copy wofi uses
    FileView {
        id: wofiTemplate
        path: Quickshell.env("HOME") + "/.config/wofi/style.css"
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: debounce.restart()
    }

    FileView {
        id: qtDarkTemplate
        path: root.qtDarkScheme
        preload: true
        printErrors: false
        onLoaded: debounce.restart()
    }
    FileView {
        id: qtLightTemplate
        path: root.qtLightScheme
        preload: true
        printErrors: false
        onLoaded: debounce.restart()
    }

    // Each browser's profile lists, re-read when it adds or switches profile.
    readonly property var browsers: [
        { base: Quickshell.env("HOME") + "/.config/zen", installs: zenInstalls, profiles: zenProfiles },
        { base: Quickshell.env("HOME") + "/.config/floorp", installs: floorpInstalls, profiles: floorpProfiles,
          chrome: true },
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

    FileView { id: wofiOut;   path: root.dir + "/wofi.css"; printErrors: false }
    FileView { id: swayncOut; path: root.dir + "/swaync.css"; printErrors: false }

    // Animation Speed reaches Hyprland through a state file its Lua config
    // reads on load, then a config-only reload (no monitor re-probe, so no
    // flicker). Written in one shell command so the reload can't run before
    // the write lands. At startup the file is only written, not reloaded:
    // Hyprland read the same value when it started.
    function writeHyprAnimations(reload) {
        var speed = String(Settings.animSpeed)
        AtomicFileWrite.write({
            path: root.dir + "/animations",
            transform: () => speed + "\n",
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

    // The window animation style and, when they follow the shell, the border
    // colours: state files hyprland.lua reads on load, then a config-only
    // reload. An empty borders file leaves hyprland.lua's own colours.
    function writeWindowAnim(reload) {
        var style = Settings.windowAnim
        AtomicFileWrite.write({
            path: root.dir + "/window-anim",
            transform: () => style + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }
    function writeBorders(reload) {
        var line = Settings.borderFollowsTheme
            ? "rgba(" + hex(Theme.strokeFocus).slice(1) + "ff) rgba(" + hex(Theme.border).slice(1) + "ff)" : ""
        AtomicFileWrite.write({
            path: root.dir + "/borders",
            transform: () => line + "\n",
            after: reload ? "hyprctl reload config-only >/dev/null" : "",
        })
    }

    // A look switch changes both colours at once; one reload is enough.
    Timer {
        id: bordersDebounce
        interval: 200
        onTriggered: root.writeBorders(true)
    }

    Connections {
        target: Theme
        enabled: Settings.borderFollowsTheme
        function onStrokeFocusChanged() { bordersDebounce.restart() }
        function onBorderChanged() { bordersDebounce.restart() }
    }

    // Stepping the size fires once per step; one setcursor at the end is enough.
    Timer {
        id: cursorDebounce
        interval: 200
        onTriggered: root.writeCursor(true)
    }

    Connections {
        target: Settings
        function onAnimSpeedChanged() { root.writeHyprAnimations(true) }
        function onSystemFontFamilyChanged() { debounce.restart() }
        function onCursorThemeChanged() { cursorDebounce.restart(); debounce.restart() }
        function onCursorSizeChanged() { cursorDebounce.restart(); debounce.restart() }
        function onIconThemeChanged() { root.writeIcons(); debounce.restart() }
        function onWindowAnimChanged() { root.writeWindowAnim(true) }
        function onBorderFollowsThemeChanged() { bordersDebounce.restart() }
    }

    // Plus the first sync. root.dir needn't exist yet: FileView.setText and
    // AtomicFileWrite both create missing parent directories.
    Component.onCompleted: {
        writeHyprAnimations(false)
        writeCursor(false)
        writeIcons()
        writeWindowAnim(false)
        writeBorders(false)
        debounce.restart()
    }

    Process {
        id: swayncReload
        command: ["swaync-client", "--reload-css", "--skip-wait"]
    }
}
