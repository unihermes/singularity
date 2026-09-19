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

    // Coalesced like Settings' own save: the steppers fire several steps in
    // a row, and each swaync reload re-parses its whole stylesheet.
    Timer {
        id: debounce
        interval: 200
        onTriggered: { root.renderWofi(); root.renderSwaync(); root.renderAlacritty(); root.renderNvim() }
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


    }


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

    Connections {
        target: Settings
        function onAnimSpeedChanged() { root.writeHyprAnimations(true) }
    }

    // Plus the first sync. root.dir needn't exist yet: FileView.setText and
    // AtomicFileWrite both create missing parent directories.
    Component.onCompleted: {
        writeHyprAnimations(false)
        debounce.restart()
    }

    Process {
        id: swayncReload
        command: ["swaync-client", "--reload-css", "--skip-wait"]
    }
}
