// Singularity - Quickshell
// ~/.config/quickshell/launcher/Launcher.qml
//
// The search-first launcher. Four modes, cycled with Tab (Shift+Tab back):
//   apps       CTRL+SPACE   -- desktop entries (services/Apps.qml)
//   files      SUPER+S      -- names under $HOME via fd (services/Files.qml)
//   clipboard  SUPER+H      -- cliphist history (services/Clipboard.qml)
//   calc       SUPER+slash  -- arithmetic (services/Calc.js), Enter copies
// Opened via `qs ipc call launcher toggle <mode>`. In apps, a leading / ; or
// = switches to files, clipboard or calc. calc lists its result then the
// syntax, filtered as you type; Enter acts on the current row.
//
// This holds the modes, the results and what Enter does; the layout
// (Theme.launcherLayout) draws them, each in its own file:
//   list, grid, line  LauncherClassic   spotlight  LauncherSpotlight
//   home              LauncherHome      start      LauncherStart
//   drawer            LauncherDrawer    bar        LauncherBar
//   mosaic            LauncherMosaic
// Every layout's field is a LauncherField, which hands the keys to the
// layout (`view`): count, move(dx, dy), current() -> { item, kind }.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../flyouts"
import "../services/Calc.js" as Calc

OverlayWindow {
    id: root

    readonly property bool open: scope.openFlyout === "launcher"
    // Tab order. A mode the shell is asked for but doesn't know falls back
    // to apps rather than showing an empty box.
    readonly property var modes: ["apps", "files", "clipboard", "calc"]
    readonly property string mode: modes.indexOf(scope.launcherMode) !== -1 ? scope.launcherMode : "apps"
    property string query: ""
    readonly property string layout: Theme.launcherLayout

    function setMode(m) { root.scope.launcherMode = m }
    function stepMode(delta) {
        var i = modes.indexOf(mode)
        setMode(modes[(i + delta + modes.length) % modes.length])
    }

    readonly property var modeNames: ({
        "apps": "Applications", "clipboard": "Clipboard",
        "calc": "Calculator", "files": "Files"
    })
    readonly property string nextModeName: modeNames[modes[(modes.indexOf(mode) + 1) % modes.length]]
    // what a row is, by the mode it came from
    readonly property var kinds: ({ apps: "app", files: "file", clipboard: "clip", calc: "calc" })
    readonly property string kind: kinds[mode]
    readonly property var glyphs: ({ apps: "󰀻", files: "󰉋", clipboard: "󰅍", calc: "󰃬" })
    readonly property var placeholders: ({
        apps: "Search applications", files: "Search files in ~",
        clipboard: "Search clipboard", calc: "2 + 2 * 3, sqrt(16), 200 * 15%"
    })
    readonly property var prefixes: ({ "/": "files", ";": "clipboard", "=": "calc" })

    // Spotlight's apps mode searches everything at once
    readonly property bool blended: layout === "spotlight" && mode === "apps"

    // a mode's rows for a query
    function listFor(m, q) {
        if (m === "calc") {
            var res = Calc.evaluate(q)
            var rows = res.text === "" ? []
                : [{ kind: "result", text: res.text, ok: res.ok, hint: res.ok ? "Enter to copy" : "" }]
            var ref = Calc.reference(q)
            for (var i = 0; i < ref.length; i++)
                rows.push({ kind: "ref", text: ref[i].name, hint: ref[i].desc, insert: ref[i].insert })
            return rows
        }
        // nothing typed: the recent files, so the mode opens with something
        // useful rather than an empty box
        if (m === "files") return q.trim() === "" ? Files.recent : Files.results
        if (m === "clipboard") {
            var t = q.trim().toLowerCase()
            return t === "" ? Clipboard.history
                : Clipboard.history.filter(e => e.preview.toLowerCase().indexOf(t) !== -1)
        }
        return Apps.list(q)
    }
    readonly property var items: open ? listFor(mode, query) : []

    // the blended search: [{ item, kind, section }], a sum's answer first,
    // then the best app (or file) as the top hit, then each kind's next few
    readonly property var blendedItems: {
        if (!open || !blended || query.trim() === "") return []
        var out = []
        var sum = Calc.evaluate(query)
        if (sum.ok && /[0-9]/.test(query) && /[-+*\/^%(]/.test(query))
            out.push({ item: { kind: "result", text: sum.text, ok: true, hint: "Enter to copy" },
                       kind: "calc", section: "Calculator" })
        var apps = Apps.list(query).slice(0, 5)
        var files = Files.results.slice(0, 4)
        var clips = listFor("clipboard", query).slice(0, 3)
        if (apps.length > 0) out.push({ item: apps.shift(), kind: "app", section: "Top hit" })
        else if (files.length > 0) out.push({ item: files.shift(), kind: "file", section: "Top hit" })
        apps.forEach(a => out.push({ item: a, kind: "app", section: "Applications" }))
        files.forEach(f => out.push({ item: f, kind: "file", section: "Files" }))
        clips.forEach(c => out.push({ item: c, kind: "clip", section: "Clipboard" }))
        return out
    }

    readonly property string emptyText: mode === "calc" ? "No matching syntax"
        : mode === "files"
            ? (query === "" ? "No recent files" : Files.searching ? "Searching…" : "No matches")
        : query !== "" ? "No matches"
        : mode === "clipboard" ? "Clipboard history is empty" : "No applications"

    // the key hints over the field, for the mode on show
    readonly property var hints: (mode === "clipboard" ? ["Enter copy", "Shift+Del remove"]
            : mode === "calc" ? ["Enter copy"]
            : mode === "files" ? ["Enter open", "Shift+Enter folder"]
            : ["Enter open"]).concat(["Tab " + nextModeName])

    readonly property bool full: Theme.launcherPosition === "full"
    readonly property bool underBar: Theme.launcherPosition === "top"
    readonly property bool atBottom: Theme.barPosition === "bottom"
    readonly property bool details: Theme.launcherDetails && layout !== "line"
    // the desktop dimmed behind: full screen, and Mosaic always
    readonly property bool dimmed: (full && Theme.launcherPlaced) || layout === "mosaic"

    // the field the layout shows, for focus and for typing into
    property Item field: null
    signal wasReset()
    signal wasTyped()

    // where the Control Centre and the clock sit on the bar, taken at each
    // open (the Start menu hangs from one, In the bar's field covers the other)
    property real controlX: -1
    property real clockX: -1
    function barX(key) {
        var it = scope.barWindow ? scope.barWindow.widgetItem(key) : null
        return it && it.visible ? it.mapToItem(null, it.width / 2, 0).x : -1
    }

    // only real pointer movement moves the selection (keys scroll rows under
    // a still pointer)
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(item, x, y) {
        var p = item.mapToGlobal(x, y)
        if (p.x === lastPointer.x && p.y === lastPointer.y) return false
        lastPointer = p
        return true
    }

    function requestClose() { scope.openFlyout = "" }

    function reset() {
        query = ""
        controlX = barX("controlcentre")
        clockX = barX("clock")
        if (field) field.clear()
        if (mode === "clipboard" || layout === "spotlight" || layout === "home") Clipboard.refresh()
        if (mode === "files" || layout === "home") Files.refreshRecent()
        Files.clear()
        wasReset()
        if (field) Qt.callLater(field.forceFocus)
    }

    function typed(text) {
        if (mode === "apps" && text.length === 1 && prefixes[text]) {
            // later: the switch clears the field this is still handling
            Qt.callLater(setMode, prefixes[text])
            return
        }
        query = text
        if (mode === "files" || blended) Files.search(text)
        wasTyped()
    }

    function activate(item, kind) {
        if (!item) return
        // the calculator stays open: one result usually leads to the next
        // expression, and the copy is the whole action
        if (kind === "calc") {
            // a syntax row types itself into the expression instead of
            // acting, so the list is completion as well as a reminder
            if (item.kind === "ref") {
                if (field) field.insertAtWord(item.insert)
                return
            }
            if (item.ok) Quickshell.execDetached(["wl-copy", "--", item.text])
            return
        }
        requestClose()
        if (kind === "clip") Clipboard.select(item)
        else if (kind === "file") Files.open(item)
        else Apps.launch(item)
    }

    // Shift+Enter: the row's second action, where it has one
    function activateAlt(item, kind) {
        if (kind !== "file" || !item) return
        requestClose()
        Files.reveal(item)
    }

    function remove(item, kind) {
        if (kind === "clip" && item) Clipboard.remove(item)
    }

    // LazyFlyout builds the launcher already open, so the first open sends
    // no onOpenChanged
    Component.onCompleted: if (open) reset()
    onOpenChanged: if (open) reset()
    onModeChanged: if (open) reset()
    onLayoutChanged: if (open) Qt.callLater(reset)

    visible: open
    focusMode: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    layerNamespace: "singularity-flyout"

    Rectangle {
        anchors.fill: parent
        visible: root.dimmed
        color: Theme.backdrop
    }

    Backdrop {
        onDismissed: root.requestClose()
    }

    // a press on the other monitor too
    DismissGrab { panel: root }

    // every row two lines tall with details on, so a box keeps one size
    // across modes; one-line rows for the denser layouts
    FontMetrics { id: bodyMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontBody }
    FontMetrics { id: captionMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontCaption }
    readonly property int rowHeight: Math.max(Theme.fieldHeight,
        Math.ceil(bodyMetrics.height + (details ? 1 + captionMetrics.height : 0)) + Theme.spaceM)
    readonly property int lineHeight: Math.max(Theme.rowHeightTall, Math.ceil(bodyMetrics.height) + Theme.spaceM)

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            spotlight: spotlight, home: home, start: start,
            drawer: drawer, bar: bar, mosaic: mosaic,
        })[root.layout] || classic
    }

    Component { id: classic; LauncherClassic { launcher: root } }
    Component { id: spotlight; LauncherSpotlight { launcher: root } }
    Component { id: home; LauncherHome { launcher: root } }
    Component { id: start; LauncherStart { launcher: root } }
    Component { id: drawer; LauncherDrawer { launcher: root } }
    Component { id: bar; LauncherBar { launcher: root } }
    Component { id: mosaic; LauncherMosaic { launcher: root } }
}
