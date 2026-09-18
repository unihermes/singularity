// Singularity - Quickshell
// ~/.config/quickshell/shell.qml
//
// Status bar: workspaces + window icons on the left, clock in the middle,
// system modules on the right. Same grayscale ramp as the rest of the repo
// -- nothing here is coloured, only lighter or darker.
//
// Most modules open a flyout (see FlyoutPanel.qml). Only one is ever open:
// `openFlyout` holds its name rather than each module keeping a bool, which
// makes "opening one closes the others" fall out for free and gives the
// backdrop a single thing to clear.
//
// System state comes from Quickshell's own service modules (Pipewire,
// UPower, Bluetooth) rather than by polling wpctl/upower/bluetoothctl: they
// are DBus-backed and push changes, so the bar updates the moment something
// changes instead of up to a poll interval later.
//
// Two exceptions, both because no service exists to use:
//   - brightness shells out to brightnessctl (services/Brightness.qml;
//     there is no backlight service)
//   - network shells out to iwctl and busctl (services/Network.qml).
//     Quickshell.Networking's only backend is NetworkManager, and this
//     machine runs iwd instead -- with NM absent the module loads but
//     reports "could not find an available backend", so nothing would ever
//     populate.
//
// Quickshell's QML API moves quickly. If the bar does not appear, run
// `quickshell` from a terminal inside the session: QML errors go to stderr
// with a file and line number, and they are usually a renamed import.

import "services"
import "flyouts"
import "bar"
import "windows"
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import QtQuick

