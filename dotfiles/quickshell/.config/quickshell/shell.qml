// Singularity - Quickshell
// ~/.config/quickshell/shell.qml
//
// The shell's entry point: session-wide state (Keep Awake, Night Light,
// lock keys), the IPC targets binds and scripts call, and one Scope per
// screen holding its bar and flyouts. Only one flyout is open at a time:
// `openFlyout` holds its name.
//
// System state comes from Quickshell's DBus-backed services; brightness
// (brightnessctl) and network (iwd, which Quickshell.Networking can't use)
// shell out instead. QML errors: run `quickshell` from a terminal.

import "services"
import "flyouts"
import "bar"
import "windows"
import "sidebar"
import "desktop"
import "services/TimeWindow.js" as TimeWindow
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick

ShellRoot {
    id: root

    // read here so Wallpaper (a lazily built singleton) runs from startup
    readonly property string wallpaper: Wallpaper.current
    // and BtBattery, so the AirPods' battery channel opens as they connect:
    // opening it later (the Bluetooth flyout or page) plays their chime;
    // and Channels, so the ChatMix dial is read from the start
    Component.onCompleted: { BtBattery.parts; Channels.chatmix }

    // Keep Awake, from the Control Centre. On the root so every screen agrees;
    // session-only so idle is never left inhibited overnight.
    property bool keepAwake: false
    // Night Light, from the Control Centre: on while hyprsunset runs (stopping it
    // restores normal gamma). Session-only, like Keep Awake.
    property bool nightLight: false
    readonly property int nightLightKelvin: Settings.nightLightKelvin
    // retuned in place: a restart would flash the screen cold
    onNightLightKelvinChanged: if (nightLightProc.running)
        Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(nightLightKelvin)])
    // false until the probe below finds the binary
    property bool hasHyprsunset: false

    // Night Light's schedule. Acts only when the window opens or closes, so a
    // hand toggle holds until the next edge; rechecked on waking.
    readonly property var nightWindow: Settings.nightLightSchedule === "sun"
        ? [Weather.sunsetMin >= 0 ? Weather.sunsetMin : 1140, Weather.sunriseMin >= 0 ? Weather.sunriseMin : 420]
        : [Settings.nightLightFrom, Settings.nightLightTo]
    // the window's state at the last check; undefined makes the next one act
    property var nightScheduled: undefined

    function checkNightSchedule() {
        if (Settings.nightLightSchedule === "off") { nightScheduled = undefined; return }
        const want = TimeWindow.contains(nightWindow[0], nightWindow[1], new Date())
        if (want === nightScheduled) return
        nightScheduled = want
        nightLight = want
    }
    onNightWindowChanged: checkNightSchedule()

    // a schedule just picked or retimed applies straight away
    Connections {
        target: Settings
        function onNightLightScheduleChanged() { root.nightScheduled = undefined; root.checkNightSchedule() }
        function onNightLightFromChanged() { root.nightScheduled = undefined; root.checkNightSchedule() }
        function onNightLightToChanged() { root.nightScheduled = undefined; root.checkNightSchedule() }
    }
    Connections {
        target: Session
        function onResumed() { root.checkNightSchedule() }
    }
    Timer {
        interval: 20000
        repeat: true
        running: Settings.nightLightSchedule !== "off"
        triggeredOnStart: true
        onTriggered: root.checkNightSchedule()
    }

    // also kills a hyprsunset left behind by an earlier shell
    Process {
        running: true
        command: ["sh", "-c", "pkill -x hyprsunset; command -v hyprsunset"]
        onExited: code => root.hasHyprsunset = (code === 0)
    }

    Process {
        id: nightLightProc
        command: ["hyprsunset", "-t", String(root.nightLightKelvin)]
        running: root.nightLight && root.hasHyprsunset
        // exited on its own (crash, refused gamma): the toggle follows
        onExited: if (root.nightLight) root.nightLight = false
    }

    // Standalone windows, one each per session, built on first open
    LazyWindow { id: system; System {} }
    LazyWindow {
        id: settingsWindow
        SettingsWindow {}
    }
    LazyWindow { id: notesWindow; NotesWindow {} }
    LazyWindow { id: keybindsWindow; KeybindsWindow {} }

    // `qs ipc call settings open <page>`
    IpcHandler {
        target: "settings"
        function open(page: string): void { settingsWindow.open(page) }
    }

    // from windows.lua's singularityShowDesktop(): tags aren't announced
    IpcHandler {
        target: "desktop"
        function changed(): void { Hyprland.refreshToplevels() }
    }

    // `qs ipc call system open <page>`
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
        function open(): void { keybindsWindow.open() }
    }

    // `qs ipc call gamemode toggle`
    IpcHandler {
        target: "gamemode"
        function toggle(): void { GameMode.toggle() }
        function set(on: bool): void { GameMode.set(on) }
        function get(): bool { return GameMode.active }
    }

    // `qs ipc call look cycle` / `... set <name>`
    IpcHandler {
        target: "look"
        function cycle(): void { Settings.cycle("look") }
        function set(name: string): void { Settings.set("look", name) }
        function get(): string { return Settings.look }
        // the appearance's saved default (Settings.saveAsDefault)
        function saveDefault(): void { Settings.saveAsDefault() }
        function resetToDefault(): void { Settings.reset() }
        function isDefault(): bool { return Settings.isDefault }
    }

    AppearanceSync {}

    // SUPER+W (`qs ipc call overlay toggle`). A signal, because the overlays
    // live per screen inside Variants; only the focused screen's acts.
    signal workspaceOverlayToggled()

    IpcHandler {
        target: "overlay"
        function toggle(): void { root.workspaceOverlayToggled() }
    }

    // SUPER+M, from windows.lua: `qs ipc call layout <mode>`. Toasted on
    // the focused screen.
    signal layoutModeChanged(string mode)

    IpcHandler {
        target: "layout"
        function set(mode: string): void { root.layoutModeChanged(mode) }
    }

    // Caps/Num Lock, from binds.lua: `qs ipc call locks changed caps|num`.
    // The bind fires on press, before xkb updates, so the shell flips its
    // own copy and toasts it; the real state is read back at startup and
    // a second after the last toggle, correcting any drift.
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
        // long enough for the key to be up again
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

    // The lid, from lid.sh after its debounce: `qs ipc call lid changed closed|open`
    signal lidChanged(bool closed)

    IpcHandler {
        target: "lid"
        function changed(state: string): void {
            if (state !== "closed" && state !== "open") return
            root.lidChanged(state === "closed")
        }
    }

    // The launcher: `qs ipc call launcher toggle apps|clipboard`
    signal launcherToggled(string mode)

    IpcHandler {
        target: "launcher"
        function toggle(mode: string): void { root.launcherToggled(mode) }
    }

    // The Claude sidebar on the focused screen: `qs ipc call claude toggle`
    // (SUPER+I)
    IpcHandler {
        target: "claude"
        function toggle(): void {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            Ai.toggle(Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0])
        }
    }

    // built on first open, then kept, so its scroll and draft stay
    LazyLoader {
        active: Ai.used
        AiSidebar {}
    }

    // Notifications: the history flyout, Do Not Disturb, Clear all
    IpcHandler {
        target: "notifications"
        function toggle(): void { Notifications.togglePanel() }
        function dnd(): void { Notifications.toggleDnd() }
        function clear(): void { Notifications.clearAll() }
    }

    // Edit mode on the focused screen's bar: `qs ipc call bar edit`
    signal barEditRequested()

    IpcHandler {
        target: "bar"
        function edit(): void { root.barEditRequested() }
    }

    // Edit mode for the focused screen's desktop widgets, on or off:
    // `qs ipc call widgets edit`
    signal widgetEditRequested()

    IpcHandler {
        target: "widgets"
        function edit(): void { root.widgetEditRequested() }
    }

    // The power menu (SUPER+SHIFT+E)
    signal powerMenuToggled()

    IpcHandler {
        target: "power"
        function menu(): void { root.powerMenuToggled() }
    }

    // The media keys: Media.keyPlayer, never a browser's tab
    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle() }
        function play(): void { Media.play() }
        function pause(): void { Media.pause() }
        function stop(): void { Media.stop() }
        function next(): void { Media.next() }
        function previous(): void { Media.previous() }
    }

    // ALT+Tab. Every Tab of a held ALT re-runs alttab-ipc.sh: tab() opens the
    // switcher or steps it, commit() on ALT's release. `gen` is the gesture
    // id from alttab.lua, so a release that beats its switcher applies to
    // that gesture only.
    signal altTabTab(string clientsJson)
    signal altTabStep(int delta, string gen)
    signal altTabCommit(string gen)
    signal altTabCancel()

    IpcHandler {
        target: "alttab"
        // the gesture id and `hyprctl clients -j`, in one call (see
        // AltTabSwitcher.begin())
        function tab(clientsJson: string): void { root.altTabTab(clientsJson) }
        function prev(gen: string): void { root.altTabStep(-1, gen) }
        function commit(gen: string): void { root.altTabCommit(gen) }
        function cancel(): void { root.altTabCancel() }
        // alttab-relay's startup self-test of the wire format
        function ping(): string { return "singularity-relay-pong" }
    }

    // A client list fetched just before a close can bring the closed window
    // back; one more refresh after the close settles clears it.
    Timer {
        id: closedSweep
        interval: 300
        onTriggered: Hyprland.refreshToplevels()
    }

    // A window's class only reaches Hyprland.toplevels on a full refetch,
    // so refetch on every window event.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "openwindow" || n === "closewindow" || n === "movewindow"
                || n === "togglegroup" || n === "moveintogroup" || n === "moveoutofgroup") {
                Hyprland.refreshToplevels()
                if (n === "closewindow") closedSweep.restart()
            } else if (n === "activewindowv2") {
                // only a group needs a refresh on focus (which tab shows)
                const tl = Hyprland.toplevels.values.find(t => t.address === event.data)
                const ipc = tl ? tl.lastIpcObject : null
                if (ipc && ipc.grouped && ipc.grouped.length > 1) Hyprland.refreshToplevels()
            }
            // "special:name,MONITOR", or ",MONITOR" once hidden; read from the
            // event, since a refresh here still has the old state
            if (event.name === "activespecial") {
                const cut = event.data.lastIndexOf(",")
                const shown = Object.assign({}, root.specialShown)
                shown[event.data.slice(cut + 1)] = event.data.slice(0, cut)
                root.specialShown = shown
            }
        }
    }

    // monitor name -> the special workspace shown on it ("" for none), from
    // activespecial events; a monitor with no event yet isn't listed
    property var specialShown: ({})

    // Closes every screen's flyout but `except`'s (null: all of them).
    function closeFlyouts(except) {
        for (const s of screens.instances)
            if (s !== except) s.openFlyout = ""
    }

    Variants {
        id: screens
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property var modelData

            // name of the open flyout, "" for none
            property string openFlyout: ""
            onOpenFlyoutChanged: if (openFlyout !== "") root.closeFlyouts(screenScope)

            // every bar; a press on any isn't a click off a flyout (DismissGrab)
            readonly property var allBars: screens.instances.map(s => s.barWindow)

            // The bar, for the lazy flyouts (`bar: bar` there would bind to
            // itself).
            readonly property var barWindow: bar

            // screen-local x the open flyout centres itself under
            property real flyoutAnchorX: 0
            // the bar section ("left", "centre", "right") of the module it
            // opened from, "" when none; a grown flyout hangs off its group
            property string flyoutSection: ""

            // whether this screen has keyboard focus; keybind-opened things
            // show only there
            function isFocusedScreen() {
                return !!Hyprland.focusedMonitor
                    && Hyprland.focusedMonitor.name === screenScope.modelData.name
            }

            // a flyout's "More in Settings" row: close it, open that page
            function openSettings(page) {
                screenScope.openFlyout = ""
                settingsWindow.open(page)
            }

            function toggleFlyout(name, item) {
                if (screenScope.openFlyout === name) {
                    screenScope.openFlyout = ""
                    return
                }
                screenScope.flyoutAnchorX = item.mapToItem(null, item.width / 2, 0).x
                screenScope.flyoutSection = screenScope.barWindow.sectionOf(item)
                screenScope.openFlyout = name
            }

            // the bar's edit mode: its shelf, centred under the bar
            function editBar() {
                screenScope.flyoutAnchorX = screenScope.modelData.width / 2
                screenScope.flyoutSection = ""
                screenScope.openFlyout = "baredit"
            }

            Connections {
                target: root
                function onBarEditRequested() {
                    if (screenScope.isFocusedScreen()) screenScope.editBar()
                }
            }

            // the desktop widgets' edit mode, over everything on this screen
            function editWidgets() { screenScope.openFlyout = "widgetedit" }

            Connections {
                target: root
                function onWidgetEditRequested() {
                    if (!screenScope.isFocusedScreen()) return
                    if (screenScope.openFlyout === "widgetedit") screenScope.openFlyout = ""
                    else screenScope.editWidgets()
                }
            }

            // SUPER+W: the workspace grid on the focused monitor
            Connections {
                target: root
                function onWorkspaceOverlayToggled() {
                    if (!screenScope.isFocusedScreen()) return
                    screenScope.openFlyout =
                        screenScope.openFlyout === "workspaceoverlay" ? "" : "workspaceoverlay"
                }
            }

            // SUPER+SHIFT+E: the power menu on the focused monitor
            Connections {
                target: root
                function onPowerMenuToggled() {
                    if (!screenScope.isFocusedScreen()) return
                    screenScope.openFlyout =
                        screenScope.openFlyout === "powermenu" ? "" : "powermenu"
                }
            }

            // The mode toast (SUPER+M, lock keys, lid). Not a flyout, so it
            // doesn't touch openFlyout; the seq counter restarts it even
            // when the text repeats.
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

            Connections {
                target: Recorder
                function onToast(icon, text) { screenScope.showModeToast(icon, text.toUpperCase()) }
            }

            // The launcher on the focused monitor. Its key again closes it;
            // the other mode's key switches mode.
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

            // the notification history under its module, centred when hidden
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
                    screenScope.flyoutSection = ""
                    screenScope.openFlyout = screenScope.openFlyout === "notifications" ? "" : "notifications"
                }
                // a click on one opened what it's about
                function onActivated() {
                    if (screenScope.openFlyout === "notifications") screenScope.openFlyout = ""
                }
                function onSettingsRequested() {
                    if (screenScope.isFocusedScreen()) screenScope.openSettings("notifications")
                }
            }

            // the gesture the open switcher belongs to; -1 when none
            property int altTabOpenGen: -1

            // a gesture whose ALT release arrived before its switcher opened;
            // no switcher opens for it. -1 for none.
            property int altTabPendingCommitGen: -1

            // the last gesture committed, to drop duplicate releases
            property int altTabCommittedGen: -1

            // -1 when unparseable (a hand-run `qs ipc call`)
            function altTabGen(raw) {
                const n = parseInt(raw)
                return isNaN(n) ? -1 : n
            }

            // a Hyprland reload restarts ids at 1: forget the old numbering
            function altTabCheckEpoch(gen) {
                if (gen < 0 || gen >= altTabCommittedGen) return
                altTabCommittedGen = -1
                altTabPendingCommitGen = -1
            }

            // ALT+Tab on the focused monitor: the first Tab opens the switcher,
            // later ones step it.
            Connections {
                target: root

                // the focus test is in each handler: an `enabled` binding
                // re-evaluated mid-dispatch missed signals
                function onAltTabTab(clientsJson) {
                    if (!screenScope.isFocusedScreen()) return
                    if (screenScope.openFlyout === "alttab") {
                        altTab.step(1)
                        return
                    }
                    altTab.begin(clientsJson)
                    if (altTab.windows.length <= 1) return

                    screenScope.altTabCheckEpoch(altTab.gen)
                    screenScope.altTabOpenGen = altTab.gen

                    // its release already came: commit (a fast tap's swap)
                    // instead of opening. `>=`: the release carries the last Tab's id.
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
                        // remembered for the case above (focused screen,
                        // gestures not yet committed)
                        if (screenScope.isFocusedScreen() && g > screenScope.altTabCommittedGen)
                            screenScope.altTabPendingCommitGen = Math.max(
                                screenScope.altTabPendingCommitGen, g)
                        return
                    }
                    // any release closes an open switcher
                    screenScope.altTabPendingCommitGen = -1
                    altTab.commit()
                }
                function onAltTabCancel() {
                    screenScope.altTabPendingCommitGen = -1
                    if (screenScope.openFlyout !== "alttab") return
                    altTab.cancel()
                }
            }

        Bar {
            id: bar
            screenScope: screenScope
            shellRoot: root
            trayMenu: trayMenu
        }

        // clock, weather, music and stats on the desktop, under the windows
        DesktopWidgets {
            id: deskWidgets
            scope: screenScope
        }

        // --- flyouts --------------------------------------------------
        // Each is its own layer surface. LazyFlyout builds one on first open;
        // the toasts and ALT+Tab are always built, as they must react at once.

        // SUPER+W: the workspace grid
        LazyFlyout {
            name: "workspaceoverlay"; scope: screenScope
            WorkspaceOverlay { scope: screenScope }
        }

        LazyFlyout {
            name: "powermenu"; scope: screenScope
            PowerMenu { scope: screenScope }
        }

        // SUPER+M, lock keys, lid: the mode toast
        ModeToast {
            scope: screenScope
        }

        // volume/brightness OSD, from the Audio and Brightness services
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

        // ALT+Tab
        AltTabSwitcher {
            id: altTab
            scope: screenScope
        }

        // workspaces / windows
        LazyFlyout { name: "workspaces"; scope: screenScope; WorkspacesFlyout { scope: screenScope; bar: screenScope.barWindow; shellRoot: root } }

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

        // cooling (desktops)
        LazyFlyout { name: "cooling"; scope: screenScope; CoolingFlyout { scope: screenScope; systemWin: system } }

        // battery
        LazyFlyout { name: "battery"; scope: screenScope; BatteryFlyout { scope: screenScope } }

        // CTRL+SPACE / SUPER+H: the launcher, centred like the workspace grid
        LazyFlyout { name: "launcher"; scope: screenScope; Launcher { scope: screenScope } }

        // tray menu: the app's own menu as flyout rows
        LazyFlyout {
            id: trayMenu
            name: "traymenu"; scope: screenScope
            TrayMenuFlyout { scope: screenScope }
        }

        // right-click menu for the bar's empty space
        LazyFlyout { name: "barmenu"; scope: screenScope; BarMenuFlyout { scope: screenScope } }

        // the desktop widgets' edit mode, and the bare desktop's right-click menu
        LazyFlyout { name: "widgetedit"; scope: screenScope; WidgetEditor { scope: screenScope; layer: deskWidgets } }
        LazyFlyout { name: "desktopmenu"; scope: screenScope; DesktopMenu { scope: screenScope; layer: deskWidgets } }

        // the bar's edit mode: hidden modules, Reset, Done
        LazyFlyout { name: "baredit"; scope: screenScope; BarEditFlyout { scope: screenScope } }

        // an app's icon in the open-windows strip, when it has several windows
        LazyFlyout { name: "appwindows"; scope: screenScope; AppWindowsFlyout { scope: screenScope; bar: screenScope.barWindow } }

        // the Music module's
        LazyFlyout { name: "media"; scope: screenScope; MediaFlyout { scope: screenScope } }

        // weather
        LazyFlyout { name: "weather"; scope: screenScope; WeatherFlyout { scope: screenScope } }

        // privacy
        LazyFlyout { name: "privacy"; scope: screenScope; PrivacyFlyout { scope: screenScope } }

        // the phone and the peripherals with a battery
        LazyFlyout { name: "devices"; scope: screenScope; DevicesFlyout { scope: screenScope } }

        // the VPN
        LazyFlyout { name: "vpn"; scope: screenScope; VpnFlyout { scope: screenScope } }

        // removable drives
        LazyFlyout { name: "drives"; scope: screenScope; DrivesFlyout { scope: screenScope } }

        // failed units
        LazyFlyout { name: "failed"; scope: screenScope; FailedFlyout { scope: screenScope } }

        // updates
        LazyFlyout { name: "updates"; scope: screenScope; UpdatesFlyout { scope: screenScope } }

        // notification history
        LazyFlyout { name: "notifications"; scope: screenScope; NotificationsFlyout { scope: screenScope } }

        // control centre
        LazyFlyout {
            name: "controlcentre"; scope: screenScope
            ControlCentre {
                scope: screenScope
                shellRoot: root
                settingsWin: settingsWindow
                systemWin: system
                keybindsWin: keybindsWindow
            }
        }

        }
    }
}


