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
    LazyWindow { id: settingsWindow; SettingsWindow {} }
    LazyWindow { id: notesWindow; NotesWindow {} }

    // `qs ipc call settings open appearance`, for a keybind or a script;
    // an unknown or empty page opens the default one
    IpcHandler {
        target: "settings"
        function open(page: string): void { settingsWindow.open(page) }
    }

    // `qs ipc call system open`, likewise.
    // System takes a page the way Settings does -- `... open network` -- so a
    // keybind can go straight to the one page it is about.
    IpcHandler {
        target: "system"
        function open(page: string): void { system.open(page) }
    }

    // `qs ipc call notes toggle`, from SUPER+N
    IpcHandler {
        target: "notes"
        function toggle(): void {
            if (notesWindow.item && notesWindow.item.visible) notesWindow.item.close()
            else notesWindow.open()
        }
    }

    IpcHandler {
        target: "keybinds"
        function open(): void { settingsWindow.open("keybinds") }
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

    // Caps Lock / Num Lock, from hyprland.lua's pass-through binds on the two
    // keys: `qs ipc call locks changed caps|num`. Each call flips the shell's
    // own copy of the state and toasts it straight away, rather than reading
    // it: the bind fires on press, and xkb only turns a lock off when the key
    // comes up, so the keyboard still reads on at that point. Flipping also
    // lets toggles quicker than a round trip to Hyprland each show. The main
    // keyboard's real state is read back at startup and shortly after the
    // last toggle; if the copy has drifted (a missed call, another keyboard)
    // it's corrected, and the toast with it.
    signal lockKeyChanged(string key, bool on)

    property var lockState: ({ caps: false, num: false })

    IpcHandler {
        target: "locks"
        function changed(key: string): void {
            if (key !== "caps" && key !== "num") return
            root.lockState[key] = !root.lockState[key]
            root.lockKeyChanged(key, root.lockState[key])
            lockResync.restart()
        }
    }

    Timer {
        id: lockResync
        // long enough that the key is up again, or a lock being switched
        // off would still read as on
        interval: 1000
        onTriggered: lockProbe.running = true
    }

    Process {
        id: lockProbe
        property bool primed: false
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kbs
                try { kbs = JSON.parse(text).keyboards || [] } catch (e) { return }
                const kb = kbs.find(k => k.main) || kbs[0]
                if (!kb) return
                const real = { caps: kb.capsLock, num: kb.numLock }
                for (const key of ["caps", "num"]) {
                    if (real[key] === root.lockState[key]) continue
                    root.lockState[key] = real[key]
                    if (lockProbe.primed) root.lockKeyChanged(key, real[key])
                }
                lockProbe.primed = true
            }
        }
    }

    // The lid, from lid.sh once a close or open has survived its debounce:
    // `qs ipc call lid changed closed|open`. Toasted like the lock keys.
    signal lidChanged(bool closed)

    IpcHandler {
        target: "lid"
        function changed(state: string): void {
            if (state !== "closed" && state !== "open") return
            root.lidChanged(state === "closed")
        }
    }

    // The launcher (flyouts/Launcher.qml): `qs ipc call launcher toggle apps`
    // from CTRL+SPACE, `... toggle clipboard` from SUPER+H. Same per-screen
    // signal relay as the overlay above.
    signal launcherToggled(string mode)

    IpcHandler {
        target: "launcher"
        function toggle(mode: string): void { root.launcherToggled(mode) }
    }

    // Claude (flyouts/ClaudeFlyout.qml): `qs ipc call claude toggle` from
    // SUPER+I. Same per-screen signal relay as the overlay above.
    signal claudeToggled()

    IpcHandler {
        target: "claude"
        function toggle(): void { root.claudeToggled() }
    }

    // Notifications: the history flyout, Do Not Disturb, Clear all
    IpcHandler {
        target: "notifications"
        function toggle(): void { Notifications.togglePanel() }
        function dnd(): void { Notifications.toggleDnd() }
        function clear(): void { Notifications.clearAll() }
    }

    // The ALT+Tab switcher. The bind wins over the switcher's keyboard grab,
    // so every Tab of a held ALT+Tab re-runs alttab-ipc.sh: tab() opens the
    // switcher on the first and steps it on the rest. commit() when ALT comes
    // up. Same per-screen signal relay as the overlay above.
    //
    // `gen` is the gesture id minted by the bind (hyprland.lua's
    // altTabWatchGen): each command carries its Tab's id, and the ALT release
    // the id of the gesture's last Tab, so a release that arrives before its
    // switcher exists is applied to that switcher and no other. tab()'s id
    // rides inside the JSON, since a call carries one argument.
    signal altTabTab(string clientsJson)
    signal altTabStep(int delta, string gen)
    signal altTabCommit(string gen)
    signal altTabCancel()

    IpcHandler {
        target: "alttab"
        // `clientsJson`: the gesture id and the raw client list (what
        // `hyprctl clients -j` prints), from alttab-relay; see
        // AltTabSwitcher.begin(). One call that always carries the list,
        // rather than an "is it open yet" probe first: the first Tab is the
        // one racing a fast ALT release, and can't afford two round trips.
        function tab(clientsJson: string): void { root.altTabTab(clientsJson) }
        function prev(gen: string): void { root.altTabStep(-1, gen) }
        function commit(gen: string): void { root.altTabCommit(gen) }
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

            // SUPER+M, the lock keys and the lid: the mode toast. Not routed through
            // openFlyout like the rest -- it isn't a flyout (no backdrop,
            // self-dismissing, and it shouldn't close whatever flyout is
            // already open) -- so it gets its own bit of state: what to show,
            // and a counter ModeToast watches to know a *new* toggle happened
            // even when the text repeats (e.g. two quick SUPER+M's landing
            // back on "monocle" should restart the timer, not no-op).
            property string modeToastIcon: ""
            property string modeToastText: ""
            property int modeToastSeq: 0

            function showModeToast(icon, text) {
                if (!screenScope.isFocusedScreen()) return
                screenScope.modeToastIcon = icon
                screenScope.modeToastText = text
                screenScope.modeToastSeq++
            }

            Connections {
                target: root
                function onLayoutModeChanged(mode) {
                    var monocle = mode === "monocle"
                    screenScope.showModeToast(monocle ? "󰊓" : "󰕴", monocle ? "MONOCLE" : "DWINDLE")
                }
                function onLidChanged(closed) {
                    screenScope.showModeToast(closed ? "󰛧" : "󰌢",
                        closed ? "LID CLOSED" : "LID OPEN")
                }
                function onLockKeyChanged(key, on) {
                    screenScope.showModeToast(key === "caps" ? "󰘲" : "󰎠",
                        (key === "caps" ? "CAPS LOCK " : "NUM LOCK ") + (on ? "ON" : "OFF"))
                }
            }

            // The launcher, on the focused monitor. The same key again closes
            // it; the other mode's key switches it over in place.
            property string launcherMode: "apps"

            Connections {
                target: root
                function onLauncherToggled(mode) {
                    if (!screenScope.isFocusedScreen()) return
                    if (screenScope.openFlyout === "launcher" && screenScope.launcherMode === mode) {
                        screenScope.openFlyout = ""
                        return
                    }
                    screenScope.launcherMode = mode
                    screenScope.openFlyout = "launcher"
                }
            }

            // The notification history under its bar module, as a click
            // would; with the module hidden, centred instead
            Connections {
                target: Notifications
                function onPanelToggled() {
                    if (!screenScope.isFocusedScreen()) return
                    const it = screenScope.barWindow.widgetItem("notifications")
                    if (it && it.visible) {
                        screenScope.toggleFlyout("notifications", it)
                        return
                    }
                    screenScope.flyoutAnchorX = screenScope.modelData.width / 2
                    screenScope.openFlyout = screenScope.openFlyout === "notifications" ? "" : "notifications"
                }
            }

            // SUPER+I opens Claude under its bar module, as a click would;
            // with the module hidden, centred instead
            Connections {
                target: root
                function onClaudeToggled() {
                    if (!screenScope.isFocusedScreen()) return
                    const it = screenScope.barWindow.widgetItem("claude")
                    if (it && it.visible) {
                        screenScope.toggleFlyout("claude", it)
                        return
                    }
                    screenScope.flyoutAnchorX = screenScope.modelData.width / 2
                    screenScope.openFlyout = screenScope.openFlyout === "claude" ? "" : "claude"
                }
            }

            // The gesture the open switcher belongs to; -1 when none is up.
            property int altTabOpenGen: -1

            // A gesture whose ALT release arrived before its switcher -- the
            // Tab that opens it still on its way through the relay.
            // onAltTabTab then never opens a switcher for it. By id, so it
            // needs no deadline and can't swallow the next gesture (whose id
            // is higher). -1 for none.
            property int altTabPendingCommitGen: -1

            // The last gesture committed. Every route to the ALT release fires
            // on every gesture, so the later ones arrive with the switcher
            // closed, like an early release would -- the id tells them apart.
            property int altTabCommittedGen: -1

            // -1 for anything unparseable, e.g. a hand-run `qs ipc call`
            // with no id: such a call gets the plain, unmatched behaviour.
            function altTabGen(raw) {
                const n = parseInt(raw)
                return isNaN(n) ? -1 : n
            }

            // A Hyprland config reload restarts gesture ids at 1 while this
            // shell remembers higher ones. An id below the last committed one
            // can only mean that, so forget the old numbering.
            function altTabCheckEpoch(gen) {
                if (gen < 0 || gen >= altTabCommittedGen) return
                altTabCommittedGen = -1
                altTabPendingCommitGen = -1
            }

            // ALT+Tab, on the focused monitor only: the first Tab of a gesture
            // opens the switcher, every later one steps it. Decided here,
            // against openFlyout, since the bind keeps no state.
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
                    if (altTab.windows.length <= 1) return

                    screenScope.altTabCheckEpoch(altTab.gen)
                    screenScope.altTabOpenGen = altTab.gen

                    // This gesture's release already arrived, so the gesture
                    // is over: commit to the previous window (a fast tap's
                    // swap) instead of opening a switcher nobody is holding
                    // ALT for. `>=`: the release carries the gesture's *last*
                    // Tab id, so an earlier Tab arriving late is just as done.
                    if (altTab.gen >= 0 && screenScope.altTabPendingCommitGen >= altTab.gen) {
                        screenScope.altTabPendingCommitGen = -1
                        altTab.commit()
                        return
                    }
                    screenScope.openFlyout = "alttab"
                }
                function onAltTabStep(delta, gen) {
                    if (screenScope.openFlyout !== "alttab") return
                    altTab.step(delta)
                }
                function onAltTabCommit(gen) {
                    const g = screenScope.altTabGen(gen)
                    if (screenScope.openFlyout !== "alttab") {
                        screenScope.altTabCheckEpoch(g)
                        // Remembered for the case above, unless the gesture is
                        // already committed (a duplicate). Focused screen only,
                        // so a stray one can't wait on another screen.
                        if (screenScope.isFocusedScreen() && g > screenScope.altTabCommittedGen)
                            screenScope.altTabPendingCommitGen = Math.max(
                                screenScope.altTabPendingCommitGen, g)
                        return
                    }
                    // Any release closes an open switcher, whatever its id:
                    // the ids only decide whether to *open* one.
                    screenScope.altTabPendingCommitGen = -1
                    altTab.commit()
                }
                function onAltTabCancel() {
                    screenScope.altTabPendingCommitGen = -1
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
                visible: Theme.barFull || Theme.barFloating
                anchors.fill: barBody
                color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
                radius: Theme.barFloating ? Theme.radius : 0
                border.width: Theme.barFloating ? Theme.borderWidth : 0
                border.color: Theme.stroke
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
                    radius: Theme.radius
                    color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
                    border.width: Theme.borderWidth
                    border.color: Theme.stroke
                }
            }

            // Notch: the centre group's ground, flush against the screen
            // edge with only its far corners rounded, growing and shrinking
            // as the centre's modules come and go.
            Rectangle {
                readonly property var span: Theme.barNotch ? bar.islandSpan("centre") : ({ x: 0, w: 0 })
                readonly property int pad: Theme.moduleGap + Theme.spaceXl
                readonly property bool atBottom: Theme.barPosition === "bottom"
                visible: Theme.barNotch && span.w > 0
                x: span.x - pad
                y: barBody.y
                width: span.w + pad * 2
                height: barBody.height
                radius: Theme.radius
                color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
                Behavior on x { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease } }
                Behavior on width { NumberAnimation { duration: Theme.durSlow; easing.type: Theme.ease } }

                // squares off the corners on the screen edge
                Rectangle {
                    y: parent.atBottom ? parent.height - height : 0
                    width: parent.width
                    height: Math.min(parent.radius, parent.height / 2)
                    color: parent.color
                }
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
                        if (!cls) continue
                        var ipc = tls[j].lastIpcObject
                        icons.push({
                            source: Apps.iconForClass(cls),
                            // drawn instead when nothing resolved, so a
                            // window is never silently missing from the strip
                            glyph: Apps.glyphForWindow(cls, ipc ? ipc.title : ""),
                            address: tls[j].address,
                        })
                    }
                    break
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

            // The bar's 18 modules, in BarModules.qml -- split out since
            // each module's own logic buried the layout plumbing below.
            BarModules {
                id: barModules
                bar: bar
                screenScope: screenScope
                trayMenu: trayMenu
                windowMenu: windowMenu
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
                anchors.rightMargin: Theme.moduleGap + Theme.barInset
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
        ModeToast {
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

        // In place of Quickshell's own "reloaded" popup, on every screen
        ReloadToast {
            scope: screenScope
        }

        // Notifications as they arrive
        NotificationPopups {
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

        // CTRL+SPACE / SUPER+H: the launcher, centred like the workspace grid
        LazyFlyout { name: "launcher"; scope: screenScope; Launcher { scope: screenScope } }

        // tray menu: the app's own menu, drawn as flyout rows so it matches
        // everything else rather than popping a native Qt menu. Submenus
        // drill down in place, like the control centre.
        LazyFlyout {
            id: trayMenu
            name: "traymenu"; scope: screenScope
            TrayMenuFlyout { scope: screenScope }
        }

        // right-click menu for a window in the bar's open-windows strip
        LazyFlyout {
            id: windowMenu
            name: "windowmenu"; scope: screenScope
            WindowMenuFlyout { scope: screenScope }
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

        // notification history
        LazyFlyout { name: "notifications"; scope: screenScope; NotificationsFlyout { scope: screenScope } }

        // Claude: SUPER+I or the bar module
        LazyFlyout { name: "claude"; scope: screenScope; ClaudeFlyout { scope: screenScope } }

        // control centre
        LazyFlyout {
            name: "controlcentre"; scope: screenScope
            ControlCentre {
                scope: screenScope
                shellRoot: root
                settingsWin: settingsWindow
                systemWin: system
            }
        }

        }
    }
}


