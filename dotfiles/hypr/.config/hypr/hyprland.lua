-- Singularity - Hyprland
-- ~/.config/hypr/hyprland.lua
--
-- Lua config. Hyprland loads this in preference to hyprland.conf, which is
-- deprecated -- and several options in the old file no longer exist at all:
-- gestures:workspace_swipe, gestures:workspace_swipe_fingers,
-- dwindle:pseudotile and misc:vfr, plus `togglesplit`, which is a layout
-- message here rather than a dispatcher.
--
-- grayscale ramp, shared with every other config in this repo:
--   #0b0b0b base   #121212 bar    #1a1a1a surface  #242424 overlay
--   #303030 border #4d4d4d muted  #7a7a7a subtext  #c2c2c2 text
--   #ebebeb bright

-- Forward-declared so the SUPER+SHIFT+F / SUPER+equal binds (Window
-- Management, below) can close over it ahead of its real definition further
-- down in Window Rules, next to the rest of the monocle logic it belongs
-- with. Lua locals are not hoisted -- omitting this `local` here would make
-- the assignment down below implicitly global instead of filling this
-- upvalue, and the binds would keep calling a nil function.
local toggleMaximize
local toggleMinimize

-- Workspaces 1..MAX_WORKSPACES get SUPER+n binds, and are the only ones a
-- window-rules.json entry may send a window to. Quickshell's copy is
-- Settings.workspaceCount (services/Settings.qml); keep the two equal.
local MAX_WORKSPACES = 5

------------------
---- PROGRAMS ----
------------------

-- Binary names, not .desktop names.
local terminal    = "alacritty"
local fileManager = "thunar"
local editor      = "codium"
local zen         = "zen-browser"
local floorp      = "floorp"
-- The Quickshell launcher (flyouts/Launcher.qml); wofi only if the shell
-- isn't running to answer. pkill first, so a second press dismisses wofi instead of stacking
-- another instance behind it. The stylesheet is Quickshell's copy with the bar's
-- corner radius applied (AppearanceSync.qml), falling back to the repo's own
-- until the shell has written one.
local menu        = "qs ipc call launcher toggle apps || pkill wofi || { s=~/.local/state/neutrino/wofi.css; [ -r \"$s\" ] || s=~/.config/wofi/style.css; wofi --show drun --style \"$s\"; }"

-- Animation Speed from the bar's Appearance page. Quickshell writes the choice
-- to a state file and runs `hyprctl reload config-only`, which re-runs this
-- file -- so the setting survives a restart without the repo's config being
-- rewritten. "fast" halves every speed below (speed is a duration, so lower is
-- quicker) and "off" turns animations off entirely.
local function singularityState(name, default)
    local f = io.open(os.getenv("HOME") .. "/.local/state/neutrino/" .. name)
    if not f then return default end
    local v = f:read("l")
    f:close()
    return v or default
end
local animMode   = singularityState("animations", "normal")
local animFactor = animMode == "fast" and 0.5 or 1

local function animation(t)
    t.speed   = t.speed * animFactor
    t.enabled = t.enabled and animMode ~= "off"
    hl.animation(t)
end

------------------
---- MONITORS ----
------------------

-- Empty output matches every display, which is what you want on a laptop that
-- gets docked. `hyprctl monitors` for real names when you need a per-display
-- rule.
-- scale 1 is native resolution: everything as small as the panel can draw it.
-- "auto" picks a HiDPI factor on a dense laptop panel, which makes the whole
-- desktop look oversized. Nudge to 1.25 or 1.5 if 1 is too small; fractional
-- values below 1 are not supported.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({
    output = "DP-3",
    mode = "preferred",
    position = "auto",
    scale = 1,
    mirror = "",
})

-- Primary display, picked on the Settings window's Display page and handed
-- over the same way as Animation Speed: a state file read here, then a
-- config-only reload. Workspace 1 lives on it, the cursor starts on it, and
-- duplicate mode copies it. Empty (the default) leaves all of that to
-- Hyprland, which uses the first display it finds.
--
-- The workspace rule only decides where workspace 1 is *created*, so a
-- workspace that already exists stays put. The Settings page moves it itself
-- when the choice changes; this hook covers docking, where the primary is
-- the display that just arrived and workspace 1 is still on the laptop.
local primaryDisplay = singularityState("primary-display", "")
if primaryDisplay ~= "" then
    hl.config({ cursor = { default_monitor = primaryDisplay } })
    hl.workspace_rule({ workspace = "1", monitor = primaryDisplay, default = true })
    hl.on("monitor.added", function()
        hl.dispatch(hl.dsp.workspace.move({ workspace = "1", monitor = primaryDisplay }))
    end)
