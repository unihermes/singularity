// Neutrino - Quickshell
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
//   - brightness shells out to brightnessctl (there is no backlight service)
//   - network shells out to iwctl. Quickshell.Networking's only backend is
//     NetworkManager, and this machine runs iwd instead -- with NM absent
//     the module loads but reports "could not find an available backend",
//     so nothing would ever populate.
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
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
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
    System { id: system }
    Keybinds { id: keybinds }
    SettingsWindow { id: settingsWindow }

    AppearanceSync {}

    // Pipewire nodes are unbound by default: audio.volume / audio.muted stay
    // invalid until the node is tracked, so the sink has to be listed here
    // for the volume module to read or write anything at all.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

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

            // Settings' Appearance entry opens this screen's Control Centre
            // on that page -- only on the focused screen, since every
            // screen's scope hears the one window's signal.
            Connections {
                target: settingsWindow
                function onAppearanceRequested() {
                    if (!Hyprland.focusedMonitor || Hyprland.focusedMonitor.name !== screenScope.modelData.name) return
                    screenScope.flyoutAnchorX = barModules.ccBtn.mapToItem(null, barModules.ccBtn.width / 2, 0).x
                    screenScope.openFlyout = "controlcentre"
                    controlCentre.page = "appearance"
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
            implicitHeight: Theme.barHeight
            // Transparent, with the ground drawn by the Rectangle below. A
            // Wayland surface decides whether it has an alpha channel when
            // it's created, so a window that starts opaque stays opaque --
            // assigning a translucent colour to it later does nothing. A
            // window that starts transparent can show any opacity after.
            color: "transparent"

            // Bar Opacity. Only the ground fades: the chips and their text
            // stay solid so the bar is still readable over a busy wallpaper.
            Rectangle {
                anchors.fill: parent
                color: Theme.bar
                opacity: Theme.barOpacity
            }

            readonly property PwNode sink: Pipewire.defaultAudioSink

            // UPower's DisplayDevice is a synthetic aggregate: it reports a
            // percentage but not necessarily powerSupply, so isLaptopBattery
            // is false on it and it can't be used to decide whether this
            // machine even has a battery. Prefer the real one, fall back to
            // the aggregate.
            readonly property UPowerDevice batt: {
                var ds = UPower.devices ? UPower.devices.values : []
                for (var i = 0; i < ds.length; i++) {
                    if (ds[i].isLaptopBattery) return ds[i]
                }
                return UPower.displayDevice
            }
            readonly property bool hasBattery: batt && batt.ready && batt.isPresent

            function batteryPercent() {
                return batt && batt.ready ? Math.round(batt.percentage * 100) : 0
            }

            property int brightness: 0
            property int tick: 0

            function volumePercent() {
                if (!sink || !sink.ready || !sink.audio) return 0
                return Math.round(sink.audio.volume * 100)
            }

            function volumeMuted() {
                return sink && sink.ready && sink.audio ? sink.audio.muted : false
            }

            // Bound (":"), not assigned once, so these track sink.audio.volume
            // / .muted live -- LevelToast watches their onChanged to catch a
            // volume move from anywhere (hardware keys, the flyout slider,
            // scroll-on-chip) without each of those call sites having to say
            // so itself.
            readonly property int volumeLevel: volumePercent()
            readonly property bool volumeIsMuted: volumeMuted()

            function setVolume(pct) {
                if (!sink || !sink.ready || !sink.audio) return
                sink.audio.volume = Math.max(0, Math.min(1, pct / 100))
            }

            // A drag or a fast scroll can call this dozens of times a
            // second. Spawning a brightnessctl process on every single one
            // used to be what made both jumpy: forking that often is real
            // overhead on its own, and with several of those processes
            // in flight at once there's no guarantee they finish writing
            // to sysfs in the order they were launched -- so the watched
            // brightnessFile below could echo back an *older* call's value
            // after a newer one, snapping the bar backwards mid-drag.
            // brightnessWriteDebounce coalesces the actual writes to one
            // in flight at a time; brightnessEcho tells brightnessFile's
            // reload to trust this optimistic value over a stale echo
            // while an adjustment is still active.
            property int pendingBrightnessWrite: -1
            property bool brightnessEcho: false

            function setBrightness(pct) {
                // clamped at 1, not 0: brightnessctl will happily set a
                // laptop panel to fully black and leave you guessing
                var v = Math.max(1, Math.min(100, Math.round(pct)))
                brightness = v
                brightnessEcho = true
                brightnessEchoGuard.restart()
                pendingBrightnessWrite = v
                brightnessWriteDebounce.restart()
            }

            Timer {
                id: brightnessWriteDebounce
                interval: 35
                onTriggered: {
                    if (bar.pendingBrightnessWrite < 0) return
                    Quickshell.execDetached(["brightnessctl", "set", bar.pendingBrightnessWrite + "%"])
                    bar.pendingBrightnessWrite = -1
                }
            }

            // Cleared a little after the last setBrightness call, not right
            // after the debounced write fires -- the write is detached, so
            // there's no signal for when it (and its resulting file event)
            // has actually landed.
            Timer {
                id: brightnessEchoGuard
                interval: 350
                onTriggered: bar.brightnessEcho = false
            }

            function batteryIcon() {
                if (!hasBattery) return "󰁹"
                if (!UPower.onBattery) return "󰂄"
                var p = batteryPercent()
                if (p >= 90) return "󰁹"
                if (p >= 55) return "󰂀"
                if (p >= 25) return "󰁽"
                return "󰁺"
            }

            // iwd state, refreshed by the Processes at the bottom
            property string netDevice: ""
            property string netSsid: ""
            // iwd's Powered flag for the radio. Read from `device list`, not
            // `station show`: a powered-off device has no station at all
            // ("No station on device"), but still appears in the list.
            property bool netPowered: true

            function setWifiPowered(on) {
                if (netDevice === "") return
                netPowered = on    // optimistic; netPowerProc settles it
                if (!on) netSsid = ""
                netPowerSet.command = ["iwctl", "device", netDevice,
                    "set-property", "Powered", on ? "on" : "off"]
                netPowerSet.running = true
            }

            // scan on open rather than on a timer: the radio should not
            // sweep while nobody is looking at it
            function scanNetworks() { netScan.running = true }

            function connectNetwork(cmd) {
                netConnect.command = cmd
                netConnect.running = true
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
            // [{ connected, ssid, security, bars, known }]
            property var netList: []

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
                for (const key in barModules.widgetItems) {
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

            // hairline under the bar, so it reads as a surface rather than a
            // strip of background
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
            }

            // --- left: workspaces -------------------------------------
            Item {
                id: leftSlots
                anchors.left: parent.left
                anchors.leftMargin: Theme.moduleGap
                anchors.top: parent.top
                anchors.bottom: parent.bottom
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
                anchors.fill: parent

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
                anchors.right: parent.right
                anchors.rightMargin: Theme.moduleGap
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: bar.slotsWidth(rightSlots)

                readonly property var order: Settings.widgetOrder("right")
                function itemFor(k) { return bar.widgetItem(k) }
            }

            // --- data -------------------------------------------------
            // Brightness is read straight from sysfs and *watched*, not
            // polled: the backlight attribute emits change notifications, so
            // the readout follows the XF86MonBrightness keys (and anything
            // else that writes to it) the same way the Pipewire-backed volume
            // readout follows external volume changes. brightnessctl is still
            // used to write, since sysfs isn't user-writable.
            property string backlightDir: ""
            property int brightnessMax: 0

            Process {
                id: backlightFind
                command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: bar.backlightDir = text.trim().replace(/\/$/, "")
                }
            }

            FileView {
                id: brightnessMaxFile
                path: bar.backlightDir !== "" ? bar.backlightDir + "/max_brightness" : ""
                onLoaded: {
                    var v = parseInt(text().trim())
                    if (!isNaN(v) && v > 0) {
                        bar.brightnessMax = v
                        brightnessFile.reload()
                    }
                }
            }

            FileView {
                id: brightnessFile
                path: bar.backlightDir !== "" ? bar.backlightDir + "/brightness" : ""
                watchChanges: true
                onFileChanged: reload()
                onLoaded: {
                    // Ignore echoes of our own writes while an adjustment is
                    // active -- see brightnessEcho above for why trusting
                    // every one of these here is what made dragging jumpy.
                    if (bar.brightnessEcho) return
                    var raw = parseInt(text().trim())
                    if (!isNaN(raw) && bar.brightnessMax > 0)
                        bar.brightness = Math.round(raw / bar.brightnessMax * 100)
                }
            }

            // --- iwd ---------------------------------------------
            // iwctl draws tables for humans: ANSI colour, a banner, and
            // fixed-width columns. Everything below strips the escapes and
            // cuts by column offset rather than by whitespace, because SSIDs
            // are allowed to contain spaces and would break field splitting.

            Process {
                id: netDeviceProc
                command: ["sh", "-c",
                    "iwctl device list 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' "
                    + "| awk 'NR>4 && $5==\"station\" {print $1; exit}'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        bar.netDevice = text.trim()
                        if (bar.netDevice !== "") {
                            netStatus.running = true
                            netPowerProc.running = true
                        }
                    }
                }
            }

            Process {
                id: netStatus
                command: ["sh", "-c",
                    "iwctl station " + bar.netDevice + " show 2>/dev/null "
                    + "| sed 's/\\x1b\\[[0-9;]*m//g' "
                    + "| awk -F'  +' '/Connected network/ {print $3}'"]
                stdout: StdioCollector {
                    onStreamFinished: bar.netSsid = text.trim()
                }
            }

            Process {
                id: netScan
                command: ["sh", "-c",
                    "iwctl station " + bar.netDevice + " scan 2>/dev/null; sleep 2"]
                onExited: {
                    netStatus.running = true
                    netListProc.running = true
                }
            }

            Process {
                id: netListProc
                command: ["sh", "-c",
                    "known=$(iwctl known-networks list 2>/dev/null "
                    + "| sed 's/\\x1b\\[[0-9;]*m//g' | awk 'NR>4 {n=substr($0,3,34); "
                    + "gsub(/^ +| +$/,\"\",n); if (n!=\"\") print n}'); "
                    + "iwctl station " + bar.netDevice + " get-networks 2>/dev/null "
                    + "| sed 's/\\x1b\\[[0-9;]*m//g' "
                    + "| awk -v known=\"$known\" 'BEGIN{split(known,k,\"\\n\")} "
                    + "NR>4 && length($0)>10 { "
                    + "marker=substr($0,1,6); name=substr($0,7,34); "
                    + "sec=substr($0,41,20); sig=substr($0,61); "
                    + "gsub(/^ +| +$/,\"\",marker); gsub(/^ +| +$/,\"\",name); "
                    + "gsub(/^ +| +$/,\"\",sec); gsub(/^ +| +$/,\"\",sig); "
                    + "if (name==\"\") next; kn=0; for (i in k) if (k[i]==name) kn=1; "
                    + "printf \"%s|%s|%s|%d|%s\\n\", (marker==\">\"?\"1\":\"0\"), "
                    + "name, sec, length(sig), kn }'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        var out = []
                        var lines = text.split("\n")
                        for (var i = 0; i < lines.length; i++) {
                            var f = lines[i].split("|")
                            if (f.length < 5) continue
                            out.push({
                                connected: f[0] === "1",
                                ssid: f[1],
                                security: f[2],
                                bars: parseInt(f[3]) || 0,
                                known: f[4] === "1"
                            })
                        }
                        bar.netList = out
                    }
                }
            }

            Process {
                id: netPowerProc
                command: ["sh", "-c",
                    "iwctl device list 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' "
                    + "| awk 'NR>4 && $1==\"" + bar.netDevice + "\" {print $3; exit}'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        var v = text.trim()
                        if (v !== "") bar.netPowered = (v === "on")
                    }
                }
            }

            // Powering the radio back on doesn't hand back an SSID at once:
            // iwd reconnects to a known network about a second later. So the
            // status is re-read after a short wait instead of on exit, or the
            // row would say "Not connected" until the next 15s refresh.
            Process {
                id: netPowerSet
                command: ["true"]
                onExited: {
                    netPowerProc.running = true
                    netPowerSettle.restart()
                }
            }

            Timer {
                id: netPowerSettle
                interval: 2500
                onTriggered: netStatus.running = true
            }

            // command is rewritten per click, so it starts out empty
            Process {
                id: netConnect
                command: ["true"]
                onExited: {
                    netStatus.running = true
                    netListProc.running = true
                }
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    barModules.clock.label = Qt.formatDateTime(new Date(), "HH:mm:ss  |  MM/dd/yy")
                    bar.tick++
                    // iwd reports itself active before its interfaces are
                    // registered, so the one-shot probe at startup can come
                    // back empty. The SSID refresh below is gated on having a
                    // device, so without this retry that empty result sticks
                    // for the whole session and the bar insists it is offline
                    // while the machine is plainly online.
                    if (bar.netDevice === "") {
                        if (bar.tick % 5 === 0) netDeviceProc.running = true
                    } else if (bar.tick % 15 === 0) {
                        // the SSID only changes when you move between
                        // networks, so it doesn't need a per-second iwctl call
                        netStatus.running = true
                        netPowerProc.running = true
                    }
                }
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

        // SUPER+W: the workspace grid. Not anchored to the bar like the
        // flyouts, but it shares openFlyout so opening it closes them (and
        // vice versa) without any extra bookkeeping.
        WorkspaceOverlay {
            scope: screenScope
        }

        // SUPER+M: brief top-of-screen toast naming the layout just switched
        // to. Listens for root.layoutModeChanged itself rather than going
        // through openFlyout -- it isn't a flyout (no backdrop, not closable,
        // self-dismissing) and shouldn't close whatever flyout is already open.
        LayoutToast {
            scope: screenScope
        }

        // Volume/brightness OSD. Watches bar.volumeLevel/volumeIsMuted and
        // bar.brightness directly rather than through an IPC relay like the
        // two toasts above -- those two both already push live updates into
        // bar's own properties (Pipewire for volume, a watched sysfs file for
        // brightness), so hardware keys, the flyout sliders and scroll-on-chip
        // all surface here for free with no new signal plumbing.
        LevelToast {
            scope: screenScope
            bar: bar
        }

        // ALT+Tab. Shares openFlyout like everything else, so opening it
        // closes whatever was up.
        AltTabSwitcher {
            id: altTab
            scope: screenScope
        }

        // workspaces / windows
        WorkspacesFlyout { scope: screenScope; bar: bar }

        // calendar
        CalendarFlyout { scope: screenScope }

        // brightness
        BrightnessFlyout { scope: screenScope; bar: bar; shellRoot: root }

        // volume
        VolumeFlyout { scope: screenScope; bar: bar }

        // network (iwd)
        NetworkFlyout { id: netFlyout; scope: screenScope; bar: bar }

        // bluetooth
        BluetoothFlyout { id: btFlyout; scope: screenScope; bar: bar }

        // battery
        BatteryFlyout { id: batteryFlyout; scope: screenScope; bar: bar }

        // tray menu: the app's own menu, drawn as flyout rows so it matches
        // everything else rather than popping a native Qt menu. Submenus
        // drill down in place, like the control centre.
        TrayMenuFlyout { id: trayMenu; scope: screenScope }

        // media
        MediaFlyout { id: mediaFlyout; scope: screenScope }

        // weather
        WeatherFlyout { id: weatherFlyout; scope: screenScope }

        // privacy
        PrivacyFlyout { scope: screenScope }

        // failed units
        FailedFlyout { scope: screenScope }

        // updates
        UpdatesFlyout { scope: screenScope }

        // control centre
        ControlCentre {
            id: controlCentre
            scope: screenScope
            bar: bar
            shellRoot: root
            settingsWin: settingsWindow
            systemWin: system
            keybindsWin: keybinds
        }

        }
    }
}