ShellRoot {
    id: root

    // Keep Awake, from Quick Actions. Held here rather than on a bar because
    // every screen gets its own bar, and a per-screen flag would let one
    // monitor's menu say "on" while another's says "off". Session-only on
    // purpose: waking up tomorrow with idle still inhibited is the failure
    // mode worth avoiding.
    property bool keepAwake: false

    // Night Light, from Quick Actions. hyprsunset holds the warm gamma ramp
    // for as long as it runs, and the compositor restores normal gamma the
    // moment its client disconnects -- so stopping the process *is* turning
    // it off, no second "reset" command needed. Session-only, like Keep
    // Awake, and on the root for the same one-state-for-all-screens reason.
    property bool nightLight: false
    readonly property int nightLightKelvin: Settings.nightLightKelvin
    // Retune a running hyprsunset in place. Restarting it instead would
    // drop the gamma ramp for a frame and flash the screen cold on every
    // step of the stepper.
    onNightLightKelvinChanged: if (nightLightProc.running)
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(nightLightKelvin)])
    // false until the probe below finds the binary; the toggle says so
    // instead of flipping on and silently doing nothing
    property bool hasHyprsunset: false

    // Also clears out any hyprsunset left behind by a previous shell. It is
    // a child process but outlives Quickshell being killed or crashing, and
    // an orphan keeps the screen warm while this fresh instance's toggle
    // insists Night Light is off -- with nothing in the UI able to stop it.
    Process {
        running: true
        command: ["sh", "-c", "pkill -x hyprsunset; command -v hyprsunset"]
        onExited: code => root.hasHyprsunset = (code === 0)
    }

    Process {
        id: nightLightProc
        command: ["hyprsunset", "-t", String(root.nightLightKelvin)]
        running: root.nightLight && root.hasHyprsunset
        // An exit while the toggle still says on is a crash or a refused
        // gamma handle, not a user action -- drop the toggle back so it
        // doesn't claim a warm screen that isn't there.
        onExited: if (root.nightLight) root.nightLight = false
    }

    // Standalone windows opened from the Control Centre. One each for the
    // whole session, not per screen: they're ordinary toplevels, and
    // Hyprland maps them on whichever monitor has focus.
    // built on first open, see LazyWindow.qml
    LazyWindow { id: system; System {} }
    LazyWindow { id: keybinds; Keybinds {} }
    LazyWindow { id: settingsWindow; SettingsWindow {} }

    // `qs ipc call settings open appearance`, for a keybind or a script;
    // an unknown or empty page opens the default one
    IpcHandler {
        target: "settings"
        function open(page: string): void { settingsWindow.open(page) }
    }

    // `qs ipc call look cycle` / `qs ipc call look set soft` -- for a keybind
    // that steps through the looks without opening anything
    IpcHandler {
        target: "look"
        function cycle(): void { Settings.cycle("look") }
        function set(name: string): void { Settings.set("look", name) }
        function get(): string { return Settings.look }
        // the appearance's saved default (Settings.saveAsDefault)
        function saveDefault(): void { Settings.saveAsDefault() }
        function resetToDefault(): void { Settings.reset() }
        function isDefault(): bool { return Settings.isDefault }
        // deletes the look from looks.json; the fallback look can't be removed
        function remove(name: string): void { Settings.removeLook(name) }

    }

    AppearanceSync {}

    // SUPER+W, arriving from hyprland.lua via `qs ipc call overlay toggle`.
    // A signal rather than a direct call because the overlays live inside
    // Variants (one per screen) and aren't addressable from out here; each
    // screen's scope listens and only the focused monitor's acts.
    signal workspaceOverlayToggled()

    IpcHandler {
        target: "overlay"
        function toggle(): void { root.workspaceOverlayToggled() }
    }

    // SUPER+M, arriving from hyprland.lua via `qs ipc call layout <mode>`
    // right after it flips monocleEnabled. Same per-screen signal relay as
    // the overlay above: only the focused monitor shows the toast.
    signal layoutModeChanged(string mode)

    IpcHandler {
        target: "layout"
        function set(mode: string): void { root.layoutModeChanged(mode) }
    }

    // The ALT+Tab switcher. hyprland.lua binds ALT+Tab globally and that bind
    // wins over the switcher's own keyboard grab -- Hyprland matches binds
    // before forwarding keys to any client, layershell included -- so every
    // Tab of a held ALT+Tab re-runs alt-tab.sh rather than reaching
    // Keys.onPressed. tab() is therefore idempotent: it opens the switcher
    // the first time and steps it on each Tab after, which is what makes
    // holding ALT and tapping Tab cycle. commit() when ALT comes up.
    // Same per-screen signal relay as the overlay above.
    signal altTabTab(string clientsJson)
    signal altTabStep(int delta)
    signal altTabCommit()
    signal altTabCancel()

    IpcHandler {
        target: "alttab"
        // `clientsJson`: the raw, unparsed output of `hyprctl clients -j`,
        // from alt-tab.sh. See AltTabSwitcher.begin() for why it comes from
        // there, and why it's handed over raw instead of pre-filtered.
        //
        // One function, always fetching and forwarding the client list,
        // rather than a cheap "step if already open" probe tried first and a
        // separate begin() as a fallback (which this used to be). Splitting
        // it that way meant the *first* Tab of a gesture -- the one whose
        // timing actually matters, since it is the only one racing a fast
        // ALT release against the switcher's keyboard grab -- paid for two
        // separate `qs ipc call` processes back to back. Each one is a good
        // ~45ms of Qt/dynamic-linker startup on its own; two of them plus
        // `hyprctl` came to roughly 100ms of pure process-spawn overhead
        // before the switcher could possibly hold the keyboard, which is
        // easily longer than a fast tap-and-release takes start to finish.
        // One call instead of two roughly halves that, at the cost of also
        // running `hyprctl` (a few ms) on repeat taps where its answer ends
        // up unused -- a fair trade, since repeat taps were never the ones
        // losing the race.
        function tab(clientsJson: string): void { root.altTabTab(clientsJson) }
        function prev(): void { root.altTabStep(-1) }
        function commit(): void { root.altTabCommit() }
        function cancel(): void { root.altTabCancel() }
        // alttab-relay's startup self-test: the one call here with a reply,
        // so the relay can tell its hand-built wire format still matches
        // this Quickshell's (see alttab-relay.cpp)
        function ping(): string { return "singularity-relay-pong" }
    }

    // A new/closed/moved window's class (and so its icon) doesn't show up
    // in Hyprland.toplevels until something re-requests the full client
    // list -- it isn't pushed with the openwindow event itself. Force that
    // refetch right when it happens instead of waiting for the next
    // incidental one (e.g. a workspace switch), which is what made new
    // app icons take a while to appear.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow"
                || event.name === "activewindow") {
                // activewindow keeps focusHistoryID current, which is the order
                // the ALT+Tab switcher walks. Without it the switcher sorts on
                // whatever the history was at the last open/close and lands on
                // the wrong window.
                Hyprland.refreshToplevels()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property var modelData

            // name of the open flyout, "" for none
            property string openFlyout: ""

            // The bar, for the lazily built flyouts. `bar: bar` inside a
            // LazyFlyout would bind the flyout's own `bar` property to
            // itself: in a nested component the object's own properties are
            // looked up before the outer file's ids.
            readonly property var barWindow: bar

            // screen-local x the open flyout centres itself under
            property real flyoutAnchorX: 0

            // `item` is the module that was clicked; mapToItem(null, ...)
            // gives its position in its own window's coordinates, and the
            // bar and the flyouts all span the full screen width, so that
            // x is directly usable as the flyout's anchor.
            // Whether this screen is the one with keyboard focus. Anything
            // opened from a global keybind uses it so only one screen reacts.
            function isFocusedScreen() {
                return !!Hyprland.focusedMonitor
                    && Hyprland.focusedMonitor.name === screenScope.modelData.name
            }

            function toggleFlyout(name, item) {
                if (screenScope.openFlyout === name) {
                    screenScope.openFlyout = ""
                    return
                }
                screenScope.flyoutAnchorX = item.mapToItem(null, item.width / 2, 0).x
                screenScope.openFlyout = name
            }

            // SUPER+W toggles the workspace grid on the focused monitor only.
            // It has no bar module to anchor to (it centres itself), so unlike
            // toggleFlyout there's no anchor to set here.
            Connections {
                target: root
                function onWorkspaceOverlayToggled() {
                    if (!screenScope.isFocusedScreen()) return
                    screenScope.openFlyout =
                        screenScope.openFlyout === "workspaceoverlay" ? "" : "workspaceoverlay"
                }
            }

            // SUPER+M: the layout toast. Not routed through openFlyout like
            // the rest -- it isn't a flyout (no backdrop, self-dismissing,
            // and it shouldn't close whatever flyout is already open) -- so
            // it gets its own bit of state: the mode to show, and a counter
            // LayoutToast watches to know a *new* toggle happened even when
            // the mode repeats (e.g. two quick SUPER+M's landing back on
            // "monocle" should restart the timer, not no-op).
            property string layoutToastMode: ""
            property int layoutToastSeq: 0

            Connections {
                target: root
                function onLayoutModeChanged(mode) {
                    if (!screenScope.isFocusedScreen()) return
                    screenScope.layoutToastMode = mode
                    screenScope.layoutToastSeq++
                }
            }

            // ALT+Tab, on the focused monitor only. The first Tab of a
            // gesture opens the switcher and preselects the previous window,
            // so a single tap-and-release is a straight there-and-back swap;
            // every Tab after that just steps it. alt-tab.sh can't tell
            // those two cases apart without asking (there's no state kept
            // between its invocations), so onAltTabTab decides it here,
            // against openFlyout, instead of alt-tab.sh spending a separate
            // IPC round trip on a "is it open yet" probe first -- see the
            // `tab()` comment on the IpcHandler above for why that round trip
            // was worth cutting.
            Connections {
                target: root

                // The focus test is inside each handler rather than on the
                // Connections' `enabled`: that binding is evaluated when the
                // signal arrives, and re-evaluating it mid-dispatch made the
                // whole block miss signals. Same shape as the Settings
                // Connections below. (A Connections can only hold signal
                // handlers, so this is a function on the scope, not a
                // property here.)
                function onAltTabTab(clientsJson) {
                    if (!screenScope.isFocusedScreen()) return
                    if (screenScope.openFlyout === "alttab") {
                        altTab.step(1)
                        return
                    }
                    altTab.begin(clientsJson)
                    // Nothing to switch between: nothing to show.
                    if (altTab.windows.length > 1) screenScope.openFlyout = "alttab"
                }
                function onAltTabStep(delta) {
                    if (screenScope.openFlyout !== "alttab") return
                    altTab.step(delta)
                }
                function onAltTabCommit() {
                    if (screenScope.openFlyout !== "alttab") return
                    altTab.commit()
                }
                function onAltTabCancel() {
                    if (screenScope.openFlyout !== "alttab") return
                    altTab.cancel()
                }
            }

        PanelWindow {
            id: bar
            screen: screenScope.modelData

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
            Rectangle {
                anchors.fill: barBody
                color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
                radius: Theme.barFloating ? Theme.radius : 0
                border.width: Theme.barFloating ? Theme.borderWidth : 0
                border.color: Theme.stroke
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

            // Name of the first connected Bluetooth device, "" for none.
            function btConnectedName() {
                var a = Bluetooth.defaultAdapter
                var ds = (a && a.devices) ? a.devices.values : []
                for (var i = 0; i < ds.length; i++) {
                    if (!ds[i].connected) continue
                    return ds[i].deviceName !== "" ? ds[i].deviceName
                        : (ds[i].name !== "" ? ds[i].name : ds[i].address)
                }
                return ""
            }
            // {source, address} for every window open on the focused
            // workspace, via each window's wmClass -> .desktop entry -> icon.
            // address lets the icon's click handler focus that exact window.
            function focusedWorkspaceIcons() {
                // read this so the binding re-evaluates once the desktop
                // entry scan (async at startup) finishes populating it
                var entryCount = DesktopEntries.applications.values.length
                if (entryCount === 0) return []

                if (!Hyprland.focusedWorkspace) return []
                var wsId = Hyprland.focusedWorkspace.id

                var icons = []
                var wss = Hyprland.workspaces.values
                for (var i = 0; i < wss.length; i++) {
                    if (wss[i].id !== wsId) continue
                    var tls = wss[i].toplevels.values
                    for (var j = 0; j < tls.length; j++) {
                        var cls = tls[j].lastIpcObject ? tls[j].lastIpcObject.class : ""
                        if (!cls || isShellWindow(tls[j])) continue
                        var entry = DesktopEntries.heuristicLookup(cls)
                        var path = entry ? Quickshell.iconPath(entry.icon, true) : ""
                        if (path) icons.push({ source: path, address: tls[j].address })
                    }
                    break
                }
                return icons
            }

            // The shell's own standalone windows (System, Keybinds)
            // are part of the bar, not apps you're running, so they're left
            // out of everything that lists windows: no Quickshell icon in the
            // window strip, no entry in the workspace flyout, and a workspace
            // holding only one of them still reads as empty.
            function isShellWindow(tl) {
                return !!(tl.lastIpcObject && tl.lastIpcObject.class === "org.quickshell")
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
                        if (isShellWindow(tls[j])) continue
                        var ipc = tls[j].lastIpcObject
                        out.push({
                            ws: wss[i].id,
                            title: ipc && ipc.title ? ipc.title : (ipc && ipc.class ? ipc.class : "window"),
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

            // The bar's 18 modules, in BarModules.qml -- split out since
            // each module's own logic buried the layout plumbing below.
            BarModules {
                id: barModules
                bar: bar
                screenScope: screenScope
                trayMenu: trayMenu
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
                    if (it && it.visible) x += it.width + Theme.moduleGap
                }
                return x
            }

            // Centre positions. With a pinned module visible in the centre,
            // it sits dead centre and the rest are measured outward from its
            // edges; otherwise the visible modules are centred as one group.
            // Rounded, since a half-pixel x blurs the chip borders.
            function centreX(key) {
                var o = centreSlots.order
                var gap = Theme.moduleGap
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
                return w + Math.max(0, n - 1) * Theme.moduleGap
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
            // rather than a strip of background
            Rectangle {
                visible: !Theme.barFloating
                y: Theme.barPosition === "bottom" ? 0 : parent.height - height
                width: parent.width
                height: Theme.borderWidth
                color: Theme.stroke
            }


            // --- left: workspaces -------------------------------------
            Item {
                id: leftSlots
                anchors.left: barBody.left
                anchors.leftMargin: Theme.moduleGap + (Theme.barFloating ? Theme.spaceXs : 0)
                anchors.top: barBody.top
                anchors.bottom: barBody.bottom
                width: bar.slotsWidth(leftSlots)

                readonly property var order: Settings.widgetOrder("left")
                function itemFor(k) { return bar.widgetItem(k) }
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
                anchors.rightMargin: Theme.moduleGap + (Theme.barFloating ? Theme.spaceXs : 0)
                anchors.top: barBody.top
                anchors.bottom: barBody.bottom

                width: bar.slotsWidth(rightSlots)

                readonly property var order: Settings.widgetOrder("right")
                function itemFor(k) { return bar.widgetItem(k) }
            }

            // Keep Awake. The Wayland idle-inhibit protocol, rather than
            // `systemd-inhibit`: idle daemons (hypridle and friends) watch
            // this protocol, and it needs no process kept alive. It only
            // holds while its window is mapped, which is why it hangs off the
            // bar -- the one surface that is always up.
            IdleInhibitor {
                window: bar
                enabled: root.keepAwake
            }
        }

        // --- flyouts --------------------------------------------------
        // Each is its own layer-shell surface rather than something drawn
        // inside the bar: a panel clips to its own surface, so a dropdown
        // drawn in the bar would be cut off at the bar's bottom edge.
        //
        // Wrapped in LazyFlyout, which builds each one the first time it
        // opens rather than at login. The toasts and the alt-tab switcher
        // are the exceptions: the toasts react to events while nothing is
        // open, and alt-tab has to be ready for a fast tap.

        // SUPER+W: the workspace grid. Not anchored to the bar like the
        // flyouts, but it shares openFlyout so opening it closes them (and
        // vice versa) without any extra bookkeeping.
        LazyFlyout {
            name: "workspaceoverlay"; scope: screenScope
            WorkspaceOverlay { scope: screenScope }
        }

        // SUPER+M: brief top-of-screen toast naming the layout just switched
        // to. Listens for root.layoutModeChanged itself rather than going
        // through openFlyout -- it isn't a flyout (no backdrop, not closable,
        // self-dismissing) and shouldn't close whatever flyout is already open.
        LayoutToast {
            scope: screenScope
        }

        // Volume/brightness OSD. Watches the Audio and Brightness services
        // directly rather than through an IPC relay like the two toasts
        // above -- both already push live updates (Pipewire for volume, a
        // watched sysfs file for brightness), so hardware keys, the flyout
        // sliders and scroll-on-chip all surface here for free.
        LevelToast {
            scope: screenScope
        }

        // ALT+Tab. Shares openFlyout like everything else, so opening it
        // closes whatever was up.
        AltTabSwitcher {
            id: altTab
            scope: screenScope
        }

        // workspaces / windows
        LazyFlyout { name: "workspaces"; scope: screenScope; WorkspacesFlyout { scope: screenScope; bar: screenScope.barWindow } }

        // calendar
        LazyFlyout { name: "calendar"; scope: screenScope; CalendarFlyout { scope: screenScope } }

        // brightness
        LazyFlyout { name: "brightness"; scope: screenScope; BrightnessFlyout { scope: screenScope; shellRoot: root } }

        // volume
        LazyFlyout { name: "volume"; scope: screenScope; VolumeFlyout { scope: screenScope } }

        // network (iwd)
        LazyFlyout { name: "network"; scope: screenScope; NetworkFlyout { scope: screenScope; bar: screenScope.barWindow } }

        // bluetooth
        LazyFlyout { name: "bluetooth"; scope: screenScope; BluetoothFlyout { scope: screenScope; bar: screenScope.barWindow } }

        // battery
        LazyFlyout { name: "battery"; scope: screenScope; BatteryFlyout { scope: screenScope } }

        // tray menu: the app's own menu, drawn as flyout rows so it matches
        // everything else rather than popping a native Qt menu. Submenus
        // drill down in place, like the control centre.
        LazyFlyout {
            id: trayMenu
            name: "traymenu"; scope: screenScope
            TrayMenuFlyout { scope: screenScope }
        }

        // media
        LazyFlyout { name: "media"; scope: screenScope; MediaFlyout { scope: screenScope } }

        // weather
        LazyFlyout { name: "weather"; scope: screenScope; WeatherFlyout { scope: screenScope } }

        // privacy
        LazyFlyout { name: "privacy"; scope: screenScope; PrivacyFlyout { scope: screenScope } }

        // failed units
        LazyFlyout { name: "failed"; scope: screenScope; FailedFlyout { scope: screenScope } }

        // updates
        LazyFlyout { name: "updates"; scope: screenScope; UpdatesFlyout { scope: screenScope } }

        // control centre
        LazyFlyout {
            name: "controlcentre"; scope: screenScope
            ControlCentre {
                scope: screenScope
                bar: screenScope.barWindow
                shellRoot: root
                settingsWin: settingsWindow
                systemWin: system
                keybindsWin: keybinds
            }
        }

        }
    }
}