end

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "20")
-- Icon theme for Quickshell's window icons and Applications list. GTK and
-- wofi get kora from gtk settings.ini, but Quickshell is Qt and Qt has no
-- theme configured here, so without this it falls back to each app's stock
-- hicolor icon (Thunar's hammer instead of kora's folder). It has to be in
-- the environment at launch: Quickshell reads it before its own
-- `//@ pragma Env` lines are applied, so setting it from shell.qml is ignored.
hl.env("QS_ICON_THEME", "kora")

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- Not UWSM, so graphical-session.target is never reached on its own --
    -- nothing here ever calls `systemctl --user start` on it, so anything
    -- that relies purely on the target (rather than D-Bus activation) to
    -- launch just sits enabled and dead for the whole session. That was
    -- silently true of the polkit agent: this used to point at
    -- /usr/lib/polkit-kde-authentication-agent-1, a KDE path that doesn't
    -- exist on this system, so the exec failed instantly and quietly and
    -- no agent ever ran -- any privileged action (mounting a drive, a
    -- NetworkManager prompt) would hang waiting on a dialog that could
    -- never appear. hyprpolkitagent is the one actually installed, and
    -- it's already enabled against graphical-session.target, so starting
    -- it here rather than execing the binary directly reuses that unit
    -- (respawn-on-crash, proper cgroup) instead of running it bare.
    --
    -- reset-failed first, for when this runs after Hyprland has crashed and
    -- been restarted by its watchdog. In the seconds with no compositor the
    -- unit's Restart=on-failure respawns the agent into a missing Wayland
    -- socket until systemd's start limit trips, and from then on a plain
    -- `start` is refused ("Start request repeated too quickly") -- which left
    -- the session with no polkit agent after a crash.
    hl.exec_cmd("systemctl --user reset-failed hyprpolkitagent.service; systemctl --user start hyprpolkitagent.service")
    -- Same trap as the polkit agent: hypridle's packaged unit hangs off
    -- graphical-session.target, which never activates here, so it has to
    -- be started by hand (reset-failed for the same crash-restart reason).
    -- The fallback runs the binary bare if the unit ever goes missing,
    -- rather than leaving the machine with no idle.
    hl.exec_cmd("systemctl --user reset-failed hypridle.service; systemctl --user start hypridle.service || hypridle")
    -- Same trap again, and it bites harder here: swaync.service is also
    -- D-Bus-activated (BusName=org.freedesktop.Notifications), so the first
    -- notification of a session can trigger it before WAYLAND_DISPLAY has
    -- propagated to the systemd --user environment, which fails it,
    -- restarts it, fails again, and hits systemd's start-limit within a
    -- couple seconds -- logging in shows a real "failed" unit even though
    -- it recovers a moment later. Starting it explicitly here, once the
    -- environment this hook runs in already has WAYLAND_DISPLAY, avoids the
    -- race instead of racing dbus activation for it.
    hl.exec_cmd("systemctl --user reset-failed swaync.service; systemctl --user start swaync.service")
    -- Stop logind suspending on lid close: the lid binds below just blank the
    -- screen, and hypridle suspends after 20 min idle. Released when
    -- Hyprland exits.
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Hyprland handles the lid' tail --pid=$(pidof -s Hyprland) -f /dev/null")
    -- Quickshell's QML warnings (binding loops, null-property access) go to
    -- stderr with nowhere to land but the TTY Hyprland was launched from --
    -- redirected to a log file so startup and logout stay clean.
    hl.exec_cmd("quickshell > ~/.cache/quickshell.log 2>&1")
    -- Persistent IPC relay for the ALT+Tab switcher -- see alttab-relay.cpp
    -- for what it does and why, and the alt-tab bind block below for how
    -- it's used. Order relative to `quickshell` above does not matter: it
    -- reconnects lazily on first use rather than requiring quickshell to
    -- already be up. QT_FORCE_STDERR_LOGGING keeps its log in that file:
    -- Qt otherwise decides for itself between stderr and the journal, and
    -- the startup self-test's failure message needs a place to be found.
    hl.exec_cmd("QT_FORCE_STDERR_LOGGING=1 ~/.config/hypr/alttab-relay > ~/.cache/alttab-relay.log 2>&1")
    -- env alone does not retheme the cursor Hyprland draws over the desktop
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 20")
    -- the saved wallpaper, or a random one from wallpapers/ when shuffle is on
    hl.exec_cmd("~/.config/hypr/wallpaper.sh")
    -- clipboard history daemon (cliphist needs this to capture every copy)
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- A terminal waiting on workspace 2. The custom title (not class) is what
    -- scopes the "send it to 2, silently" rule below to this one instance:
    -- matching on Alacritty's class would banish every terminal you ever
    -- open, and overriding the class instead of the title used to do exactly
    -- that -- it also meant every Quickshell component (bar's window strip,
    -- ALT+Tab switcher, workspace overlay) looked up "neutrino-startup" in
    -- DesktopEntries instead of "Alacritty" and came back with no icon.
    hl.exec_cmd(terminal .. " --title neutrino-startup")
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 1,
        gaps_out    = 0,
        border_size = 0,

        col = {
            active_border   = "rgba(c2c2c266)",
            inactive_border = "rgba(303030aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 3,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.96,
        dim_inactive = true,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            -- 0xAARRGGBB, so this is black at 40 percent
            color        = 0x66000000,
        },

        blur = {
            enabled    = true,
            size       = 6,
            passes     = 2,
            noise      = 0.015,
            contrast   = 0.9,
            brightness = 0.7,
        },
    },

    animations = {
        enabled = animMode ~= "off",
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- any key or mouse movement turns a blanked screen back on, whatever
        -- blanked it -- not only hypridle's own screens-off step
        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
    },
})

hl.curve("neutrino", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })

-- speed is in 100ms units (3 = 300ms), so lower is faster
animation({ leaf = "global",     enabled = true, speed = 3, bezier = "neutrino" })
animation({ leaf = "border",     enabled = true, speed = 3, bezier = "neutrino" })
animation({ leaf = "windows",    enabled = true, speed = 2, bezier = "neutrino", style = "popin 92%" })
animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "neutrino", style = "popin 92%" })
animation({ leaf = "fade",       enabled = true, speed = 1.5, bezier = "neutrino" })
animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "neutrino", style = "slidefade 12%" })

-- Layer surfaces: wofi, and the bar's flyouts. These inherit `global` unless
-- set, so the launcher was taking the same 300ms a window does just to appear
-- -- long enough to feel like a delay on something you open to type into.
-- fade rather than popin: the bar is a layer too, and scaling it on every
-- start looks wrong.
animation({ leaf = "layersIn",  enabled = true, speed = 1, bezier = "neutrino", style = "fade" })
animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "neutrino", style = "fade" })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout     = "us",
        follow_mouse  = 0,
        sensitivity   = 0.1,
        accel_profile = "adaptive",
        left_handed = false,

        touchpad = {
            natural_scroll       = false,
            disable_while_typing = true,
            scroll_factor        = 0.7,
            -- the .conf spelling is tap-to-click; the lua schema takes the
            -- underscored form, since dashes are not a bare Lua identifier
            tap_to_click         = true,
            clickfinger_behavior = true,
        },
    },

    -- stops the cursor from jumping to whatever gets focused, e.g. the
    -- Quickshell workspace bar's click-to-focus icons
    cursor = {
        no_warps = true,
    },
})

-- Hyprland inverts the workspace swipe by default, so a 3-finger swipe
-- left goes to the workspace on the right. That reads backwards next to
-- natural_scroll = false above, which already puts the touchpad's own
-- vertical scrolling in the traditional (uninverted) direction -- so this
-- un-inverts the horizontal one to match: swipe left, go left.
hl.config({
    gestures = {
        workspace_swipe_invert = false,
    },
})

