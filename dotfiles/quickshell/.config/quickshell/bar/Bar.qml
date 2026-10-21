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
    // shell's root, and the tray menu the bar's modules open
    required property var screenScope
    required property var shellRoot
    required property var trayMenu
    screen: bar.screenScope.modelData

    // both edges listed, one switched off: left+right with neither top nor
    // bottom isn't a valid strut
    anchors {
        top: Theme.barPosition === "top"
        bottom: Theme.barPosition === "bottom"
        left: true
        right: true
    }
    // a floating bar's window also holds the gap between it and the
    // screen edge, so windows tile clear of the whole thing
    implicitHeight: Theme.barHeight + Theme.barMargin
    // transparent at creation, or the surface can never show opacity
    color: "transparent"

    // a press no module takes is the click off that closes an open flyout;
    // a right-click opens the bar's own menu there
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            mouse.accepted = false
            if (mouse.button !== Qt.RightButton) {
                bar.shellRoot.closeFlyouts(null)
                return
            }
            bar.screenScope.flyoutAnchorX = mouse.x
            bar.screenScope.flyoutSection = ""
            bar.screenScope.openFlyout = "barmenu"
        }
    }

    // where the bar is drawn: the whole window, or inset when floating
    Item {
        id: barBody
        x: Theme.barMargin
        y: Theme.barPosition === "bottom" ? 0 : Theme.barMargin
        width: parent.width - Theme.barMargin * 2
        height: Theme.barHeight
    }

    // See-through fades the ground only (chips stay solid); shaded under
    // Theme.gradient, tinted under Glass's tint option
    readonly property color barTone: Theme.glass && Theme.opt("tint")
        ? Qt.tint(Theme.bar, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)) : Theme.bar
    readonly property color barGround: Qt.rgba(bar.barTone.r, bar.barTone.g, bar.barTone.b, Theme.barOpacity)
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
        border.color: Theme.stroke
    }

    // Islands: a ground per module group; the centre one follows its modules
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
            border.color: Theme.stroke
        }
    }

    // Grouped modules: one frame round each section's visible modules,
    // which sit flush inside it: a channel, or the style's own strokes
    // round a surface ground (Chips set to Strip under another style).
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

            Channel { visible: Theme.frameChannel; radius: Theme.groupRadius }

            Rectangle {
                visible: !Theme.frameChannel
                anchors.fill: parent
                radius: Theme.groupRadius
                color: Theme.glass ? (Theme.isLight ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)) : Theme.surface
                border.width: Theme.frameStroked ? Theme.borderWidth : 0
                border.color: Theme.stroke

                // the inner stroke of a double frame, faint unless lit
                Rectangle {
                    visible: Theme.frameDouble
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Math.max(0, parent.radius - 2)
                    color: "transparent"
                    border.width: Theme.borderWidth
                    border.color: Theme.opt("lit") ? Theme.frameStroke : Theme.surface
                }
            }
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
            var it = slotItem(o[i])
            if (!it || !it.visible) continue
            lo = Math.min(lo, it.x)
            hi = Math.max(hi, it.x + it.width)
        }
        return hi < lo ? { x: 0, w: 0 } : { x: centreSlots.x + lo, w: hi - lo }
    }

    // adapter.state (BlueZ's PowerState signals), not `enabled`, which
    // Quickshell sets optimistically and never reverts
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

    // One icon per app on the focused workspace (or per workspace, ruled
    // off, under windowScope "all"), each listing its windows, popouts
    // included; the icon's own window is the first that isn't a popout.
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
            var apps = {}
            var first = true
            for (var j = 0; j < tls.length; j++) {
                var ipc = tls[j].lastIpcObject
                var cls = ipc ? ipc.class : ""
                if (!cls || Apps.isBackTabToplevel(tls[j])) continue
                var tags = windowTags(ipc)
                var win = {
                    source: Apps.iconForClass(cls),
                    // drawn instead when nothing resolved, so a
                    // window is never silently missing from the strip
                    glyph: Apps.glyphForWindow(cls, ipc.title),
                    // for the index style, which names the app
                    name: Apps.nameForWindow(cls, ipc.title),
                    address: tls[j].address,
                    // live, for the title styles; read in the
                    // delegate so a title change doesn't rebuild the strip
                    toplevel: tls[j],
                    popout: isPopout(tags),
                    // the window a popout came from, and whether one of
                    // its popouts is blocking it (windows.lua's tags)
                    from: tagSuffix(tags, "from_0x"),
                    blocked: tags.indexOf("blocked") >= 0,
                }
                var app = apps[cls]
                if (!app) {
                    app = apps[cls] = {
                        key: wss[i].id + "/" + cls,
                        source: win.source, glyph: win.glyph, name: win.name,
                        address: win.address, toplevel: win.toplevel,
                        main: !win.popout,
                        windows: [],
                        groupStart: first && icons.length > 0,
                    }
                    icons.push(app)
                    first = false
                } else if (!app.main && !win.popout) {
                    app.glyph = win.glyph
                    app.name = win.name
                    app.address = win.address
                    app.toplevel = win.toplevel
                    app.main = true
                }
                app.windows.push(win)
            }
        }
        // the app's own windows ahead of its popouts
        for (var k = 0; k < icons.length; k++)
            icons[k].windows.sort((x, y) => (x.popout ? 1 : 0) - (y.popout ? 1 : 0))
        return icons
    }

    // The app icon whose windows AppWindowsFlyout lists: its key.
    property string appWindowsKey: ""
    // the window in it whose actions are open, "" for none
    property string appWindowsOpen: ""

    // windows.lua's tags on a window. Rule-set tags carry a trailing "*".
    function windowTags(ipc) {
        var tags = ipc && ipc.tags ? ipc.tags : []
        return tags.map(t => String(t).replace(/\*$/, ""))
    }
    // the rest of the first of `tags` starting with `prefix`, or ""
    function tagSuffix(tags, prefix) {
        for (var i = 0; i < tags.length; i++)
            if (tags[i].startsWith(prefix)) return tags[i].slice(prefix.length)
        return ""
    }

    // a popout per windows.lua's tags, or an app rule's held side
    function isPopout(tags) {
        return tags.indexOf("popout") >= 0 || tags.indexOf("app-held") >= 0
    }

    // the open window of a tray item, so its click raises it; ids and
    // titles are reduced to lowercase letters and digits and matched either way
    function trayItemWindow(item) {
        function norm(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "") }
        var keys = [norm(item.id), norm(item.title)].filter(function(k) { return k.length >= 3 })
        if (keys.length === 0) return null
        var tls = Hyprland.toplevels.values
        for (var pass = 0; pass < 2; pass++) {
            for (var i = 0; i < tls.length; i++) {
                var ipc = tls[i].lastIpcObject
                if (!ipc || Apps.isShellWindow(tls[i])) continue
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

    // the workspace indicator's apps style: an app on workspace `id` as
    // { source, glyph }, or null
    function workspaceApp(id) {
        var entryCount = DesktopEntries.applications.values.length
        var wss = Hyprland.workspaces.values
        for (var i = 0; i < wss.length; i++) {
            if (wss[i].id !== id) continue
            var tls = wss[i].toplevels.values
            for (var j = 0; j < tls.length; j++) {
                var ipc = tls[j].lastIpcObject
                if (!ipc || !ipc.class || Apps.isShellWindow(tls[j])) continue
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
                if (!Apps.isShellWindow(tls[j])) return true
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
                if (Apps.isShellWindow(tls[j]) || Apps.isBackTabToplevel(tls[j])) continue
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
    // laid out by hand, not a Row, so the saved order applies: each module's
    // x is the width of the visible ones before it

    // The bar's 19 modules, in BarModules.qml -- split out since
    // each module's own logic buried the layout plumbing below.
    BarModules {
        id: barModules
        bar: bar
        screenScope: bar.screenScope
        shellRoot: bar.shellRoot
        trayMenu: bar.trayMenu
    }

    function widgetItem(key) { return barModules.widgetItems[key] }

    // --- editing on the bar ----------------------------------
    // Edit mode is the edit shelf (BarEditFlyout) open on this screen;
    // BarEditor takes the bar's input meanwhile.

    readonly property bool editing: screenScope.openFlyout === "baredit"
    readonly property var editor: barEditor
    readonly property var widgetKeys: Object.keys(barModules.widgetItems)

    // What holds a module's slot: the module, or while editing, a stand-in
    // for one that's on but has nothing to show (an empty tray, no
    // updates), so it can still be moved.
    function slotItem(key) {
        const it = widgetItem(key)
        if (!editing || !it || it.visible || !Settings.widgetVisible(key)) return it
        return standIns.objectAt(widgetKeys.indexOf(key))
    }

    // an Instantiator, not a Repeater, so each keeps its own parent binding
    Instantiator {
        id: standIns
        model: bar.widgetKeys

        Item {
            id: standIn
            required property string modelData
            readonly property Item module: bar.widgetItem(modelData)
            parent: bar.slotsFor(Settings.widgetSection(modelData))
            visible: bar.editing && !!module && !module.visible && Settings.widgetVisible(modelData)
            width: Theme.moduleHeight + Theme.modulePadH * 2
            height: Theme.barHeight

            property bool slideX: false
            Behavior on x {
                enabled: standIn.slideX
                NumberAnimation { duration: Theme.dur(160); easing.type: Theme.ease }
            }

            Text {
                anchors.centerIn: parent
                text: (Settings.widgetMeta[standIn.modelData] || { icon: "" }).icon
                color: Theme.textDisabled
                font.family: Theme.fontIcon
                font.pixelSize: Theme.iconSize
            }
        }
    }

    // every module in its saved section's slot container, at its order's x
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
        }
        placeSlots()
    }

    // Every module's x, and the visible modules of its section in order. A
    // module slides only when that order changes (Bar Widgets moving or
    // hiding one): a neighbour changing width, like the tray gaining an
    // icon, moves it at once, as a slide would trail the section's edge.
    readonly property var slotPlaces: {
        const out = {}
        for (const key in barModules.widgetItems) {
            const section = Settings.widgetSection(key)
            const slots = slotsFor(section)
            const shown = slots.order.filter(k => {
                const it = slots.itemFor(k)
                return it && it.visible
            })
            out[key] = { x: slotX(slots, key), order: section + ":" + shown.join(",") }
        }
        return out
    }
    property var placedOrders: ({})
    onSlotPlacesChanged: placeSlots()
    function placeSlots() {
        const places = slotPlaces
        const orders = {}
        for (const key in places) {
            const slide = slotsAnimate && placedOrders[key] !== places[key].order
            for (const it of [barModules.widgetItems[key], standIns.objectAt(widgetKeys.indexOf(key))]) {
                if (!it) continue
                it.slideX = slide
                it.x = places[key].x
            }
            orders[key] = places[key].order
        }
        placedOrders = orders
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

    // Centre positions: the pinned module dead centre and the rest outward
    // from it, else the group centred. Rounded, or borders blur.
    function centreX(key) {
        var o = centreSlots.order
        var gap = Theme.moduleSpacing
        var ai = o.indexOf(Settings.centreAnchor)
        var anchorItem = ai >= 0 ? slotItem(o[ai]) : null
        var ki = o.indexOf(key)
        var x = 0, i, it

        if (!anchorItem || !anchorItem.visible) {
            x = (centreSlots.width - slotsWidth(centreSlots)) / 2
            for (i = 0; i < ki; i++) {
                it = slotItem(o[i])
                if (it && it.visible) x += it.width + gap
            }
            return Math.round(x)
        }

        var ax = (centreSlots.width - anchorItem.width) / 2
        if (ki === ai) return Math.round(ax)
        if (ki > ai) {
            x = ax + anchorItem.width + gap
            for (i = ai + 1; i < ki; i++) {
                it = slotItem(o[i])
                if (it && it.visible) x += it.width + gap
            }
            return Math.round(x)
        }
        // left of the anchor: step back over each module down to and
        // including this one, landing on its left edge
        x = ax
        for (i = ai - 1; i >= ki; i--) {
            it = slotItem(o[i])
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

    // off at startup, where every module would sweep in from x=0 as
    // widths settle
    property bool slotsAnimate: false
    Timer {
        interval: 800
        running: true
        onTriggered: bar.slotsAnimate = true
    }

    // hairline on the bar's inner edge, so it reads as a surface
    // rather than a strip of background
    Rectangle {
        visible: Theme.barFull
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
        function itemFor(k) { return bar.slotItem(k) }

        ModuleSeparators { slots: leftSlots }
    }

    // --- centre -----------------------------------------------
    // spans the bar, so its middle is half its width; takes no input
    Item {
        id: centreSlots
        anchors.fill: barBody

        readonly property var order: Settings.widgetOrder("centre")
        function itemFor(k) { return bar.slotItem(k) }

        ModuleSeparators { slots: centreSlots }
    }

    // --- right: system modules --------------------------------
    Item {
        id: rightSlots
        anchors.right: barBody.right
        anchors.rightMargin: Theme.moduleGap + Theme.barInset
        anchors.top: barBody.top
        anchors.bottom: barBody.bottom

        width: bar.slotsWidth(rightSlots)

        readonly property var order: Settings.widgetOrder("right")
        function itemFor(k) { return bar.slotItem(k) }

        ModuleSeparators { slots: rightSlots }
    }

    // the pinned modules' hitboxes run on to the screen edges (full width
    // only), so the corners click
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

    // over the modules, so its presses come first
    BarEditor {
        id: barEditor
        bar: bar
        body: barBody
    }

    // Keep Awake, via the idle-inhibit protocol; it holds only while its
    // window is mapped, hence the bar
    IdleInhibitor {
        window: bar
        enabled: bar.shellRoot.keepAwake
    }
}
