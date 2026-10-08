// Singularity - Quickshell
// ~/.config/quickshell/bar/Bar.qml
//
// One screen's bar window: its ground, the three groups' channels, and the
// slots the modules (BarModules.qml) are laid out in. shell.qml makes one
// per screen and hands it that screen's scope.

import "../services"
import "../flyouts"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick

PanelWindow {
    id: bar

    // the screen's scope in shell.qml (which flyout is open, where), the
    // shell's root, and the two menus the bar's modules open
    required property var screenScope
    required property var shellRoot
    required property var trayMenu
    required property var windowMenu
    screen: bar.screenScope.modelData

    // Both edges are listed and one is switched off, rather than
    // anchoring to a single computed edge: a PanelWindow with left
    // and right but neither top nor bottom is not a valid strut, so
    // the pair has to stay mutually exclusive.
    anchors {
        top: Theme.barPosition === "top"
        bottom: Theme.barPosition === "bottom"
        left: true
        right: true
    }
    // a floating bar's window also holds the gap between it and the
    // screen edge, so windows tile clear of the whole thing
    implicitHeight: Theme.barHeight + Theme.barMargin
    // Transparent, with the ground drawn by the Rectangle below. A
    // Wayland surface decides whether it has an alpha channel when
    // it's created, so a window that starts opaque stays opaque --
    // assigning a translucent colour to it later does nothing. A
    // window that starts transparent can show any opacity after.
    color: "transparent"

    // Where the bar is drawn: the whole window when full width, inset
    // from the screen edge and sides when floating. The modules lay
    // out inside this, not the window.
    Item {
        id: barBody
        x: Theme.barMargin
        y: Theme.barPosition === "bottom" ? 0 : Theme.barMargin
        width: parent.width - Theme.barMargin * 2
        height: Theme.barHeight
    }

    // Bar Opacity. Only the ground fades -- by its colour's alpha,
    // so a floating bar's stroke stays solid -- and the chips and
    // their text stay solid so the bar is still readable over a busy
    // wallpaper.
    // Theme.gradient: every ground below shaded top to bottom
    // Glass's accent-tinted option mixes a little of the accent in
    readonly property color barTone: Theme.glass && Theme.opt("tint")
        ? Qt.tint(Theme.bar, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)) : Theme.bar
    readonly property color barGround: Qt.rgba(bar.barTone.r, bar.barTone.g, bar.barTone.b, Theme.barOpacity)
    // a floating bar's or island's edge: Corners' is only a faint hairline
    readonly property color barEdge: Theme.frameCorners ? Theme.cornerHairline : Theme.stroke
    property Gradient barShading: Gradient {
        GradientStop { position: 0; color: Theme.shadeTop(bar.barGround) }
        GradientStop { position: 1; color: Theme.shadeBottom(bar.barGround) }
    }

    Rectangle {
        visible: Theme.barFull || Theme.barFloating
        anchors.fill: barBody
        color: bar.barGround
        gradient: Theme.gradient ? bar.barShading : null
        radius: Theme.barFloating ? Theme.barRadius : 0
        border.width: Theme.barFloating ? Theme.borderWidth : 0
        border.color: bar.barEdge
    }

    // Islands: the same ground, but one per group of modules, each
    // hugging its group with the gap between them left open. The
    // left and right ones reach the bar's edge; the centre one
    // follows its modules as they appear and hide.
    Repeater {
        model: Theme.barIslands ? Settings.widgetSections : []

        Rectangle {
            required property string modelData
            readonly property var span: bar.islandSpan(modelData)
            readonly property int pad: Theme.moduleGap + Theme.barInset
            visible: span.w > 0
            x: span.x - pad
            y: barBody.y
            width: span.w + pad * 2
            height: barBody.height
            radius: Theme.barRadius
            color: bar.barGround
            gradient: Theme.gradient ? bar.barShading : null
            border.width: Theme.borderWidth
            border.color: bar.barEdge
        }
    }

    // Grouped modules: one channel round each section's visible
    // modules, which sit flush inside its inner line.
    Repeater {
        model: Theme.moduleGrouped ? Settings.widgetSections : []

        Item {
            required property string modelData
            readonly property var rect: bar.groupRect(modelData)
            visible: rect !== null
            x: rect ? rect.x : 0
            y: rect ? rect.y : 0
            width: rect ? rect.w : 0
            height: rect ? rect.h : 0

            Channel { radius: Theme.groupRadius }
        }
    }

    // A section's channel, in the bar's coordinates; null when the
    // section shows nothing
    function groupRect(section) {
        var s = islandSpan(section)
        if (s.w <= 0) return null
        var pad = Theme.channelWidth
        return { x: s.x - pad, y: barBody.y + Math.round((Theme.barHeight - Theme.groupHeight) / 2),
                 w: s.w + pad * 2, h: Theme.groupHeight }
    }

    // the section a bar item (or anything inside one) sits in
    function sectionOf(item) {
        for (var p = item; p; p = p.parent) {
            if (p === leftSlots) return "left"
            if (p === centreSlots) return "centre"
            if (p === rightSlots) return "right"
        }
        return ""
    }

    // {x, w} of a section's visible modules, in the bar's coordinates
    function islandSpan(section) {
        if (section === "left") return { x: leftSlots.x, w: leftSlots.width }
        if (section === "right") return { x: rightSlots.x, w: rightSlots.width }
        var lo = Infinity, hi = -Infinity
        var o = centreSlots.order
        for (var i = 0; i < o.length; i++) {
            var it = widgetItem(o[i])
            if (!it || !it.visible) continue
            lo = Math.min(lo, it.x)
            hi = Math.max(hi, it.x + it.width)
        }
        return hi < lo ? { x: 0, w: 0 } : { x: centreSlots.x + lo, w: hi - lo }
    }

    // adapter.enabled mirrors BlueZ's "Powered" property, but
    // Quickshell writes it optimistically and never reverts it if
    // the D-Bus Set call errors or is a no-op -- if that ever
    // desyncs, "enabled" is stuck wrong with no way to notice.
    // adapter.state ("PowerState") is populated only from BlueZ's
    // own PropertiesChanged signals, so it's the true state.
    function btAdapterOn(a) {
        return !!a && a.state === BluetoothAdapterState.Enabled
    }
    function btAdapterBlocked(a) {
        return !!a && a.state === BluetoothAdapterState.Blocked
    }
    function setBtPowered(a, on) {
        if (!a || a.state === BluetoothAdapterState.Blocked) return
        a.enabled = on
    }

    // {source, address} for every window open on the focused
    // workspace, via each window's wmClass -> .desktop entry -> icon.
    // address lets the icon's click handler focus that exact window.
    // The windows the open-windows strip shows: the focused
    // workspace's, or with Theme.windowScope "all" every workspace's
    // in workspace order, each group's first marked so the strip can
    // rule it off from the one before.
    function focusedWorkspaceIcons() {
        // read this so the binding re-evaluates once the desktop
        // entry scan (async at startup) finishes populating it
        var entryCount = DesktopEntries.applications.values.length
        if (entryCount === 0) return []

        if (!Hyprland.focusedWorkspace) return []
        var wsId = Hyprland.focusedWorkspace.id
        var all = Theme.windowScope === "all"

        var wss = Hyprland.workspaces.values.slice()
            .filter(w => all ? w.id > 0 : w.id === wsId)
            .sort((x, y) => x.id - y.id)
        var icons = []
        for (var i = 0; i < wss.length; i++) {
            var tls = wss[i].toplevels.values
            var first = true
            for (var j = 0; j < tls.length; j++) {
                var cls = tls[j].lastIpcObject ? tls[j].lastIpcObject.class : ""
                if (!cls || Apps.isBackTabToplevel(tls[j])) continue
                var ipc = tls[j].lastIpcObject
                icons.push({
                    source: Apps.iconForClass(cls),
                    // drawn instead when nothing resolved, so a
                    // window is never silently missing from the strip
                    glyph: Apps.glyphForWindow(cls, ipc ? ipc.title : ""),
                    // for the index style, which names the app
                    name: Apps.nameForWindow(cls, ipc ? ipc.title : ""),
                    address: tls[j].address,
                    // live, for the title styles; read in the
                    // delegate so a title change doesn't rebuild the strip
                    toplevel: tls[j],
                    groupStart: first && icons.length > 0,
                })
                first = false
            }
        }
        return icons
    }

    // The open window belonging to a tray item, if any, so clicking
    // the tray icon can raise that window instead of asking the app
    // to (which many ignore, or answer by toggling it hidden). Tray
    // ids and titles are loose -- "spotify-client", "Discord",
    // "chrome_status_icon_1" -- so both sides are reduced to bare
    // lowercase letters and digits and matched on either one
    // containing the other.
    function trayItemWindow(item) {
        function norm(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "") }
        var keys = [norm(item.id), norm(item.title)].filter(function(k) { return k.length >= 3 })
        if (keys.length === 0) return null
        var tls = Hyprland.toplevels.values
        for (var pass = 0; pass < 2; pass++) {
            for (var i = 0; i < tls.length; i++) {
                var ipc = tls[i].lastIpcObject
                if (!ipc || isShellWindow(tls[i])) continue
                var names = [norm(ipc.class), norm(ipc.initialClass)]
                for (var n = 0; n < names.length; n++) {
                    var c = names[n]
                    if (c.length < 3) continue
                    for (var k = 0; k < keys.length; k++) {
                        // exact matches first, so "code" can't take
                        // a tray item meant for "codeblocks"
                        if (pass === 0 ? c === keys[k]
                                : (c.indexOf(keys[k]) !== -1 || keys[k].indexOf(c) !== -1))
                            return tls[i]
                    }
                }
            }
        }
        return null
    }

    // The shell's own standalone windows (System, Keybinds).
    // They show up in the window strip and in ALT+Tab like anything
    // else you have open -- they are real toplevels you can focus and
    // work in. What they stay out of is the shell's own bookkeeping:
    // the workspace flyout, and counting towards whether a workspace
    // has anything on it (a workspace holding only a Settings window
    // still reads as empty), and tray-icon matching, which is looking
    // for the app a tray item belongs to.
    function isShellWindow(tl) {
        return !!(tl.lastIpcObject && tl.lastIpcObject.class === "org.quickshell")
    }

    // an app open on workspace `id` for the workspace indicator's
    // apps style -- the first that isn't one of the shell's windows
    // -- as { source, glyph }, or null when there's none
    function workspaceApp(id) {
        var entryCount = DesktopEntries.applications.values.length
        var wss = Hyprland.workspaces.values
        for (var i = 0; i < wss.length; i++) {
            if (wss[i].id !== id) continue
            var tls = wss[i].toplevels.values
            for (var j = 0; j < tls.length; j++) {
                var ipc = tls[j].lastIpcObject
                if (!ipc || !ipc.class || isShellWindow(tls[j])) continue
                return { source: entryCount > 0 ? Apps.iconForClass(ipc.class) : "",
                         glyph: Apps.glyphForWindow(ipc.class, ipc.title) }
            }
        }
        return null
    }

    function workspaceHasWindows(id) {
        var wss = Hyprland.workspaces.values
        for (var i = 0; i < wss.length; i++) {
            if (wss[i].id !== id) continue
            var tls = wss[i].toplevels.values
            for (var j = 0; j < tls.length; j++)
                if (!isShellWindow(tls[j])) return true
            return false
        }
        return false
    }

    // every window on every workspace, for the workspace flyout
    function allWindows() {
        var out = []
        var wss = Hyprland.workspaces.values
        for (var i = 0; i < wss.length; i++) {
            var tls = wss[i].toplevels.values
            for (var j = 0; j < tls.length; j++) {
                if (isShellWindow(tls[j]) || Apps.isBackTabToplevel(tls[j])) continue
                var ipc = tls[j].lastIpcObject
                out.push({
                    ws: wss[i].id,
                    title: tls[j].title || (ipc && ipc.class ? ipc.class : "window"),
                    cls: ipc && ipc.class ? ipc.class : "",
                    address: tls[j].address
                })
            }
        }
        out.sort(function(a, b) { return a.ws - b.ws })
        return out
    }

    // --- module slots ----------------------------------------
    // The left and right groups are laid out by hand rather than by
    // a Row, because a Row can only place children in the order they
    // are declared, and Bar Widgets lets that order be changed. Each
    // module takes its x from the saved order: the sum of the widths
    // of the visible modules before it. A hidden module takes no
    // space, so the rest close up around it.

    // The bar's 19 modules, in BarModules.qml -- split out since
    // each module's own logic buried the layout plumbing below.
    BarModules {
        id: barModules
        bar: bar
        screenScope: bar.screenScope
        shellRoot: bar.shellRoot
        trayMenu: bar.trayMenu
        windowMenu: bar.windowMenu
    }

    function widgetItem(key) { return barModules.widgetItems[key] }

    // Every module lives in the slot container of its saved section,
    // at the x its saved order gives it. Bound here once rather than
    // on each module, so a module only declares what it shows.
    Component.onCompleted: {
        const items = barModules.widgetItems
        const defaults = [].concat(...Settings.widgetSections.map(s => Settings.widgetDefaults[s]))
        for (const key in items)
            if (!Settings.widgetMeta[key] || defaults.indexOf(key) < 0)
                console.warn("bar widget " + key + " is missing from Settings.widgetMeta or widgetDefaults")
        for (const key in Settings.widgetMeta)
            if (!items[key]) console.warn("Settings.widgetMeta lists " + key + ", which has no item in BarModules.widgetItems")
        for (const key in items) {
            const it = barModules.widgetItems[key]
            it.parent = Qt.binding(() => slotsFor(Settings.widgetSection(key)))
            it.x = Qt.binding(() => slotX(it.parent, key))
            it.slideX = Qt.binding(() => slotsAnimate)
        }
    }

    function slotsFor(section) {
        return section === "centre" ? centreSlots
            : section === "right" ? rightSlots : leftSlots
    }

    function slotX(slots, key) {
        if (slots === centreSlots) return centreX(key)
        var x = 0
        var o = slots.order
        for (var i = 0; i < o.length; i++) {
            if (o[i] === key) return x
            var it = slots.itemFor(o[i])
            if (it && it.visible) x += it.width + Theme.moduleSpacing
        }
        return x
    }

    // Centre positions. With a pinned module visible in the centre,
    // it sits dead centre and the rest are measured outward from its
    // edges; otherwise the visible modules are centred as one group.
    // Rounded, since a half-pixel x blurs the chip borders.
    function centreX(key) {
        var o = centreSlots.order
        var gap = Theme.moduleSpacing
        var ai = o.indexOf(Settings.centreAnchor)
        var anchorItem = ai >= 0 ? widgetItem(o[ai]) : null
        var ki = o.indexOf(key)
        var x = 0, i, it

        if (!anchorItem || !anchorItem.visible) {
            x = (centreSlots.width - slotsWidth(centreSlots)) / 2
            for (i = 0; i < ki; i++) {
                it = widgetItem(o[i])
                if (it && it.visible) x += it.width + gap
            }
            return Math.round(x)
        }

        var ax = (centreSlots.width - anchorItem.width) / 2
        if (ki === ai) return Math.round(ax)
        if (ki > ai) {
            x = ax + anchorItem.width + gap
            for (i = ai + 1; i < ki; i++) {
                it = widgetItem(o[i])
                if (it && it.visible) x += it.width + gap
            }
            return Math.round(x)
        }
        // left of the anchor: step back over each module down to and
        // including this one, landing on its left edge
        x = ax
        for (i = ai - 1; i >= ki; i--) {
            it = widgetItem(o[i])
            if (it && (it.visible || i === ki)) x -= it.width + gap
        }
        return Math.round(x)
    }

    function slotsWidth(slots) {
        var w = 0, n = 0
        var o = slots.order
        for (var i = 0; i < o.length; i++) {
            var it = slots.itemFor(o[i])
            if (it && it.visible) { w += it.width; n++ }
        }
        return w + Math.max(0, n - 1) * Theme.moduleSpacing
    }

    // Slides modules when the order changes, but not at startup,
    // where every module would sweep in from x=0 as widths settle.
    property bool slotsAnimate: false
    Timer {
        interval: 800
        running: true
        onTriggered: bar.slotsAnimate = true
    }

    // hairline on the bar's inner edge, so it reads as a surface
    // rather than a strip of background; Underline's hairline option
    // can leave it out
    Rectangle {
        visible: Theme.barFull && (Theme.style !== "underline" || Theme.opt("hair"))
        y: Theme.barPosition === "bottom" ? 0 : parent.height - height
        width: parent.width
        height: Theme.borderWidth
        color: Theme.stroke
    }


    // --- left: workspaces -------------------------------------
    Item {
        id: leftSlots
        anchors.left: barBody.left
        anchors.leftMargin: Theme.moduleGap + Theme.barInset
        anchors.top: barBody.top
        anchors.bottom: barBody.bottom
        width: bar.slotsWidth(leftSlots)

        readonly property var order: Settings.widgetOrder("left")
        function itemFor(k) { return bar.widgetItem(k) }

        ModuleSeparators { slots: leftSlots }
    }

    // --- centre -----------------------------------------------
    // Centred on the bar as a group, so whatever is moved in here
    // stays balanced around the middle of the screen.
    // Spans the whole bar, so positions inside it are bar positions
    // and "the middle" is simply half its width. It holds no input
    // handlers of its own, so it doesn't block clicks on either side.
    Item {
        id: centreSlots
        anchors.fill: barBody

        readonly property var order: Settings.widgetOrder("centre")
        function itemFor(k) { return bar.widgetItem(k) }

        ModuleSeparators { slots: centreSlots }
    }

    // --- right: system modules --------------------------------
    // All icons come from the Material Design set rather than a mix
    // of icon families: Font Awesome's bluetooth glyph in particular
    // is far narrower and taller than its speaker/wifi/battery, so a
    // mixed row never looks evenly weighted.
    // Tight gaps: the chips' own borders already separate them, so
    // a wide gap on top of that just scatters the row.
    Item {
        id: rightSlots
        anchors.right: barBody.right
        anchors.rightMargin: Theme.moduleGap + Theme.barInset
        anchors.top: barBody.top
        anchors.bottom: barBody.bottom

        width: bar.slotsWidth(rightSlots)

        readonly property var order: Settings.widgetOrder("right")
        function itemFor(k) { return bar.widgetItem(k) }

        ModuleSeparators { slots: rightSlots }
    }

    // The pinned modules' hitboxes run on to the screen's edges (full width
    // only; a floating bar has a gap there that isn't the bar), so the
    // corners click: a strip from the edge to the module's own, forwarding
    // the click to it.
    Repeater {
        model: Theme.barFull ? [
            { key: "controlcentre", side: "left" },
            { key: "desktop", side: "right" },
        ] : []

        MouseArea {
            id: edge
            required property var modelData
            readonly property Item target: bar.widgetItem(modelData.key)
            readonly property bool onLeft: modelData.side === "left"
            enabled: !!target && target.visible
            y: barBody.y
            height: barBody.height
            // the module's edge in window coordinates, followed as it slides
            readonly property real edgeX: target ? target.parent.x + target.x + (onLeft ? 0 : target.width) : 0
            x: onLeft ? 0 : edgeX
            width: onLeft ? edgeX : bar.width - edgeX
            cursorShape: Qt.PointingHandCursor
            onClicked: target.activated()
        }
    }

    // Keep Awake. The Wayland idle-inhibit protocol, rather than
    // `systemd-inhibit`: idle daemons (hypridle and friends) watch
    // this protocol, and it needs no process kept alive. It only
    // holds while its window is mapped, which is why it hangs off the
    // bar -- the one surface that is always up.
    IdleInhibitor {
        window: bar
        enabled: bar.shellRoot.keepAwake
    }
}