-- Replaces gestures:workspace_swipe, which no longer exists.
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Sections are marker comments, `-- --- Name ---`: the bar's Keybinds window
-- groups binds by them and adds new ones to the end of the chosen section.

local mod = "SUPER"

-- --- Launchers ---
hl.bind("CTRL + SPACE",      hl.dsp.exec_cmd(menu))  -- Open app launcher
hl.bind(mod .. " + Return",  hl.dsp.exec_cmd(terminal))  -- Open terminal
hl.bind(mod .. " + A",       hl.dsp.exec_cmd(terminal))  -- Open terminal
hl.bind(mod .. " + E",       hl.dsp.exec_cmd(fileManager))  -- Open file manager
hl.bind(mod .. " + V",       hl.dsp.exec_cmd(editor))  -- Open code editor
hl.bind(mod .. " + Z",       hl.dsp.exec_cmd(zen))  -- Open Zen Browser
hl.bind(mod .. " + F",       hl.dsp.exec_cmd(floorp))  -- Open Floorp

-- --- Window Management ---
-- fullscreen sits on CTRL and float on SHIFT, since plain F and V launch apps
hl.bind(mod .. " + Q",         hl.dsp.window.close())  -- Close window
-- Two different things, deliberately on separate binds:
--   maximize  fills the usable area, stopping below the Quickshell bar
--   fullscreen covers the entire output, bar included
--
-- Routed through toggleMaximize() (defined down in the window rules section,
-- alongside the rest of the monocle logic it coordinates with) rather than
-- dispatched directly, so that unmaximizing on purpose sticks: in monocle,
-- focusing a window maximizes it, which would otherwise undo this the moment
-- you alt-tabbed away and back. toggleMaximize() records the window as
-- deliberately small and the focus hook leaves those alone. The wrapper
-- closures exist because these binds are registered before that function is
-- assigned further down -- Lua resolves the upvalue when the key is actually
-- pressed, not when the bind is registered, so the forward reference is fine.
hl.bind(mod .. " + X", function() toggleMaximize() end)  -- Maximize or restore window
hl.bind(mod .. " + CTRL + F",  hl.dsp.window.fullscreen())  -- Fullscreen window, covering the bar
-- same action as double-clicking a window's titlebar
hl.bind(mod .. " + equal",     function() toggleMaximize() end)  -- Maximize or restore window
hl.bind(mod .. " + C",         function() toggleMinimize() end)  -- Minimize or restore window
hl.bind(mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))  -- Float or tile window
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())  -- Log out
hl.bind(mod .. " + P",         hl.dsp.window.pseudo())  -- Keep window's own size in its tile
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"))  -- Split side by side or stacked
hl.bind(mod .. " + M",         function() toggleLayout() end)  -- Switch between tiled and one-window layout

-- Workspace grid: every workspace and its windows at once. Click a cell to
-- jump, click a window to focus it, drag a window between cells to move it.
-- Drawn by Quickshell (WorkspaceOverlay.qml), so this only pokes the shell.
hl.bind(mod .. " + W", hl.dsp.exec_cmd("qs ipc call overlay toggle"))  -- Show all workspaces

-- --- Focus ---
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))  -- Focus window to the left
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))  -- Focus window to the right
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))  -- Focus window above
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))  -- Focus window below

-- Windows-style alt-tab, with the switcher drawn by Quickshell
-- (AltTabSwitcher.qml). Hold ALT and tap Tab to move the highlight, release
-- ALT to focus what you landed on.
--
-- Nothing is focused until the release. Hyprland's own cycle_next focuses as
-- it walks, so previewing a window meant raising it and resizing the layout;
-- keeping the selection in Quickshell makes stepping free, and gives
-- SHIFT+Tab a working reverse direction, which the dispatcher never had.
--
-- There is no submap. Hyprland 0.56.2 does not deliver a modifier-key
-- *release* to a submap bind -- an Alt_L release bind inside one, with
-- ignore_mods, registered correctly and never fired once under test, while the
-- submap's catchall swallowed the release instead. That is what made the
-- switcher sit on screen and commit on whatever key came next: the "press Tab
-- again to open it" bug. The switcher takes the keyboard itself and catches
-- the release in Keys.onReleased, which also retires the catchall dead man's
-- switch -- with no submap there is no mode to get the keyboard stuck in.
--
-- Every Tab of a held ALT+Tab comes through these binds, not just the first:
-- Hyprland matches its own binds before forwarding keys to any client, so they
-- win over the switcher's keyboard grab and Keys.onPressed never sees a Tab.
-- The shell's onAltTabTab is idempotent to suit -- it opens the switcher on
-- the first Tab and steps it on the ones after. SHIFT+Tab and grave need their own
-- binds for the same reason; they would otherwise never reach the shell.
-- `repeating` on each so holding the key autorepeats.
--
-- alt-tab.sh and alttab-ipc.sh both reach the shell through alttab-relay
-- (started above) rather than `qs ipc call` directly -- see alttab-relay.cpp
-- and alttab-ipc.sh for why: `qs` is expensive enough to start on its own
-- (~45ms measured on this machine) to lose the race against a fast
-- tap-and-release, on top of everything above about catching the release at
-- all. Falls back to `qs` itself if the relay isn't reachable.
hl.bind("ALT + Tab",         hl.dsp.exec_cmd("~/.config/hypr/alt-tab.sh"),        { repeating = true })  -- Switch windows
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards
hl.bind("ALT + grave",       hl.dsp.exec_cmd("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards

-- A bare Alt_L/Alt_R `global` bind (hyprland-global-shortcuts-v1) was tried
-- here as a second route to the ALT release, alongside the keyboard grab in
-- AltTabSwitcher.qml. Reverted: registering it made Hyprland treat bare ALT
-- differently everywhere, not just during alt-tab -- ALT is also the mod for
-- window drag/resize, and releasing it after any of that started closing the
-- switcher's layer state and refocusing whatever the mouse was over, not
-- what alt-tab had selected. Not worth it.

-- --- Workspaces ---
for i = 1, MAX_WORKSPACES do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- --- Mouse ---
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })  -- Move window by dragging
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })  -- Resize window by dragging

-- --- Clipboard ---
hl.bind(mod .. " + H", hl.dsp.exec_cmd("qs ipc call launcher toggle clipboard"))  -- Clipboard history

