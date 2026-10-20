// Singularity - Quickshell
// ~/.config/quickshell/services/Wallpaper.qml
//
// The wallpaper and its colours. hypr/wallpaper.sh shows it (a new swaybg
// each change) and restores it at login; this keeps the list and the saved
// choice. In wallpaper colour mode matugen's palette is mapped onto the
// ramp's roles and tinted towards the image (tint()), cached per image and
// scheme so startup doesn't flash grey.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/wallpaper.sh"
    // where the images are: the repo's wallpapers/, beside the script's link
    readonly property string folder: images.length > 0 ? images[0].substring(0, images[0].lastIndexOf("/")) : ""
    readonly property string stateDir: Settings.stateDir

    property var images: []
    property string current: ""
    readonly property int index: images.indexOf(current)
    readonly property string name: current === "" ? "" : current.substring(current.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "")
    // the name in words: monet_pale_lillies -> Monet pale lillies
    readonly property string title: {
        var s = name.replace(/[_-]+/g, " ").trim()
        return s === "" ? s : s[0].toUpperCase() + s.slice(1)
    }

    // role -> "#rrggbb", or null while there's no palette for the current
    // image and scheme (Theme then stays grayscale)
    property var palette: null
    property bool generating: false

    readonly property bool wanted: Settings.colourMode === "wallpaper"
    readonly property string scheme: Settings.colourScheme
    // "dark" or "light": which of matugen's two schemes the ramp is built from
    readonly property string variant: Settings.colourVariant

    function set(path) {
        if (!path || path === current) return
        current = path
        Quickshell.execDetached([script, "set", path, Settings.wallpaperFill])
        saveState()
    }

    function step(d) {
        if (images.length === 0) return
        var i = index < 0 ? 0 : (index + d + images.length) % images.length
        set(images[i])
    }

    function shuffle() {
        if (images.length < 2) return
        var i
        do { i = Math.floor(Math.random() * images.length) } while (images[i] === current)
        set(images[i])
    }

    function saveState() {
        if (current === "") return
        stateFile.setText("shuffle=" + (Settings.wallpaperShuffle ? 1 : 0) + "\nwallpaper=" + current
            + "\nmode=" + Settings.wallpaperFill + "\n")
    }

    // Bumped whenever the mapping below changes, so a palette cached by an
    // older mapping is regenerated rather than shown.
    readonly property int mappingVersion: 3
    function cacheValid(c) {
        return c.version === mappingVersion && c.scheme === scheme && c.variant === variant && !!c.colors
    }

    // how much of the source's saturation each Intensity lets in
    readonly property var tintStrength: ({
        "scheme-neutral": 0.3,
        "scheme-tonal-spot": 0.55,
        "scheme-vibrant": 0.8,
        "scheme-expressive": 0.8,
    })

    // a role keeps its lightness and takes the source's hue at `amount` of
    // its saturation (never less than it had)
    function tint(hex, source, amount) {
        var c = Qt.color(hex), src = Qt.color(source)
        var sat = Math.min(1, Math.max(c.hslSaturation, src.hslSaturation * amount))
        var out = Qt.hsla(src.hslHue, sat, c.hslLightness, 1)
        function h2(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }
        return "#" + h2(out.r) + h2(out.g) + h2(out.b)
    }

    function refresh() {
        if (!wanted || current === "") return
        if (cacheValid(cache) && cache.image === current) {
            palette = cache.colors
            return
        }
        // a run already in flight is for a stale image or scheme; restarting
        // it drops that result instead of letting it land over this one
        matugen.running = false
        matugen.command = ["matugen", "image", current, "--mode", variant, "--type", scheme,
                           "--prefer", "saturation", "--json", "hex", "--dry-run", "--quiet"]
        generating = true
        matugen.running = true
    }

    onWantedChanged: refresh()
    onSchemeChanged: refresh()
    onVariantChanged: refresh()
    onCurrentChanged: {
        refresh()
        if (rotate.running) rotate.restart()
    }

    Connections {
        target: Settings
        function onWallpaperShuffleChanged() { root.saveState() }
        // the same image again, fitted the new way
        function onWallpaperFillChanged() {
            root.saveState()
            if (root.current !== "") Quickshell.execDetached([root.script, "set", root.current, Settings.wallpaperFill])
        }
    }

    // a random wallpaper every Settings.wallpaperInterval minutes; any change
    // restarts the wait
    Timer {
        id: rotate
        interval: Math.max(1, Settings.wallpaperInterval) * 60000
        running: Settings.wallpaperInterval > 0 && root.images.length > 1
        repeat: true
        onTriggered: root.shuffle()
    }

    Process {
        running: true
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.images = text.split("\n").filter(l => l !== "")
        }
    }

    Process {
        running: true
        command: [root.script, "current"]
        stdout: StdioCollector {
            onStreamFinished: root.current = text.trim()
        }
    }

    Process {
        id: matugen
        stdout: StdioCollector {
            onStreamFinished: {
                root.generating = false
                var c
                try { c = JSON.parse(text).colors } catch (e) { return }
                if (!c) return
                var v = root.variant
                function pick(k) { return c[k][v].color }
                // grounds tinted from primary_container, strokes and text from
                // primary; the neutral scheme uses the seed colour
                var ground = pick("primary_container"), accent = pick("primary")
                if (Qt.color(ground).hslSaturation < 0.15) ground = accent = pick("source_color")
                var k = root.tintStrength[root.scheme] || 0.55
                // dark climbs the surface containers; light runs the other way
                var colors = v === "light" ? {
                    base:    root.tint(pick("surface_dim"),               ground, k),
                    bar:     root.tint(pick("surface_container_low"),     ground, k),
                    panel:   root.tint(pick("surface"),                   ground, k),
                    surface: root.tint(pick("surface_container"),         ground, k),
                    overlay: root.tint(pick("surface_container_highest"), ground, k),
                    border:  root.tint(pick("outline_variant"),           accent, k * 0.8),
                    muted:   root.tint(pick("outline"),                   accent, k * 0.8),
                    subtext: root.tint(pick("on_surface_variant"),        accent, k * 0.7),
                    text:    root.tint(pick("on_surface"),                accent, k * 0.5),
                    bright:  accent,
                } : {
                    base:    root.tint(pick("surface_container_lowest"),  ground, k),
                    bar:     root.tint(pick("surface"),                   ground, k),
                    panel:   root.tint(pick("surface_container_low"),     ground, k),
                    surface: root.tint(pick("surface_container"),         ground, k),
                    overlay: root.tint(pick("surface_container_high"),    ground, k),
                    border:  root.tint(pick("surface_container_highest"), ground, k),
                    muted:   root.tint(pick("outline_variant"),           accent, k * 0.8),
                    subtext: root.tint(pick("outline"),                   accent, k * 0.7),
                    text:    root.tint(pick("on_surface_variant"),        accent, k * 0.5),
                    bright:  accent,
                }
                root.palette = colors
                root.cache = { version: root.mappingVersion, image: root.current, scheme: root.scheme,
                               variant: v, colors: colors }
                cacheFile.setText(JSON.stringify(root.cache))
            }
        }
        onExited: code => { if (code !== 0) root.generating = false }
    }

    // What the last matugen run produced. Read before anything draws, so a
    // wallpaper-coloured shell starts wallpaper-coloured.
    property var cache: ({})

    FileView {
        id: cacheFile
        path: root.stateDir + "/palette.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: {
            try { root.cache = JSON.parse(text()) } catch (e) { root.cache = {} }
            // trust the cache for the scheme before swaybg has been asked
            // which image it's showing; refresh() re-checks the image after
            if (root.wanted && root.cacheValid(root.cache))
                root.palette = root.cache.colors
        }
    }

    FileView { id: stateFile; path: root.stateDir + "/wallpaper.state"; printErrors: false }
}