-- --- Screenshot ---
-- saves to ~/Pictures/Screenshots and copies to the clipboard
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh"))  -- Screenshot an area

-- --- Lid ---
-- Close turns the screen off and suspends after 5 min if it's still shut;
-- open turns it back on and cancels that. logind's own lid handling is
-- inhibited in autostart so this is the only thing acting on the lid. All of
-- it -- the debounce for this laptop's bouncing lid switch, the suspend
-- timer, re-suspending after a wake with the lid shut, docked mode -- lives
-- in lid.sh. misc:key_press_enables_dpms and mouse_move_enables_dpms are the
-- backstop: any key or mouse movement wakes a wrongly-blanked screen.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid closed: screen off, suspend after 5 min
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid opened: screen on

-- --- Function Keys ---
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })  -- Volume up
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })  -- Volume down
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })  -- Mute or unmute sound
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })  -- Mute or unmute microphone
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -n1 set 5%+"),                     { locked = true, repeating = true })  -- Brightness up
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -n1 set 5%-"),                     { locked = true, repeating = true })  -- Brightness down

----------------------
---- WINDOW RULES ----
----------------------

-- Deliberately NOT suppressing maximize events. Hyprland's own example config
-- ships a `suppress_event = "maximize"` rule matching class ".*", but that is
-- what double-clicking a titlebar sends: with it in place, double-click stops
-- maximizing anything. Leaving it out keeps that working, and maximize honours
-- the Quickshell bar's reserved zone, so the window fills the space below it.

hl.window_rule({
    -- Fixes dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- The startup terminal, parked on workspace 2. "silent" is the whole point:
-- without it the window pulls the session onto workspace 2 as it opens, and
-- you land in a terminal instead of an empty desktop.
hl.window_rule({
    name  = "startup-terminal",
    match = { title = "^(neutrino-startup)$" },
    workspace = "2 silent",
})

-- Monocle. Hyprland ships dwindle and master only, with no monocle layout,
-- so this emulates one: dwindle stays the underlying layout, but every
-- window that would tile is floated and sized to fill the usable area
-- instead of maximized.
--
-- Floating rather than maximized on purpose: Hyprland allows exactly one
-- maximized (or tiled-fullscreen) window per workspace, so a maximize-based
-- monocle can only ever keep the *focused* window full -- everything else
-- sits at its dwindle-tile size until it is focused, which is what made
-- alt-tab visibly grow the landed-on window every single time. Floating
-- windows have independent geometry, so every one of them can be full-size
-- at once; switching focus is then just a raise, with nothing to resize.
--
-- tag "+monocle" on the rule (removed by "-monocle" on every rule below
-- this shares a window with) is what tells the window.open hook further
-- down which windows it owns: without it, sizing would have to duplicate
-- every one of those rules' class/title matches here instead of just
-- deferring to whichever of them wins.
local monocleRule = hl.window_rule({
    name  = "monocle",
    match = { float = false },
    float = true,
    maximize = false,
    tag = "+monocle",
})

-- The bar's standalone windows (System, Keybinds, Settings) are
-- Quickshell FloatingWindows, class org.quickshell. They size themselves to
-- their content, so they float at that size, centred on the focused monitor.
-- DO NOT apply generic floating window sizing (50%, centered) — let them use
-- their own size logic defined in QML code.
--
-- Two things here are load-bearing. maximize = false: the monocle rule
-- matches `float = false`, and at map time these aren't floating *yet*, so
-- it catches them too. And this rule has to come *after* the monocle rule:
-- when two rules set the same property the later one wins, so above it,
-- monocle's maximize = true overrides this and they float at full size.
hl.window_rule({
    name     = "quickshell-windows",
    tag      = "-monocle",
    match    = { class = "^(org\\.quickshell)$" },
    float    = true,
    center   = true,
    maximize = false,
    -- Intentionally no size constraint — QML code defines window dimensions
})

-- Apps that are always worth the whole screen: the editor and the browsers.
-- Always maximize-on-open in dwindle mode, so switching to dwindle tiles
-- everything else while leaving these full. In monocle mode this rule is
-- disabled (see toggleLayout) and monocleRule's ordinary float+size handles
-- them instead -- they used to be exempted from that and kept this
-- maximize=true unconditionally, which seemed right (they open already
-- full) but wasn't: with two of them open at once, Hyprland's one-tiled-
-- maximized-window-per-workspace limit still means only one can hold that
-- state, so alt-tabbing *between* them, e.g. the editor and a browser, jarred
-- exactly like the problem this was all meant to fix. Floating both like
-- everything else is what actually keeps them both full at the same time.
--
-- Matched on class, not title: browser and editor titles change with whatever
-- is open in them.
local maximizePrimaryDwindleRule = hl.window_rule({
    name     = "maximize-primary-dwindle",
    match    = { class = "^(codium|VSCodium|floorp|zen|zen-browser)$" },
    maximize = true,
})
maximizePrimaryDwindleRule:set_enabled(false)

-- Every per-app and popout exception lives in one place:
-- ~/.config/singularity/window-rules.json (the repo's dotfiles/singularity
-- package, so the defaults ship with it), edited from the Settings window's
-- Window Rules page. What stays in this file is the machinery the shell
-- itself depends on -- monocle, Quickshell's own windows, the XWayland drag
-- fix, the startup terminal -- not preferences about particular apps.
--
-- Read on every load, so the page's save-then-reload is all it takes; like
-- any window rule they apply to windows as they open. Placed after every rule
-- above on purpose: when two rules set the same property the later one wins,
-- so an entry here overrides this file's defaults for that app. Within the
-- file it's the other way round -- the entry nearer the top wins.
--
-- Entries match by class, title or both. Written from the page they are
-- literal and whole ("org.pwmt.zathura" matches that class and nothing else);
-- with "regex": true they are passed to Hyprland as written, which is what
-- the popout entries need. Lookaheads never match there (see below); a
-- "negative:" prefix is how an entry says "anything but this".
--
-- Popouts are a heuristic, not a rule: GTK and Qt dialogs inherit their
-- parent app's class, so only the title tells them apart, and the list of
-- titles will need extending as things slip through.
--
-- JSON comes from json.lua beside this file (Hyprland's Lua has no JSON
-- library). Loaded with pcall: if it's missing or broken the rules file is
-- treated as empty, never as an error that takes the rest of the config down.
local decodeJson
do
    local ok, decoder = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/json.lua")
    decodeJson = ok and decoder or function() return nil end
end

-- Classes are matched whole and literally: "org.pwmt.zathura" must not also
-- match "orgXpwmtYzathura", so every regex metacharacter is escaped.
local function literalRegex(text)
    return (text:gsub("[%.%^%$%*%+%?%(%)%[%]%{%}%|\\]", "\\%0"))
end

do
    local f = io.open(os.getenv("HOME") .. "/.config/singularity/window-rules.json")
    local rules = f and decodeJson(f:read("a")) or {}
    if f then f:close() end
    -- Bottom of the file first: when two rules set the same property the
    -- one applied last wins, and the page lists newest first, so this makes
    -- "higher in the list wins" -- a rule you just added beats the defaults.
    rules = type(rules) == "table" and rules or {}
    for n = #rules, 1, -1 do
        local r = rules[n]
        local match = {}
        if type(r) == "table" then
            for _, key in ipairs({ "class", "title" }) do
                if type(r[key]) == "string" and r[key] ~= "" then
                    match[key] = r.regex and r[key] or "^(" .. literalRegex(r[key]) .. ")$"
                end
            end
        end
        if next(match) then
            -- A rule that doesn't name a class never reaches Quickshell's own
            -- windows. They size themselves in QML, and a title rule handing
            -- one a size cut it off: the Settings window carries the title
            -- "Settings", which the dialog entry matches, and lost a chunk of
            -- its content to a smaller surface than it was laid out for.
            --
            -- "negative:", not a (?!...) lookahead: Hyprland's regex engine
            -- has no lookaheads, and a pattern using one doesn't error, it
            -- just never matches -- which silently disabled the whole rule.
            match.class = match.class or "negative:^(org\\.quickshell)$"
            local name = "settings-rule-" .. n
            local rule = { name = name, match = match }
            local exempt = r.float or r.pin or r.fullscreen
            -- Floating, pinned and fullscreen windows all leave monocle: its
            -- open hook would otherwise resize them to fill the screen a
            -- moment after this rule put them where they belong.
            if exempt then
                rule.tag      = "-monocle"
                rule.maximize = false
            end
            -- Pinning only applies to floating windows in Hyprland. A pinned
            -- window (picture-in-picture) keeps the spot its app chose.
            if r.float or r.pin then
                rule.float  = true
                rule.center = not r.pin
                if type(r.size) == "string" and r.size:match("^%d+ %d+$") then rule.size = r.size end
            end
            if r.pin then rule.pin = true end
            if r.fullscreen then rule.fullscreen = true end
            local ws = tonumber(r.workspace)
            if ws and ws >= 1 and ws <= MAX_WORKSPACES then rule.workspace = tostring(math.floor(ws)) end
            hl.window_rule(rule)
            -- A second rule, because one rule carries one tag: this marks the
            -- window as exempt for SUPER+M's sweep (toggleLayout), which has
            -- to decide about windows that were already open without being
            -- able to ask which rules matched them.
            if exempt then
                hl.window_rule({ name = name .. "-exempt", match = match, tag = "+monocle-exempt" })
            end
        end
    end
end

-- What actually keeps monocle coherent.
--
-- Hyprland allows exactly one maximized window per workspace, so the window
-- rule alone cannot hold the illusion: it fires as a window maps, the new
-- window takes the maximized state, and every window opened before it silently
-- drops back to its dwindle size. What you get is not monocle but a normal
-- tiled layout where only the newest window is big -- which is why double
-- clicking a titlebar looked like it "shrank the window into its tile": the
-- window really was tiled, and maximize was toggling it out of full.
--
-- Maximizing on focus instead of on map is what fixes that. Whatever you land
-- on is full by the time you see it, from any route -- alt-tab, the taskbar,
-- SUPER+arrow, closing the window in front.
--
-- This used to shell out to a bash+python script over `hyprctl -j` for every
-- focus change. That round trip (spawn a process, open a new hyprctl IPC
-- socket, parse JSON, dispatch back) was slow enough relative to Hyprland's
-- own event ordering that a second, unrelated focus event -- notably the
-- keyboard grab release when the ALT+Tab switcher closes, which bounces focus
-- back to whichever window was active before the switcher opened -- could
-- land in the middle of it and steal the maximize meant for the real target.
-- Chasing that race with retries treated the symptom. Running the whole check
-- in Lua, in-process, on Hyprland's own event thread removes it at the root:
-- there is no subprocess and no IPC round trip for another event to land
-- inside of, so this always finishes inside the same tick as the focus event
-- that triggered it.
--
-- windowsInMonocle tracks layout mode as a Lua boolean rather than a runtime
-- file: nothing outside this config needs to read it, so there is no reason
-- to leave process boundaries. It resets to monocle (this default) on a
-- config reload or Hyprland restart, same as the file it replaces did on
-- reboot.
local monocleEnabled = true

-- Workspaces pinned to one layout whatever SUPER+M says, from
-- ~/.config/singularity/workspace-layouts.json -- { "1": "monocle",
-- "3": "dwindle" } -- which the Settings window's Window Rules page writes.
-- Anything not listed follows monocleEnabled. Read on every load, like
-- window-rules.json.
local workspaceLayouts = {}
do
    local f = io.open(os.getenv("HOME") .. "/.config/singularity/workspace-layouts.json")
    local pins = f and decodeJson(f:read("a")) or {}
    if f then f:close() end
    if type(pins) == "table" then
        for ws, mode in pairs(pins) do
            if mode == "monocle" or mode == "dwindle" then workspaceLayouts[tostring(ws)] = mode end
        end
    end
end

-- Whether monocle applies on this workspace: its pin, else the global mode.
local function monocleOn(ws)
    local pin = ws and workspaceLayouts[tostring(ws.id)]
    if pin then return pin == "monocle" end
    return monocleEnabled
end

-- Per-window state this config keeps on top of Hyprland's own, by address,
-- in memory for the same reason as monocleEnabled above:
--   small     -- unmaximized on purpose (SUPER+equal), so refocusing it does
--                not immediately undo the choice; see toggleMaximize() below
--   minimized -- the {x, y} SUPER+C hid it from; see toggleMinimize() below
-- One table, cleared by one window.close hook further down: addresses are
-- pointer values Hyprland reuses once a window is gone, so anything left
-- behind would land on some unrelated window that opens later.
local windowState = {}
local function stateOf(addr)
    local st = windowState[addr]
    if not st then
        st = {}
        windowState[addr] = st
    end
    return st
end

-- Puts a SUPER+C-hidden window back where it was and forgets it was hidden.
local function restoreMinimized(win)
    local st = stateOf(win.address)
    local saved = st.minimized
    st.minimized = nil
    hl.dispatch(hl.dsp.window.move({ x = saved.x, y = saved.y, window = "address:" .. win.address }))
end

-- The monitor's usable rect (its resolution minus whatever the bar and any
-- other layer-shell surface has reserved), in the same logical-pixel units
-- as win.size/win.at. Shared by isAlreadyFull() below (the maximize-based
-- path, for dwindle mode) and the floating-monocle sizer.
--
-- x/y are the monitor's own origin plus its reserved edge, NOT the reserved
-- edge alone: hl.dsp.window.move places a window at an absolute point in the
-- whole layout, not an offset within its monitor (verified by moving the same
-- window to the same coordinates twice -- it does not drift). Returning a
-- monitor-local origin put every window on the second monitor at the *first*
-- monitor's top-left while still sized to the second's resolution, so a
-- display sitting to the right of another had its windows land on the wrong
-- screen and hang off the far edge of it.
local function usableArea(mon)
    local reserved = mon.reserved or { left = 0, top = 0, right = 0, bottom = 0 }
    return {
        x = (mon.x or 0) + reserved.left,
        y = (mon.y or 0) + reserved.top,
        w = mon.width / mon.scale - reserved.left - reserved.right,
        h = mon.height / mon.scale - reserved.top - reserved.bottom,
    }
end

-- Whether a floating-monocle window still fills the monitor it is actually
-- on. isAlreadyFull() below compares size alone, which is all the maximize
-- path needs; this one compares position too, since the whole failure it
-- guards against is a window that is the right size on the wrong screen.
local function isFitted(win, area)
    return math.abs(win.size.x - area.w) <= 4 and math.abs(win.size.y - area.h) <= 4
        and math.abs(win.at.x - area.x) <= 4 and math.abs(win.at.y - area.y) <= 4
end

local function isAlreadyFull(win, mon)
    local area = usableArea(mon)
    local w, h = win.size.x, win.size.y
    return math.abs(w - area.w) <= 4 and math.abs(h - area.h) <= 4
end

-- True if `win` currently carries the given Hyprland tag. Tags are real,
-- queryable window state (not just a match-time flag), so this works
-- whenever it's checked, not only right after the window maps.
-- A tag applied by a window rule (monocleRule, here) comes back with a
-- trailing "*" -- Hyprland's marker for a "dynamic" tag that gets
-- re-evaluated, versus a plain "static" one set by a one-off dispatch
-- (hl.dsp.window.tag, in toggleLayout's sweep below) which has none. Both
-- are the same tag as far as this config cares, so both compare equal here.
local function hasTag(win, name)
    if not win.tags then return false end
    if type(win.tags) == "table" then
        for _, t in ipairs(win.tags) do
            if t == name or t == name .. "*" then return true end
        end
        return false
    end
    return win.tags == name or win.tags == name .. "*"
end

-- Windows SUPER+M's sweep (toggleLayout) must leave floating when monocle
-- comes back on. It can't rely on the "monocle" tag -- windows open since
-- dwindle mode never got one -- so it asks the "monocle-exempt" tag the
-- window-rules.json entries add, plus Quickshell's own windows, whose rule
-- is part of this file's machinery rather than that list.
local function isMonocleExempt(win)
    return win.class == "org.quickshell" or hasTag(win, "monocle-exempt")
end

-- Fills `win` to the monitor's usable rect without touching its floating
-- state -- callers decide whether it needs floating first.
local function sizeToFullFloat(win, mon)
    mon = mon or win.monitor or hl.get_active_monitor()
    if not mon then return end
    local area = usableArea(mon)
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(area.w), y = math.floor(area.h), window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(area.x), y = math.floor(area.y), window = addr }))
end

-- Sizes every window the monocle rule just floated, the moment it maps --
-- once, on open, rather than on every focus change. That's the entire fix
-- for alt-tab's resize jank: by the time anything can be focused, it's
-- already full, so switching to it is just a raise.
-- window.open hands the window that just mapped as its first argument.
-- hl.get_active_window() is NOT a reliable substitute here (unlike in
-- maximizeFocused()'s hooks): a second window opening while another is
-- already focused can fire this before the active pointer has moved on to
-- it, which silently sized the *previous* window a second time instead --
-- confirmed with a real pair of test windows before landing on this.
-- Moves one window into or out of monocle. SUPER+M's sweep, and any window
-- that lands on a workspace whose layout isn't the one the rules were set
-- for when it mapped (see applyLayoutRules below). Windows opened before
-- monocle was ever turned on have no "monocle" tag yet (the rule was
-- disabled when they mapped), so going into monocle falls back to the
-- exemption list for those; going out can trust the tag, since anything
-- wearing it was floated by this same machinery at some point.
local function setWindowMonocle(w, on, mon)
    local addr = "address:" .. w.address
    if on then
        -- class "" is a window that hasn't said what it is yet; leave it
        if not w.floating and w.class and w.class ~= "" and not isMonocleExempt(w) then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
            hl.dispatch(hl.dsp.window.tag({ tag = "+monocle", window = addr }))
            sizeToFullFloat(w, mon)
        end
    elseif w.floating and hasTag(w, "monocle") then
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = addr }))
        hl.dispatch(hl.dsp.window.tag({ tag = "-monocle", window = addr }))
        stateOf(w.address).small = nil
    end
end

-- In monocle right now: floated by the monocle machinery. The tag alone
-- isn't enough -- monocleRule's tag is re-applied whenever Hyprland
-- re-evaluates a window's rules, so a tiled window on a workspace pinned to
-- dwindle can pick it up while monocle is the active workspace's layout.
-- Floating isn't re-applied that way; it's set once, at map time.
local function isMonocleWin(w)
    return w.floating and hasTag(w, "monocle")
end

local function onMonocleOpen(win)
    if not win then return end
    -- The rules follow the *active* workspace's layout, so a window that
    -- mapped somewhere else (a window-rules.json workspace entry, an app
    -- restoring its own session) can come up in the wrong one.
    --
    -- Only then, though. On the active workspace the rules were already
    -- right, and a window's own state isn't settled yet at this point:
    -- Quickshell's Settings/System windows map before their class and the
    -- quickshell-windows rule's float have landed, so they looked like a
    -- tiled app due for monocle and were blown up to full screen.
    local on = monocleOn(win.workspace)
    local active = hl.get_active_workspace()
    local elsewhere = win.workspace and active and win.workspace.id ~= active.id
    if elsewhere and on ~= isMonocleWin(win) and not (on and isMonocleExempt(win)) then
        setWindowMonocle(win, on, win.monitor)
        return
    end
    -- Only the windows monocleRule floated. Exempt ones -- Quickshell's own
    -- Settings/System/Keybinds windows, window-rules.json entries -- keep
    -- the size they open at.
    if on and hasTag(win, "monocle") then sizeToFullFloat(win) end
end
hl.on("window.open", onMonocleOpen)

-- SUPER+SHIFT+n and dragging between workspaces: the window takes on the
-- destination's layout. This fires before workspace.active does, so the
-- rules may still be set for the workspace it left -- which is fine, since
-- the conversion below is done by dispatch rather than by the rules.
hl.on("window.move_to_workspace", function(win, ws)
    if not win or not ws or ws.special then return end
    local on = monocleOn(ws)
    if on ~= isMonocleWin(win) then setWindowMonocle(win, on, ws.monitor or win.monitor) end
end)

local function maximizeFocused()
    local win = hl.get_active_window()

    -- A hidden window that gets focus by any route other than SUPER+C
    -- (ALT+Tab, the workspace overlay, its bar entry) is being asked for, so
    -- bring it back. Left to the refit below, a monocle window would come
    -- back on-screen but keep its stale minimized entry -- the next SUPER+C
    -- then took the restore branch and threw it to its old position -- and a
    -- window made small on purpose, which the refit skips, would stay hidden.
    -- Ahead of the monocle check since SUPER+C works in dwindle mode too.
    if win and stateOf(win.address).minimized then restoreMinimized(win) end

    if not win or not win.class or win.fullscreen ~= 0 then return end
    if not monocleOn(win.workspace) then return end

    if win.floating then
        -- Unlike a tiled window, Hyprland does not raise a floating one to the
        -- top of its own stack just because it got focus. Without this,
        -- alt-tab correctly changed which window has focus but whatever was
        -- already on top visually stayed there, covering it. Other floaters
        -- (dialogs, quickshell, thunar) are left alone, same as before --
        -- they're not part of the monocle stack, so there's no stacking order
        -- to fix for them.
        if hasTag(win, "monocle") then
            -- sizeToFullFloat() runs once, on open, so a window keeps the
            -- geometry the layout had at that moment. Sending it to a
            -- workspace on another monitor, or docking and undocking, leaves
            -- it fitted to a monitor it is no longer on. Re-fitting here
            -- catches that on the next focus whatever caused it, and backs up
            -- the monitor hooks below for the cases where Hyprland has not
            -- settled the new layout by the time those fire.
            local mon = win.monitor
            if mon and not stateOf(win.address).small and not isFitted(win, usableArea(mon)) then
                sizeToFullFloat(win, mon)
            end
            hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        end
        return
    end
    -- win.floating above is not enough on its own for a window that has
    -- just mapped: it races the quickshell-windows rule the same way the
    -- monocle rule's own `float = false` match does (see its comment above),
    -- and window.active can fire before that rule's `float = true` has
    -- landed. Caught here by class rather than waiting it out, since a
    -- Quickshell standalone window (Settings, System, Keybinds) sizes
    -- itself in QML and a maximize in that gap left it stuck rendering at
    -- its fixed content size inside a maximized surface -- cut off rather
    -- than centred.
    if win.class == "org.quickshell" then return end
    if stateOf(win.address).small then return end

    local mon = hl.get_active_monitor()
    if not mon then return end

    -- Testing the fullscreen *flag* above is not enough on its own: a window
    -- that is the only one on its workspace already fills the usable area
    -- while still reporting fullscreen=0, so a flag-only guard would
    -- re-maximize it every time it is focused. The geometry compare here
    -- catches that case so an already-full window does not animate and
    -- reflow its contents for no reason.
    if isAlreadyFull(win, mon) then return end

    hl.dispatch(hl.dsp.window.fullscreen({mode="maximized"}))
end

hl.on("window.active", maximizeFocused)

-- Closing is its own case: focus does not move until the closing window is
-- actually gone. window.active already covers the window that receives focus
-- next, but the sequencing around a close is Hyprland's internal detail, not
-- something to rely on -- re-checking explicitly here is what the old script's
-- --settle argument did, and needs no such flag now since there is no
-- subprocess spawn latency left for a window.active firing "too early" to
-- matter against.
hl.on("window.close", maximizeFocused)

-- window.close hands the closing window over, same as window.open does.
hl.on("window.close", function(win)
    if win then windowState[win.address] = nil end
end)

-- Docking, undocking, or changing a display's resolution or arrangement (the
-- Settings window's Display page writes those and reloads) moves and resizes
-- the monitors under every window that is already open. Monocle windows are
-- floating, so nothing re-lays them out: each keeps the rect it was given on
-- open, which now belongs to a monitor that has moved, shrunk or gone away --
-- windows sized for a large external display hang off the edge of a laptop
-- panel after undocking, and windows opened on the laptop stop short of
-- filling a bigger screen after docking.
--
-- The focus hook above re-fits one window at a time, but only once you get to
-- it; this puts them all right at the moment the layout changes, rather than
-- leaving a screen of wrong-sized windows to fix by visiting each. Windows
-- made small on purpose keep that size -- same rule as everywhere else.
local function refitMonocle()
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and hasTag(w, "monocle") and not stateOf(w.address).small and monocleOn(w.workspace) then
            local mon = w.monitor
            if mon and not isFitted(w, usableArea(mon)) then sizeToFullFloat(w, mon) end
        end
    end
end

-- All three, because they answer different questions and Hyprland does not
-- promise the layout has settled by the time any one of them fires: added and
-- removed catch a display appearing or going, layout_changed catches a
-- rearrangement of the ones already there (and fires last when a dock does
-- several of those at once).
hl.on("monitor.added", refitMonocle)
hl.on("monitor.removed", refitMonocle)
hl.on("monitor.layout_changed", refitMonocle)

-- Deliberately no window.fullscreen hook to force a window back to maximized
-- when it leaves that state. There used to be one, on the reasoning that
-- monocle means one window filling the screen with nothing to toggle to, but
-- it also swallowed SUPER+SHIFT+F: the unmaximize landed and was immediately
-- undone, so there was no way to make a window small on purpose.
--
-- toggleMaximize() below records deliberate shrinks in windowState so
-- maximizeFocused() leaves them alone, and double-clicking a titlebar (which
-- does not go through toggleMaximize) still gets re-maximized on the next
-- focus, via the window.active hook above -- matching the old behaviour.
--
-- That's still exactly right for a tiled window (an editor/browser in dwindle mode via maximize-primary-dwindle, or
-- anything while monocle is off): fullscreen's own toggle semantics do the
-- job. A floating-monocle window doesn't have an "unmaximize" to toggle --
-- it's just floating at whatever size sizeToFullFloat() gave it -- so for
-- those this shrinks to 70% centred instead, and grows back the same way
-- on the next press.
function toggleMaximize()
    local win = hl.get_active_window()
    if not win then return end

    if win.floating and hasTag(win, "monocle") then
        local addr = "address:" .. win.address
        if stateOf(win.address).small then
            sizeToFullFloat(win)
            stateOf(win.address).small = nil
        else
            local mon = win.monitor or hl.get_active_monitor()
            if not mon then return end
            local area = usableArea(mon)
            hl.dispatch(hl.dsp.window.resize({
                x = math.floor(area.w * 0.7), y = math.floor(area.h * 0.7), window = addr }))
            hl.dispatch(hl.dsp.window.center({ window = addr }))
            stateOf(win.address).small = true
        end
        return
    end

    hl.dispatch(hl.dsp.window.fullscreen({mode="maximized"}))

    -- Hyprland decides where the toggle actually lands (window rules and
    -- monocle's own maximize=true can override it), so read the state back
    -- rather than assume it went the way this predicted.
    -- by selector: hl.get_window() returns nil for a bare address
    local after = hl.get_window("address:" .. win.address)
    if after and after.fullscreen ~= 0 then
        stateOf(win.address).small = nil
    else
        stateOf(win.address).small = true
    end
end

-- Hides window below screen or restores it. Refocusing a hidden window any
-- other way restores it too -- see maximizeFocused() above.
function toggleMinimize()
    local win = hl.get_active_window()
    if not win then return end
    local st = stateOf(win.address)

    if st.minimized then
        restoreMinimized(win)
        return
    end

    -- window.move only places floating windows; on a tiled one (dwindle
    -- mode, or a monocle-exempt window) it does nothing, and recording a
    -- position anyway left the next press "restoring" a window that never
    -- moved. Say so rather than silently ignore the key.
    if not win.floating then
        hl.exec_cmd("notify-send -a Hyprland -t 3000 'Minimize' 'Only floating windows can be minimized'")
        return
    end

    local mon = win.monitor or hl.get_active_monitor()
    if not mon then return end
    st.minimized = { x = win.at.x, y = win.at.y }
    local belowScreen = mon.y + mon.height + 100
    hl.dispatch(hl.dsp.window.move({ x = win.at.x, y = belowScreen, window = "address:" .. win.address }))

    -- Moving it off-screen doesn't move focus, so keys would keep going to a
    -- window you can't see. Hand focus to the most recently used window left
    -- on this workspace instead -- never another hidden one, since focusing
    -- that would bring it straight back (see maximizeFocused() above). With
    -- nothing else there, focus stays put.
    local next
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= win.address and w.mapped and not w.hidden
                and w.workspace and win.workspace and w.workspace.id == win.workspace.id
                and not stateOf(w.address).minimized
                and (not next or w.focus_history_id < next.focus_history_id) then
            next = w
        end
    end
    if next then hl.dispatch(hl.dsp.focus({ window = "address:" .. next.address })) end
end

-- monocleRule and the dwindle maximize rule only act on windows as they
-- map, and new windows nearly always map on the active workspace -- so the
-- rules are switched to match whichever workspace is active, on every
-- workspace change as well as on SUPER+M. That's what lets a pinned
-- workspace get its own layout at map time, with no float-then-tile flicker.
-- The bar's layout toast is only told when the layout actually changes.
local rulesMonocle = nil
local function applyLayoutRules()
    local ws = hl.get_active_workspace()
    if ws and ws.special then return end
    local on = monocleOn(ws)
    monocleRule:set_enabled(on)
    maximizePrimaryDwindleRule:set_enabled(not on)
    if rulesMonocle ~= nil and rulesMonocle ~= on then
        hl.exec_cmd("qs ipc call layout set " .. (on and "monocle" or "dwindle"))
    end
    rulesMonocle = on
end
applyLayoutRules()
hl.on("workspace.active", applyLayoutRules)

-- SUPER+M switches between monocle and dwindle everywhere that isn't
-- pinned. monocleRule only applies to windows as they map, so switching
-- also has to walk every window already open on the workspace -- otherwise
-- only new windows would notice the change. On a pinned workspace nothing
-- here moves; the toast says it's pinned instead of claiming a switch.
-- Global, like toggleMaximize(), so SUPER+M up in the keybinds can reach it.
function toggleLayout()
    monocleEnabled = not monocleEnabled

    local ws = hl.get_active_workspace()
    local pin = ws and workspaceLayouts[tostring(ws.id)]
    if pin then
        hl.exec_cmd("notify-send -a Hyprland -t 3000 'Layout' 'Workspace " .. ws.id
            .. " is pinned to " .. (pin == "monocle" and "monocle" or "tiled")
            .. "; the others switched'")
        return
    end

    rulesMonocle = nil   -- always announce this one
    applyLayoutRules()

    local win = hl.get_active_window()
    if not win or not win.workspace then return end
    local mon = win.monitor or hl.get_active_monitor()
    for _, w in ipairs(win.workspace:get_windows()) do
        setWindowMonocle(w, monocleEnabled, mon)
    end
end
