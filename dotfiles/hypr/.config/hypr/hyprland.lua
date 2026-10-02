-- Singularity - Hyprland
-- ~/.config/hypr/hyprland.lua
--
-- Lua config; Hyprland loads this in preference to the deprecated
-- hyprland.conf.
--
-- grayscale ramp, shared with every other config in this repo:
--   #0b0b0b base   #121212 bar    #1a1a1a surface  #242424 overlay
--   #303030 border #4d4d4d muted  #7a7a7a subtext  #d0e2fa text
--   #ebebeb bright

-- Forward-declared so the binds below can close over them ahead of their
-- definitions in Window Rules. Without these `local`s the later assignments
-- would be globals and the binds would call nil.
local toggleMaximize
local toggleMinimize
local toggleScratchpad
local toggleStashed

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
-- isn't running. pkill first so a second press dismisses wofi rather than
-- stacking another. Its stylesheet is Quickshell's copy with the bar's corner
-- radius applied (AppearanceSync.qml), else the repo's own.
local menu        = "qs ipc call launcher toggle apps || pkill wofi || { s=~/.local/state/singularity/wofi.css; [ -r \"$s\" ] || s=~/.config/wofi/style.css; wofi --show drun --style \"$s\"; }"

-- Animation time from the bar's Appearance page. Quickshell writes it to a
-- state file and runs `hyprctl reload config-only`, which re-runs this file --
-- so the setting survives a restart without the repo's config being
-- rewritten. It's a percentage of each speed below (speed is a duration, so
-- 50 is twice as quick), and 0 turns animations off entirely. The words
-- "normal", "fast" and "off" are the older form of the same file.
local function singularityState(name, default)
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/" .. name)
    if not f then return default end
    local v = f:read("l")
    f:close()
    return v or default
end
local animTime   = singularityState("animations", "100")
local animFactor = math.max(0, math.min(100,
    tonumber(animTime) or ({ normal = 100, fast = 50, off = 0 })[animTime] or 100)) / 100
local animOff    = animFactor == 0

-- How windows open, close, minimize and restore, picked on the Appearance
-- page. "fade" is popin at full size, so the window only fades, and "none"
-- shows and hides them at once. SUPER+C follows the same choice by hand; see
-- toggleMinimize() below.
local windowStyles = {
    popin = "popin 92%", zoom = "popin 70%", fade = "popin 100%", fold = "gnomed",
    slide = "slide", rise = "slide bottom", drop = "slide top", none = "popin 100%",
}
local windowAnim   = singularityState("window-anim", "popin")
if not windowStyles[windowAnim] then windowAnim = "popin" end
local windowStyle    = windowStyles[windowAnim]
local windowsAnimate = windowAnim ~= "none"
-- SUPER+C's version: the styles that move the window off-screen (up for
-- drop, down for the others), and the size the rest shrink to as they fade,
-- as fractions of width and height (fold collapses to a line, as gnomed does)
local windowSlides = windowAnim == "slide" or windowAnim == "rise" or windowAnim == "drop"
local windowShrink = ({ popin = { 0.92, 0.92 }, zoom = { 0.7, 0.7 }, fold = { 1, 0.05 } })[windowAnim]

-- The scratchpad (SUPER+grave) is a special workspace, and a workspace can
-- only slide or fade, so the styles that don't slide show it as a fade.
local scratchStyle = windowSlides and "slidevert" or "fade"

-- "<active> <inactive>" border colours, written by the Appearance page when
-- borders follow the shell's accent; otherwise absent, and the colours
-- under general below apply.
local borderActive, borderInactive = singularityState("borders", ""):match("^(%S+)%s+(%S+)$")

-- "<active tab> <inactive tab> <active text> <inactive text> <accent>" for
-- the tab bar over grouped windows (see TABS below), written by the
-- Appearance page from the current look; absent, the colours under group
-- below apply.
local tabActive, tabInactive, tabText, tabTextInactive, tabAccent =
    singularityState("groupbar", ""):match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$")

-- Window corner radius, written by the Appearance page from the shell's panel
-- corners so windows and panels round alike; absent, 6.
local windowRounding = tonumber(singularityState("rounding", "")) or 6

-- "<border width> <shadow>" from the Appearance page's style: the border
-- as thick as the shell's strokes, and its shadow ("none", "soft", "hard")
local windowBorder, windowShadow = singularityState("window-frame", ""):match("^(%d+)%s+(%a+)$")
windowBorder = tonumber(windowBorder) or 1
windowShadow = windowShadow or "soft"
local hardShadow = windowShadow == "hard"

-- The open tab's fill, with a line of the accent along its top edge. The
-- groupbar has no colour of its own for that line (its indicator shares the
-- fill's colour), so it's the last stops of a vertical gradient: the last
-- two of twenty are the accent, a line about 2px thick on a 26px bar.
local function tabFill(fill, accent)
    local colors = {}
    for i = 1, 18 do colors[i] = fill end
    colors[19], colors[20] = accent, accent
    return { colors = colors, angle = 270 }
end

local function animation(t)
    t.speed   = t.speed * animFactor
    t.enabled = t.enabled and not animOff
    hl.animation(t)
end

------------------
---- MONITORS ----
------------------

-- The built-in panel switched off while the lid is shut on a docked laptop,
-- so every workspace moves to the other displays as if the panel weren't
-- there. lid.sh decides when: it writes the panel's name to this file and
-- reloads, and removes it and reloads when the lid opens (the reload
-- restores the panel's own rule). Called after the rules, so it wins.
local function panelOffWhileLidShut()
    local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-lid-docked")
    if not f then return end
    local panel = f:read("l")
    f:close()
    if panel and panel ~= "" then hl.monitor({ output = panel, disabled = true }) end
end

-- The Display page's rules for this machine's displays, in the state
-- directory since they differ per machine. Until it has saved any, one rule
-- for every display: empty output matches them all, which suits a laptop
-- that gets docked. The page copies this rule to start the file.
-- scale 1 is native resolution: everything as small as the panel can draw it.
-- "auto" picks a HiDPI factor on a dense laptop panel, which makes the whole
-- desktop look oversized. Nudge to 1.25 or 1.5 if 1 is too small; fractional
-- values below 1 are not supported.
if not pcall(dofile, os.getenv("HOME") .. "/.local/state/singularity/monitors.lua") then
    hl.monitor({
        output   = "",
        mode     = "preferred",
        position = "auto",
        scale    = 1,
    })
end

panelOffWhileLidShut()

-- Primary display, picked on the Settings window's Display page and handed
-- over the same way as Animation Speed: a state file read here, then a
-- config-only reload. Workspace 1 lives on it, the cursor starts on it, and
-- duplicate mode copies it. Empty (the default) leaves all of that to
-- Hyprland, which uses the first display it finds.
--
-- The workspace rule only decides where workspace 1 is *created*, so a
-- workspace that already exists stays put. The Settings page moves it itself
-- when the choice changes, and singularityResetWorkspaces() below does on
-- docking.
local primaryDisplay = singularityState("primary-display", "")
if primaryDisplay ~= "" then
    hl.config({ cursor = { default_monitor = primaryDisplay } })
    hl.workspace_rule({ workspace = "1", monitor = primaryDisplay, default = true })
end

-- One workspace per display, numbered from the primary: 1 on the primary,
-- 2 on the next display along (left to right, then top to bottom), and so
-- on. Every other workspace is gathered onto the primary. A global so the
-- Display page's "Reset workspaces" can run it through `hyprctl eval`.
function singularityResetWorkspaces()
    local mons = hl.get_monitors()
    if #mons == 0 then return end
    local primary = mons[1]
    for _, m in ipairs(mons) do
        if m.name == primaryDisplay then primary = m end
    end
    local order = {}
    for _, m in ipairs(mons) do
        if m ~= primary then order[#order + 1] = m end
    end
    table.sort(order, function(a, b) return a.x < b.x or (a.x == b.x and a.y < b.y) end)
    table.insert(order, 1, primary)

    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.id > #order and ws.monitor and ws.monitor.name ~= primary.name then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(ws.id), monitor = primary.name }))
        end
    end
    -- Backwards, so the primary is focused last. A workspace that doesn't
    -- exist yet is created on whichever display has focus.
    for i = #order, 1, -1 do
        local name = order[i].name
        if hl.get_workspace(i) then
            hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(i), monitor = name }))
        else
            hl.dispatch(hl.dsp.focus({ monitor = name }))
        end
        hl.dispatch(hl.dsp.focus({ workspace = i }))
    end
end

-- Layer surfaces -- the bar, the wallpaper -- are only placed again when a
-- monitor rule moves a display, not when Hyprland slides one over because
-- another came or went, so the bar is left mid-screen or off it. A rule
-- moving each display one pixel, at its current mode and scale so nothing
-- modesets, followed by a reload back to the real rules, puts them right.
-- lid.sh runs both after every change of displays.
function singularityNudgeDisplays()
    for _, m in ipairs(hl.get_monitors()) do
        if not m.is_mirror then
            hl.monitor({
                output    = m.name,
                mode      = string.format("%dx%d@%.3f", m.width, m.height, m.refresh_rate),
                position  = (m.x + 1) .. "x" .. m.y,
                scale     = m.scale,
                transform = m.transform,
            })
        end
    end
end

-- A display plugged in (or the panel back on as the lid opens) lays the
-- workspaces out afresh. Plugging or unplugging one with the lid shut is
-- lid.sh's to handle: it switches the panel off or back on to match.
--
-- Run from a timer rather than inside the event: a display is added before
-- its workspace exists, and focusing it then crashes Hyprland. At launch
-- that is every display, so hyprland.start (see AUTOSTART below) queues it
-- the same way.
local function resetWorkspacesSoon()
    hl.timer(function() singularityResetWorkspaces() end, { timeout = 500, type = "oneshot" })
end
hl.on("monitor.added", function()
    resetWorkspacesSoon()
    hl.exec_cmd("~/.config/hypr/lid.sh displays")
end)
hl.on("monitor.removed", function()
    hl.exec_cmd("~/.config/hypr/lid.sh displays")
end)

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
-- The pointer and icon themes picked on the Appearance page, which writes
-- them to state files like the animation speed above.
local cursorTheme, cursorSize = singularityState("cursor", ""):match("^(%S+)%s+(%d+)$")
cursorTheme = cursorTheme or "Bibata-Modern-Classic"
cursorSize  = cursorSize or "20"
local iconTheme = singularityState("icons", "kora")
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_SIZE", cursorSize)
-- Icon theme for Quickshell's window icons and Applications list. GTK and
-- wofi get it from gsettings, but Quickshell is Qt and Qt has no theme
-- configured here, so without this it falls back to each app's stock
-- hicolor icon (Thunar's hammer instead of kora's folder). It has to be in
-- the environment at launch: Quickshell reads it before its own
-- `//@ pragma Env` lines are applied, so setting it from shell.qml is ignored.
hl.env("QS_ICON_THEME", iconTheme)

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    resetWorkspacesSoon()
    -- Not UWSM, so graphical-session.target is never reached, and units
    -- that hang off it (rather than D-Bus activation) have to be started by
    -- hand. Starting the unit rather than the binary keeps its
    -- respawn-on-crash and cgroup.
    --
    -- reset-failed first: after Hyprland crashes and is restarted, the unit
    -- has usually hit its start limit respawning into a missing Wayland
    -- socket, and a plain `start` is then refused.
    hl.exec_cmd("systemctl --user reset-failed hyprpolkitagent.service; systemctl --user start hyprpolkitagent.service")
    -- Same for hypridle; the fallback runs it bare if the unit is missing.
    hl.exec_cmd("systemctl --user reset-failed hypridle.service; systemctl --user start hypridle.service || hypridle")
    -- Stop logind suspending on lid close: the lid binds below just blank the
    -- screen, and hypridle suspends after 20 min idle. Released when
    -- Hyprland exits.
    hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --who=Hyprland --why='Hyprland handles the lid' tail --pid=$(pidof -s Hyprland) -f /dev/null")
    -- QML warnings go to a log rather than the TTY. `exec` replaces the
    -- /bin/sh that hl.exec_cmd wraps this in, so no idle shell sits in the
    -- tree as quickshell's parent (same for the relay below).
    hl.exec_cmd("exec quickshell > ~/.cache/quickshell.log 2>&1")
    -- The ALT+Tab switcher's IPC relay (alttab-relay.cpp). It finds
    -- Quickshell lazily, so order doesn't matter. QT_FORCE_STDERR_LOGGING
    -- keeps its self-test messages in the log file rather than the journal.
    hl.exec_cmd("exec env QT_FORCE_STDERR_LOGGING=1 ~/.config/hypr/alttab-relay > ~/.cache/alttab-relay.log 2>&1")
    -- env alone does not retheme the cursor Hyprland draws over the desktop
    hl.exec_cmd("hyprctl setcursor " .. cursorTheme .. " " .. cursorSize)
    -- the saved wallpaper, or a random one from wallpapers/ when shuffle is on
    hl.exec_cmd("~/.config/hypr/wallpaper.sh")
    -- clipboard history daemon (cliphist needs this to capture every copy)
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- XDG autostart, which Hyprland does not run itself: the .desktop files
    -- in ~/.config/autostart, managed from Settings > Startup. Last, so a
    -- user entry starts against a session that already has its bar, its
    -- notification daemon and its wallpaper -- an entry that opens a window
    -- otherwise races the bar for the screen. See the script's header for
    -- which entries it runs and why a package's own entry is opt-in.
    hl.exec_cmd("~/.config/singularity/autostart.sh run")
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- The tab bar over grouped windows. A floating group draws it above the
-- windows, flush against them, so fillArea() below leaves this much room for
-- it.
local GROUPBAR_HEIGHT = 26

hl.config({
    general = {
        gaps_in     = 1,
        gaps_out    = 0,
        border_size = windowBorder,

        col = {
            active_border   = borderActive or "rgba(d0e2fa66)",
            inactive_border = borderInactive or "rgba(303030aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = windowRounding,
        rounding_power   = 2,
        active_opacity   = 1,
        inactive_opacity = 1,
        dim_inactive = true,
        dim_strength = 0.1,

        -- soft: black at 40 percent, blurred; hard: a solid offset copy
        shadow = {
            enabled      = windowShadow ~= "none",
            range        = hardShadow and 2 or 18,
            render_power = hardShadow and 1 or 3,
            offset       = hardShadow and "4 4" or "0 0",
            color        = hardShadow and "rgba(000000ff)" or "rgba(00000066)",
        },

        blur = {
            enabled    = true,
            size       = 12,
            passes     = 2,
            noise      = 0.015,
            contrast   = 0.9,
            brightness = 0.7,
        },
    },

    animations = {
        enabled = not animOff,
    },

    dwindle = {
        preserve_split = true,
    },

    -- Groups are only made by the TABS hooks below, so a new window never
    -- joins whichever group has focus, and dragging one never merges it in.
    group = {
        auto_group      = false,
        drag_into_group = 0,
        -- the tab fills, so the border runs on from the tab bar instead of
        -- drawing an accent line between it and the window
        col = {
            border_active   = tabActive or "rgba(2a2a2aff)",
            border_inactive = tabInactive or "rgba(161616ff)",
        },
        groupbar = {
            height              = GROUPBAR_HEIGHT,
            -- tabs edge to edge: -1 rather than 0, since tab widths are
            -- fractional and 0 leaves a hairline between them
            gaps_in             = -1,
            gaps_out            = 0,
            font_family         = "UbuntuMono Nerd Font",
            font_size           = 13,
            -- room either side, so a long title's "…" isn't against the edge
            text_padding        = 10,
            gradients           = true,
            rounding            = 3,
            gradient_rounding   = 3,
            indicator_height    = 0,
            middle_click_close  = true,
            text_color          = tabText or "rgba(d0e2faff)",
            text_color_inactive = tabTextInactive or "rgba(7a7a7aff)",
            col = {
                active   = tabFill(tabActive or "rgba(2a2a2aff)", tabAccent or "rgba(d0e2faff)"),
                inactive = tabInactive or "rgba(161616ff)",
            },
        },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- any key or mouse movement turns a blanked screen back on, whatever
        -- blanked it -- not only hypridle's own screens-off step
        key_press_enables_dpms  = true,
        mouse_move_enables_dpms = true,
    },

    -- A fullscreen game's frames go straight to the display, skipping
    -- compositing; 2 limits it to windows tagged as games, where 1 (every
    -- fullscreen window) can flicker on some apps.
    render = {
        direct_scanout = 2,
    },
})

hl.curve("singularity", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })

-- speed is in 100ms units (3 = 300ms), so lower is faster
-- SUPER+C times its hand-made animations by these; see toggleMinimize() below
local windowSpeed = 2
local fadeSpeed = 1.5
animation({ leaf = "global",     enabled = true, speed = 3, bezier = "singularity" })
animation({ leaf = "border",     enabled = true, speed = 3, bezier = "singularity" })
animation({ leaf = "windows",    enabled = true, speed = windowSpeed, bezier = "singularity", style = windowStyle })
animation({ leaf = "windowsIn",  enabled = windowsAnimate, speed = windowSpeed, bezier = "singularity", style = windowStyle })
animation({ leaf = "windowsOut", enabled = windowsAnimate, speed = 1.5, bezier = "singularity", style = windowStyle })
animation({ leaf = "fade",       enabled = true, speed = fadeSpeed, bezier = "singularity" })
animation({ leaf = "fadeIn",     enabled = windowsAnimate, speed = fadeSpeed, bezier = "singularity" })
animation({ leaf = "fadeOut",    enabled = windowsAnimate, speed = fadeSpeed, bezier = "singularity" })
animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "singularity", style = "slidefade 12%" })
animation({ leaf = "specialWorkspace", enabled = windowsAnimate, speed = windowSpeed, bezier = "singularity",
            style = scratchStyle })

-- Layer surfaces: wofi and the bar's flyouts. Faster than `global`, which
-- they'd otherwise inherit, since a launcher should appear at once. fade
-- rather than popin, since the bar is a layer too.
animation({ leaf = "layersIn",  enabled = true, speed = 1, bezier = "singularity", style = "fade" })
animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "singularity", style = "fade" })

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

-- Swipe left, go left: uninverted, to match natural_scroll = false above.
hl.config({
    gestures = {
        workspace_swipe_invert = false,
    },
})

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
-- Maximize goes through toggleMaximize() (Window Rules) so that shrinking a
-- window on purpose sticks: it records the choice, and the focus hook that
-- re-maximizes in monocle leaves such windows alone. Wrapped in closures
-- because the function is assigned further down.
hl.bind(mod .. " + X", function() toggleMaximize() end)  -- Maximize or restore window
hl.bind(mod .. " + CTRL + F",  hl.dsp.window.fullscreen())  -- Fullscreen window, covering the bar
-- same action as double-clicking a window's titlebar
hl.bind(mod .. " + equal",     function() toggleMaximize() end)  -- Maximize or restore window
hl.bind(mod .. " + C",         function() toggleMinimize() end)  -- Minimize or restore window
hl.bind(mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))  -- Float or tile window
hl.bind(mod .. " + P",         hl.dsp.window.pseudo())  -- Keep window's own size in its tile
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"))  -- Split side by side or stacked
hl.bind(mod .. " + M",         function() toggleLayout() end)  -- Switch between tiled and one-window layout

-- --- Scratchpad ---
-- A terminal on its own special workspace, floating over whichever workspace
-- you're on. The first press starts it; after that the key shows and hides it.
-- SHIFT stashes the focused window there as well, to be shown with it, and
-- on a window already in the scratchpad puts it back on the workspace below.
hl.bind(mod .. " + grave", function() toggleScratchpad() end)  -- Show or hide the scratchpad
hl.bind(mod .. " + SHIFT + grave", function() toggleStashed() end)  -- Move window into or out of the scratchpad

-- --- Show desktop ---
-- Hides every window on the workspace as SUPER+C does, so they stay on it
-- and in the bar's window strip; the next press brings them back. See
-- singularityShowDesktop() below.
hl.bind(mod .. " + D", function() singularityShowDesktop() end)  -- Show the desktop, or bring its windows back

-- --- Notes ---
-- Quickshell's sticky notes (windows/NotesWindow.qml), pinned in the
-- top-right corner over every workspace; see the "notes" rule below
hl.bind(mod .. " + N", hl.dsp.exec_cmd("qs ipc call notes toggle"))  -- Show or hide sticky notes

-- --- Focus ---
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))  -- Focus window to the left
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))  -- Focus window to the right
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))  -- Focus window above
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))  -- Focus window below

-- --- Move & resize ---
-- moveWindowDir() and friends, below: tiled windows move, swap and resize
-- in the layout, floating ones are nudged 40px at a time.
hl.bind(mod .. " + SHIFT + left",  function() moveWindowDir("left") end,  { repeating = true })  -- Move window left
hl.bind(mod .. " + SHIFT + right", function() moveWindowDir("right") end, { repeating = true })  -- Move window right
hl.bind(mod .. " + SHIFT + up",    function() moveWindowDir("up") end,    { repeating = true })  -- Move window up
hl.bind(mod .. " + SHIFT + down",  function() moveWindowDir("down") end,  { repeating = true })  -- Move window down
hl.bind(mod .. " + ALT + left",  function() swapWindowDir("left") end)  -- Swap with the window to the left
hl.bind(mod .. " + ALT + right", function() swapWindowDir("right") end)  -- Swap with the window to the right
hl.bind(mod .. " + ALT + up",    function() swapWindowDir("up") end)  -- Swap with the window above
hl.bind(mod .. " + ALT + down",  function() swapWindowDir("down") end)  -- Swap with the window below
hl.bind(mod .. " + CTRL + left",  function() resizeWindowDir("left") end,  { repeating = true })  -- Resize window: move its edge left
hl.bind(mod .. " + CTRL + right", function() resizeWindowDir("right") end, { repeating = true })  -- Resize window: move its edge right
hl.bind(mod .. " + CTRL + up",    function() resizeWindowDir("up") end,    { repeating = true })  -- Resize window: move its edge up
hl.bind(mod .. " + CTRL + down",  function() resizeWindowDir("down") end,  { repeating = true })  -- Resize window: move its edge down
hl.bind(mod .. " + O", function() sendToNextMonitor() end)  -- Send window to the next monitor

-- Windows-style alt-tab, with the switcher drawn by Quickshell
-- (AltTabSwitcher.qml). Hold ALT and tap Tab to move the highlight, release
-- ALT to focus what you landed on.
--
-- Nothing is focused until the release. Hyprland's own cycle_next focuses as
-- it walks, so previewing a window meant raising it and resizing the layout;
-- keeping the selection in Quickshell makes stepping free, and gives
-- SHIFT+Tab a working reverse direction, which the dispatcher never had.
--
-- There is no submap: Hyprland (0.56.2) never delivers a modifier release
-- to a submap bind. The switcher takes the keyboard itself and catches the
-- release in Keys.onReleased, and with no submap there's no mode for the
-- keyboard to get stuck in.
--
-- Every Tab of a held ALT+Tab comes through these binds, not just the first:
-- Hyprland matches its own binds before forwarding keys to any client, so they
-- win over the switcher's keyboard grab and Keys.onPressed never sees a Tab.
-- The shell's onAltTabTab is idempotent to suit -- it opens the switcher on
-- the first Tab and steps it on the ones after. SHIFT+Tab and grave need their own
-- binds for the same reason; they would otherwise never reach the shell.
-- `repeating` on each so holding the key autorepeats.
--
-- alttab-ipc.sh reaches the shell through alttab-relay (started above),
-- which also reads the window list from Hyprland; `qs ipc call` (~45ms just
-- to start) is only the fallback. See alttab-relay.cpp.
--
-- The ALT release is also watched here, in-process. The switcher's grab
-- only sees a release that happens after it is up, and an ALT let go while
-- the first Tab is still on its way would otherwise reach no one, leaving
-- the switcher holding the keyboard. hl.is_key_down reads Hyprland's own key
-- state, so altTabWatch polls it from the moment the bind fires and sends
-- the commit when ALT comes up. Keys.onReleased stays the fast path;
-- whichever notices first wins, and the shell drops the second.
--
-- Chained oneshots rather than a `repeat` timer: a Lua timer only stops
-- once collected, so a repeating one fires on long after it's wanted.
--
-- Each gesture gets a generation number, sent with every command, so the
-- shell matches a release to the exact Tab it belongs to and never opens a
-- switcher for a gesture whose ALT is already up. It also retires any chain
-- left over from an earlier gesture.
local altTabWatchGen = 0
local altTabWatchTimer = nil

-- `sends` counts commits already sent for this release. Two extras follow
-- the first, as insurance against it being lost while the Tab is still in
-- flight; the shell drops repeats for a gesture it has committed.
local function altTabWatch(gen, sends)
    if gen ~= altTabWatchGen then return end

    if hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R") then
        altTabWatchTimer = hl.timer(function() altTabWatch(gen, 0) end,
            { timeout = 24, type = "oneshot" })
        return
    end

    hl.exec_cmd("~/.config/hypr/alttab-ipc.sh commit " .. gen)

    if sends >= 2 then
        altTabWatchTimer = nil
        return
    end

    altTabWatchTimer = hl.timer(function() altTabWatch(gen, sends + 1) end,
        { timeout = 90, type = "oneshot" })
end

-- Armed by every alt-tab bind, retiring the previous chain. The generation
-- is bumped before the command runs, so both carry the same id.
local function altTabKey(cmd)
    return function()
        altTabWatchGen = altTabWatchGen + 1
        local gen = altTabWatchGen
        hl.exec_cmd(cmd .. " " .. gen)
        altTabWatchTimer = hl.timer(function() altTabWatch(gen, 0) end,
            { timeout = 24, type = "oneshot" })
    end
end

hl.bind("ALT + Tab",         altTabKey("~/.config/hypr/alttab-ipc.sh tab"),  { repeating = true })  -- Switch windows
hl.bind("ALT + SHIFT + Tab", altTabKey("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards
hl.bind("ALT + grave",       altTabKey("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards

-- Not a bare Alt_L/Alt_R `global` bind for the release: that changes how
-- Hyprland treats ALT everywhere, including the drag/resize mod.

-- --- Tabs ---
-- For the apps opened as tabs (TABBED_CLASSES under WINDOW RULES), and only
-- while one has focus: the TABS hooks turn these off for anything else, so
-- other apps keep the keys (a browser's own CTRL+Tab).
local tabNextBind  = hl.bind("CTRL + Tab",         hl.dsp.group.next())  -- Next tab
local tabPrevBind  = hl.bind("CTRL + SHIFT + Tab", hl.dsp.group.prev())  -- Previous tab
local tabCloseBind = hl.bind(mod .. " + SHIFT + Q", function() closeAllTabs() end)  -- Close all tabs

-- --- Workspaces ---
-- Workspace grid: every workspace and its windows at once. Click a cell to
-- jump, click a window to focus it, drag a window between cells to move it.
-- Drawn by Quickshell (WorkspaceOverlay.qml), so this only pokes the shell.
hl.bind(mod .. " + W", hl.dsp.exec_cmd("qs ipc call overlay toggle"))  -- Show all workspaces
for i = 1, MAX_WORKSPACES do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- --- Mouse ---
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })  -- Move window by dragging
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })  -- Resize window by dragging

-- --- Clipboard ---
hl.bind(mod .. " + H", hl.dsp.exec_cmd("qs ipc call launcher toggle clipboard"))  -- Clipboard history

-- --- Calculator and file search ---
-- Two more launcher modes (flyouts/Launcher.qml). Tab cycles between all
-- four, so either key reaches the others; these are just the direct ways in.
hl.bind(mod .. " + slash", hl.dsp.exec_cmd("qs ipc call launcher toggle calc"))   -- Calculator
hl.bind(mod .. " + S",     hl.dsp.exec_cmd("qs ipc call launcher toggle files"))  -- Search files

-- --- Claude ---
-- Quickshell's Claude flyout (flyouts/ClaudeFlyout.qml)
hl.bind(mod .. " + I", hl.dsp.exec_cmd("qs ipc call claude toggle"))  -- Ask Claude to change the desktop

-- --- Shell windows ---
-- The bar's standalone windows; an empty page opens each on its default page
hl.bind(mod .. " + comma",  hl.dsp.exec_cmd("qs ipc call settings open ''"))  -- Open Settings
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("qs ipc call system open ''"))    -- Open System
hl.bind(mod .. " + K",      hl.dsp.exec_cmd("qs ipc call keybinds open"))     -- Open Keybinds

-- --- Session ---
-- Through logind so hypridle's lock_cmd runs it: one hyprlock at a time, and
-- the refocus on unlock
hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))  -- Lock the screen
-- lock, suspend, log out, reboot, shut down; flyouts/PowerMenu.qml
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("qs ipc call power menu"))  -- Open the power menu

-- --- Screenshot ---
-- saves to ~/Pictures/Screenshots and copies to the clipboard
hl.bind("Print",         hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh area"))    -- Screenshot an area
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh window"))  -- Screenshot the active window
hl.bind("CTRL + Print",  hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh screen"))  -- Screenshot the focused monitor
hl.bind("ALT + Print",   hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh text"))    -- Copy the text in an area
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/hypr/screenshot.sh text"))  -- Copy the text in an area

-- --- Lid ---
-- Close turns the screen off and suspends after 5 min if it's still shut;
-- open turns it back on and cancels that. logind's own lid handling is
-- inhibited in autostart so this is the only thing acting on the lid. All of
-- it -- the debounce for this laptop's bouncing lid switch, the suspend
-- timer, re-suspending after a wake with the lid shut, docked mode -- lives
-- in lid.sh. misc:key_press_enables_dpms and mouse_move_enables_dpms are the
-- backstop: any key or mouse movement wakes a wrongly-blanked screen. lid.sh
-- turns both off while the lid is shut, or the keyboard and touchpad the
-- closing lid presses on would wake the panel it just blanked.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid closed: screen off, suspend after 5 min
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid opened: screen on

-- --- Function Keys ---
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })  -- Volume up
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })  -- Volume down
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })  -- Mute or unmute sound
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })  -- Mute or unmute microphone
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/brightness.sh up"),                { locked = true, repeating = true })  -- Brightness up
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/brightness.sh down"),              { locked = true, repeating = true })  -- Brightness down

-- --- Media Keys ---
-- Drive the player the bar's media module follows (services/Media.qml)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("qs ipc call media toggle"),   { locked = true })  -- Play or pause media
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call media pause"),    { locked = true })  -- Pause media
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("qs ipc call media stop"),     { locked = true })  -- Stop media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("qs ipc call media next"),     { locked = true })  -- Next track
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("qs ipc call media previous"), { locked = true })  -- Previous track

-- --- Lock Keys ---
-- Pass-through: the key still toggles its lock as usual, and the shell shows
-- the new state in a toast (shell.qml's "locks" handler). On press: a release
-- bind on these keys never fires.
hl.bind("Caps_Lock", hl.dsp.exec_cmd("qs ipc call locks changed caps"), { non_consuming = true })  -- Show Caps Lock state
hl.bind("Num_Lock",  hl.dsp.exec_cmd("qs ipc call locks changed num"),  { non_consuming = true })  -- Show Num Lock state

----------------------
---- WINDOW RULES ----
----------------------

-- Deliberately NOT suppressing maximize events (Hyprland's example config
-- does): that's what double-clicking a titlebar sends. On a floating window
-- the window.fullscreen hook turns it into a fill; see fillFloating().

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

-- A link opened from another app lands in a new Floorp tab, which Floorp
-- selects and then asks to be activated. Hyprland ignores activation
-- requests by default (misc:focus_on_activate); this honours Floorp's, so
-- its window comes to the front showing that tab.
hl.window_rule({
    name  = "floorp-focus-on-activate",
    match = { class = "^(floorp)$" },
    focus_on_activate = true,
})

-- The other way round: a download opened from the browser goes to its app,
-- which asks to be activated, and Hyprland only marks it urgent. While a
-- browser has focus, honour that request too, so an app that was already
-- open comes to the front with the file.
local BROWSER_CLASSES = { ["zen"] = true, ["zen-browser"] = true, ["floorp"] = true, ["firefox"] = true }
hl.on("window.urgent", function(win)
    local active = hl.get_active_window()
    if not win or not active or win.address == active.address then return end
    if not BROWSER_CLASSES[active.class] or BROWSER_CLASSES[win.class] then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
end)

-- Monocle. Hyprland ships dwindle and master only, with no monocle layout,
-- so this emulates one: dwindle stays the underlying layout, but every
-- window that would tile is floated and sized to fill the usable area
-- instead of maximized.
--
-- Floating rather than maximized: Hyprland allows one maximized window per
-- workspace, so only the focused one could be full and switching would
-- resize. Floaters each keep their own geometry, so switching is a raise.
--
-- The "+monocle" tag (taken off again by "-monocle" on the rules below)
-- tells the window.open hook which windows it owns, without repeating
-- those rules' matches here.
local monocleRule = hl.window_rule({
    name  = "monocle",
    match = { float = false },
    float = true,
    maximize = false,
    tag = "+monocle",
})

-- The gap general.gaps_out leaves at the screen's edges, which monocle
-- windows keep clear of like tiled ones: { top, right, bottom, left }.
local function edgeGaps()
    local g = hl.get_config("general.gaps_out")
    if type(g) ~= "table" then return { top = 0, right = 0, bottom = 0, left = 0 } end
    return { top = g.top or 0, right = g.right or 0, bottom = g.bottom or 0, left = g.left or 0 }
end

-- With no gap, a monocle window runs to the screen's edges, where rounded
-- corners would only show slivers of wallpaper and border; it stays square.
local gaps = edgeGaps()
if gaps.top == 0 and gaps.right == 0 and gaps.bottom == 0 and gaps.left == 0 then
    hl.window_rule({
        name     = "monocle-square",
        match    = { tag = "monocle" },
        rounding = 0,
    })
end

-- The bar's standalone windows (System, Keybinds, Settings): Quickshell
-- FloatingWindows, class org.quickshell, which size themselves in QML. They
-- float centred at that size -- no size here.
--
-- maximize = false and coming *after* the monocle rule are both
-- load-bearing: at map time these aren't floating yet, so monocle matches
-- them too, and the later rule wins.
hl.window_rule({
    name     = "quickshell-windows",
    tag      = "-monocle",
    match    = { class = "^(org\\.quickshell)$", title = "negative:^(Notes)$" },
    float    = true,
    center   = true,
    maximize = false,
    -- Intentionally no size constraint — QML code defines window dimensions
})

-- The sticky notes (SUPER+N): one of the shell's windows too, but pinned so
-- it stays up across workspace switches, and opened in the top-right corner
-- instead of centred. Placed by the rule rather than moved from a
-- window.open hook: moving a pinned window as it maps crashes Hyprland.
-- A rule's position ignores the bar's reserved space, so clearing a top bar
-- takes its extent from the bar-top state file, which Quickshell rewrites
-- (and reloads this config) whenever the bar moves or changes size.
local NOTES_MARGIN = 8
local function notesTop()
    return (tonumber(singularityState("bar-top", "32")) or 32) + NOTES_MARGIN
end
hl.window_rule({
    name     = "notes",
    tag      = "-monocle",
    match    = { class = "^(org\\.quickshell)$", title = "^(Notes)$" },
    float    = true,
    pin      = true,
    maximize = false,
    move     = "monitor_w-window_w-" .. NOTES_MARGIN .. " " .. notesTop(),
})

-- The scratchpad terminal (SUPER+grave): opens straight onto the special
-- workspace, floating and centred. Out of monocle for the same reason as the
-- shell's windows above -- its open hook would stretch it to fill the screen.
local SCRATCH_CLASS = "singularity-scratch"
hl.window_rule({
    name      = "scratchpad-terminal",
    tag       = "-monocle",
    match     = { class = "^(" .. SCRATCH_CLASS .. ")$" },
    workspace = "special:scratchpad",
    float     = true,
    center    = true,
    size      = "monitor_w*0.6 monitor_h*0.6",
    maximize  = false,
})
hl.window_rule({ name = "scratchpad-terminal-exempt", match = { class = "^(" .. SCRATCH_CLASS .. ")$" }, tag = "+monocle-exempt" })

-- Starts the terminal if it isn't running (the rule above shows it), and
-- otherwise toggles the workspace it lives on.
toggleScratchpad = function()
    if #hl.get_windows({ class = SCRATCH_CLASS }) == 0 then
        hl.dispatch(hl.dsp.exec_cmd(terminal .. " --class " .. SCRATCH_CLASS))
    else
        hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
    end
end

-- Out of the scratchpad, it lands on the workspace the scratchpad was shown
-- over, which is then uncovered so the window can be seen there. Into it,
-- silently: the window just goes, rather than the scratchpad opening on it.
toggleStashed = function()
    local win = hl.get_active_window()
    if not win or not win.workspace then return end
    local target = "address:" .. win.address
    if win.workspace.name == "special:scratchpad" then
        local mon = win.monitor
        local ws = mon and mon.active_workspace
        if not ws then return end
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = target }))
        if mon.active_special_workspace then
            hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
        end
        hl.dispatch(hl.dsp.focus({ window = target }))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", window = target, follow = false }))
    end
end

-- Per-app and popout exceptions live in
-- ~/.config/singularity/window-rules.json, edited from Settings > Window
-- Rules. This file keeps only the machinery the shell depends on.
--
-- Read on every load, after every rule above so an entry overrides this
-- file's defaults (the later rule wins); within the file, the entry nearer
-- the top wins.
--
-- Entries match by class, title or both, literally and whole unless
-- "regex": true, which the popout entries need. Hyprland's regex has no
-- lookaheads -- one silently never matches -- so "negative:" says "anything
-- but this". Popouts are matched by title, since dialogs inherit their
-- app's class.
--
-- JSON comes from json.lua beside this file, loaded with pcall: missing or
-- broken, the rules are treated as empty rather than breaking the config.
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

-- The "fullscreen" entries' rules, which follow the layout like monocleRule.
local fullscreenRules = {}

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
            -- windows, which size themselves in QML (the Settings window's
            -- title would otherwise match the dialog entry).
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
            local ws = tonumber(r.workspace)
            if ws and ws >= 1 and ws <= MAX_WORKSPACES then rule.workspace = tostring(math.floor(ws)) end
            hl.window_rule(rule)
            -- Its own rule so applyLayoutRules can switch it off in dwindle,
            -- where every window opens tiled (see keepNewWindowTiled).
            if r.fullscreen then
                table.insert(fullscreenRules,
                    hl.window_rule({ name = name .. "-fullscreen", match = match, fullscreen = true }))
            end
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

-- The global layout mode, toggled by SUPER+M. In memory only: nothing
-- outside this file reads it, and it resets to monocle on a reload.
--
-- The rest of monocle is hooks, run in-process on Hyprland's event thread so
-- no other event can land mid-way: window.open sizes each new window,
-- window.active (maximizeFocused) keeps whatever you land on full and on top.
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

-- Per-window state this config keeps on top of Hyprland's own, by address:
--   small     -- unmaximized on purpose (SUPER+equal), so refocusing it does
--                not immediately undo the choice; see toggleMaximize() below
--   minimized -- the {x, y, w, h} SUPER+C hid it from, and whether it was
--                tiled (and fullscreen) before being floated to hide it;
--                see toggleMinimize() below
--   hideGen   -- bumped by every hide and restore, so a hide's delayed
--                second step skips a window brought back in the meantime
--   restore   -- the {x, y, w, h} a non-monocle floater had before it was
--                filled; see fillFloating() below
-- Cleared by a window.close hook further down: Hyprland reuses addresses,
-- so leftovers would land on some later window.
local windowState = {}
local function stateOf(addr)
    local st = windowState[addr]
    if not st then
        st = {}
        windowState[addr] = st
    end
    return st
end

-- SUPER+C also writes what it saved to a tag on the window, since
-- windowState doesn't survive a config reload and the Appearance page
-- reloads for most of its settings. A window hidden across one would
-- otherwise never come back. Tags set by dispatch outlive a reload.
local function minimizedTag(m)
    return string.format("minimized_%d_%d_%d_%d_%d_%d",
        m.x, m.y, m.w, m.h, m.tiled and 1 or 0, m.fullscreen)
end

local function setProp(addr, prop, value)
    hl.dispatch(hl.dsp.window.set_prop({ prop = prop, value = value, window = addr }))
end

-- Sizes and places a floater at r = {x, y, w, h}: animated with the
-- windows curve, or in one jump. Hyprland reads no_anim when it next draws,
-- not when the move is dispatched, so the jump holds it for a moment before
-- clearing it and calling andThen, which may animate again.
local function moveTo(addr, r)
    hl.dispatch(hl.dsp.window.resize({ x = r.w, y = r.h, window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = r.x, y = r.y, window = addr }))
end
local function jumpTo(addr, r, andThen)
    setProp(addr, "no_anim", "1")
    moveTo(addr, r)
    hl.timer(function()
        setProp(addr, "no_anim", "0")
        if andThen then andThen() end
    end, { timeout = 30, type = "oneshot" })
end

-- Calls fn once an animation of the given speed has played out.
local function afterAnimation(speed, fn)
    if animOff then
        fn()
    else
        hl.timer(fn, { timeout = math.floor(speed * 100 * animFactor), type = "oneshot" })
    end
end

-- r at the window style's starting size (windowShrink), around the same
-- centre.
local function shrunk(r)
    local w, h = math.floor(r.w * windowShrink[1]), math.floor(r.h * windowShrink[2])
    return { x = r.x + (r.w - w) // 2, y = r.y + (r.h - h) // 2, w = w, h = h }
end

-- Puts a SUPER+C-hidden window back where it was and forgets it was
-- hidden: slid back, or faded in where it was (growing from windowShrink
-- for the styles that have one), and tiled again if it was tiled.
local function restoreMinimized(win)
    local st = stateOf(win.address)
    local saved = st.minimized
    st.minimized = nil
    st.hideGen = (st.hideGen or 0) + 1
    local gen = st.hideGen
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.tag({ tag = "-" .. minimizedTag(saved), window = addr }))
    -- hidden by show desktop: the bar's button reads the tag
    for _, t in ipairs(type(win.tags) == "table" and win.tags or { win.tags }) do
        if t == "showdesktop" then
            hl.dispatch(hl.dsp.window.tag({ tag = "-showdesktop", window = addr }))
            hl.dispatch(hl.dsp.exec_cmd("qs ipc call desktop changed"))
            break
        end
    end

    -- skipped if it was hidden again, or closed, in the meantime
    local function current()
        return windowState[win.address] == st and st.hideGen == gen
    end
    -- Tiled again only once it has arrived: a maximized window hides the
    -- rest of the workspace, which would otherwise vanish while it's still
    -- fading in.
    local function retile()
        if not current() then return end
        hl.dispatch(hl.dsp.window.float({ action = "disable", window = addr }))
        if saved.fullscreen ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen({
                mode = saved.fullscreen == 1 and "maximized" or "fullscreen", action = "set", window = addr }))
        end
    end
    local function show()
        if not current() then return end
        if windowAnim ~= "fade" then moveTo(addr, saved) end
        -- slide too: the window may have been hidden under another style
        setProp(addr, "opacity", "1")
        if saved.tiled then afterAnimation(windowSpeed, retile) end
    end

    if windowSlides then
        show()
    else
        jumpTo(addr, windowShrink and shrunk(saved) or saved, show)
    end
end

-- The monitor's usable rect (its resolution minus what the bar and other
-- layer surfaces reserve), in the logical pixels of win.size/win.at. x/y
-- are absolute layout coordinates -- the monitor's origin plus its reserved
-- edge -- since window.move places windows in the whole layout.
local function usableArea(mon)
    local reserved = mon.reserved or { left = 0, top = 0, right = 0, bottom = 0 }
    return {
        x = (mon.x or 0) + reserved.left,
        y = (mon.y or 0) + reserved.top,
        w = mon.width / mon.scale - reserved.left - reserved.right,
        h = mon.height / mon.scale - reserved.top - reserved.bottom,
    }
end

-- The rect a monocle window fills: the usable area inside the edge gaps,
-- less a strip along the top for the tab bar when the window is one of a
-- group's tabs.
local function fillArea(win, mon)
    local area = usableArea(mon)
    local g = edgeGaps()
    area.x = area.x + g.left
    area.y = area.y + g.top
    area.w = area.w - g.left - g.right
    area.h = area.h - g.top - g.bottom
    if win.group then
        local bar = GROUPBAR_HEIGHT
        area.y = area.y + bar
        area.h = area.h - bar
    end
    return area
end

-- Whether a floater fills the monitor it is on: position as well as size,
-- unlike isAlreadyFull(), since the right size on the wrong screen isn't.
local function isFitted(win, area)
    return math.abs(win.size.x - area.w) <= 4 and math.abs(win.size.y - area.h) <= 4
        and math.abs(win.at.x - area.x) <= 4 and math.abs(win.at.y - area.y) <= 4
end

local function isAlreadyFull(win, mon)
    local area = usableArea(mon)
    local w, h = win.size.x, win.size.y
    return math.abs(w - area.w) <= 4 and math.abs(h - area.h) <= 4
end

-- True if `win` carries the Hyprland tag `name`. A tag set by a window rule
-- comes back with a trailing "*" (dynamic) and one set by dispatch without;
-- both count.
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
    local area = fillArea(win, mon)
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(area.w), y = math.floor(area.h), window = addr }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(area.x), y = math.floor(area.y), window = addr }))
end

-- A floating window is maximized by filling the usable area, never with
-- Hyprland's maximized flag: a floater carrying that flag ignores
-- bring_to_top and window.move, so ALT+Tab left it covered and SUPER+C
-- couldn't hide it. The flag is taken off wherever it turns up (the
-- window.fullscreen hook, and on focus as a backstop) -- SUPER+X, a titlebar
-- double-click, an app asking for it -- and the window filled instead.
-- Filling remembers the geometry it had, which toggleMaximize() puts back.
--
-- Returns the window re-read, since its geometry has changed.
local function fillFloating(win)
    local addr = "address:" .. win.address
    local st = stateOf(win.address)
    if hasTag(win, "monocle") then
        st.small = nil
    elseif not st.restore then
        st.restore = { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }
    end
    sizeToFullFloat(win)
    hl.dispatch(hl.dsp.window.bring_to_top({ window = addr }))
    -- by selector: hl.get_window() returns nil for a bare address
    return hl.get_window(addr) or win
end

local function unflagFloating(win)
    if not (win and win.floating and win.fullscreen == 1) then return win end
    local addr = "address:" .. win.address
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = addr }))
    win = hl.get_window(addr) or win
    -- Quickshell's own windows size themselves in QML; just unflag them
    if win.class == "org.quickshell" then return win end
    return fillFloating(win)
end
hl.on("window.fullscreen", function(win) unflagFloating(win) end)

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

-- Sizes every window the monocle rule just floated, once, as it maps, so
-- switching to it later is just a raise. Uses the window window.open hands
-- over, not hl.get_active_window(), which can still be the previous window
-- when a second one opens.
local function onMonocleOpen(win)
    if not win then return end
    -- The rules follow the *active* workspace's layout, so a window that
    -- mapped somewhere else (a window-rules.json workspace entry, an app
    -- restoring its own session) can come up in the wrong one.
    --
    -- Only then: on the active workspace the rules were right, and a
    -- window's state isn't settled yet (Quickshell's windows map before
    -- their class and float land, and looked like tiled apps).
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

-- In dwindle every window opens tiled, including one that asks to open
-- maximized or fullscreen (an app restoring how it was last closed). Apps
-- ask as they map or a moment after, so for its first second and a half a
-- tiled window's maximize or fullscreen is undone. Taking it out of the
-- tiling afterwards is left to SUPER+X, SUPER+CTRL+F and SUPER+SHIFT+V.
local justOpened = {}
local function keepNewWindowTiled(win)
    if not (win and justOpened[win.address]) then return end
    if win.floating or win.fullscreen == 0 or monocleOn(win.workspace) then return end
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = win.fullscreen == 1 and "maximized" or "fullscreen", action = "unset",
        window = "address:" .. win.address }))
end
hl.on("window.open", function(win)
    if not win then return end
    local addr = win.address
    justOpened[addr] = true
    hl.timer(function() justOpened[addr] = nil end, { timeout = 1500, type = "oneshot" })
    keepNewWindowTiled(win)
end)
hl.on("window.fullscreen", keepNewWindowTiled)

-- LinOffice (Office in a Windows VM over FreeRDP RemoteApp): each app also
-- maps an untitled ~21x21 helper window at the screen's corner, with the
-- app's class. It showed as a second, empty Word/Excel window in the strip
-- and ALT+Tab, so it's parked on a special workspace that's never shown.
-- Matched on size too: Office's menus and dropdowns are untitled as well.
hl.on("window.open", function(win)
    if not win or not win.xwayland or win.title ~= "" then return end
    if not (win.class or ""):match("^Microsoft ") then return end
    if win.size.x > 32 or win.size.y > 32 then return end
    hl.dispatch(hl.dsp.window.move({ workspace = "special:rdp-helpers", window = "address:" .. win.address, follow = false }))
end)

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

    -- A hidden window focused by any route (ALT+Tab, the overlay, the bar)
    -- is being asked for, so bring it back. Ahead of the monocle check since
    -- SUPER+C works in dwindle mode too.
    -- Restoring puts it back as it was, so there's nothing left to do here
    -- but raise it -- a re-fit now would cut the restore animation short.
    if win and stateOf(win.address).minimized then
        restoreMinimized(win)
        hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        return
    end

    -- normally already done by the window.fullscreen hook
    win = unflagFloating(win)

    if not win or not win.class or win.fullscreen ~= 0 then return end
    if not monocleOn(win.workspace) then return end

    if win.floating then
        -- Hyprland doesn't raise a floater just because it got focus, so a
        -- monocle window is raised here. Other floaters (dialogs, Quickshell)
        -- aren't part of the monocle stack and are left alone.
        if hasTag(win, "monocle") then
            -- Re-fit a window left sized for a monitor it's no longer on
            -- (moved across, docked, undocked); backs up the monitor hooks
            -- below for when the layout hadn't settled as they fired.
            local mon = win.monitor
            if mon and not stateOf(win.address).small and not isFitted(win, fillArea(win, mon)) then
                sizeToFullFloat(win, mon)
            end
            hl.dispatch(hl.dsp.window.bring_to_top({ window = "address:" .. win.address }))
        end
        return
    end
    -- By class too: a Quickshell window can be focused before its rule's
    -- float lands, and must never be maximized (it sizes itself in QML).
    if win.class == "org.quickshell" then return end
    if stateOf(win.address).small then return end

    local mon = hl.get_active_monitor()
    if not mon then return end

    -- A window alone on its workspace fills the area with fullscreen=0, so
    -- compare geometry too rather than re-maximize it on every focus.
    if isAlreadyFull(win, mon) then return end

    hl.dispatch(hl.dsp.window.fullscreen({mode="maximized"}))
end

hl.on("window.active", maximizeFocused)

-- Re-checked on close too, rather than relying on how Hyprland sequences
-- the focus change around it.
hl.on("window.close", maximizeFocused)

-- window.close hands the closing window over, same as window.open does.
hl.on("window.close", function(win)
    if win then windowState[win.address] = nil end
end)

-- Docking, undocking, or changing a display's resolution or arrangement
-- moves the monitors under every open window, and floaters aren't re-laid
-- out. This re-fits every monocle window at once when that happens (the
-- focus hook only catches one at a time). Windows made small keep that size.
local function refitMonocle()
    for _, w in ipairs(hl.get_windows()) do
        if w.floating and hasTag(w, "monocle") and not stateOf(w.address).small and monocleOn(w.workspace) then
            local mon = w.monitor
            if mon and not isFitted(w, fillArea(w, mon)) then sizeToFullFloat(w, mon) end
        end
    end
end

-- All three: added/removed for a display appearing or going,
-- layout_changed for a rearrangement (it fires last when docking).
hl.on("monitor.added", refitMonocle)
hl.on("monitor.removed", refitMonocle)
hl.on("monitor.layout_changed", refitMonocle)
-- and after every load, for a changed edge gap
hl.timer(refitMonocle, { timeout = 200, type = "oneshot" })

-- TABS. Apps with no tabs of their own open each file in a window of its
-- own; these open theirs as tabs of one Hyprland group instead, joining the
-- first window of the same class on the same workspace. The group draws its
-- tab bar; clicking a tab switches, middle-clicking closes it.
local TABBED_CLASSES = {
    ["org.pwmt.zathura"] = true,
}

-- A monocle group is refitted as its tab bar comes and goes: the group
-- moves as one, so fitting any member fits them all.
local function refitGroup(win)
    if isMonocleWin(win) and not stateOf(win.address).small and monocleOn(win.workspace) then
        sizeToFullFloat(win)
    end
end

hl.on("window.open", function(win)
    if not win or not TABBED_CLASSES[win.class] or not win.workspace then return end
    local host
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= win.address and w.class == win.class and w.workspace
            and w.workspace.id == win.workspace.id and (not host or (w.group and not host.group)) then
            host = w
        end
    end
    if not host then return end
    if not host.group then
        hl.dispatch(hl.dsp.group.toggle({ window = "address:" .. host.address }))
    end
    if not host.group then return end
    host.group:add(win)
    refitGroup(win)
end)

-- SUPER+SHIFT+Q: every tab of the focused window's group.
function closeAllTabs()
    local win = hl.get_active_window()
    if not win then return end
    local members = win.group and win.group.members or { win }
    for _, w in ipairs(members) do
        hl.dispatch(hl.dsp.window.close({ window = "address:" .. w.address }))
    end
end

-- The Tabs binds are live only while a tabbed app has focus.
local function syncTabBinds()
    local win = hl.get_active_window()
    local on = win ~= nil and TABBED_CLASSES[win.class] == true
    for _, b in ipairs({ tabNextBind, tabPrevBind, tabCloseBind }) do b:set_enabled(on) end
end
syncTabBinds()
hl.on("window.active", syncTabBinds)
hl.on("window.close", syncTabBinds)

-- A group down to its last tab is dissolved, so a lone window has no tab
-- bar. After the close has settled, since the group still counts the
-- closing window while window.close runs.
hl.on("window.close", function()
    hl.timer(function()
        for _, w in ipairs(hl.get_windows()) do
            if w.group and w.group.size == 1 then
                hl.dispatch(hl.dsp.group.toggle({ window = "address:" .. w.address }))
                refitGroup(w)
            end
        end
    end, { timeout = 50, type = "oneshot" })
end)

-- SUPER+X. Deliberately no hook forcing a window back to maximized when it
-- leaves that state (the window.fullscreen hook only takes the flag *off*
-- floaters): that would make shrinking a window impossible. Instead this
-- records deliberate shrinks in windowState and maximizeFocused() leaves
-- them alone.
--
-- A tiled window uses Hyprland's own maximize toggle. A monocle floater has
-- nothing to toggle, so it shrinks to 70% centred and grows back.
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

    -- Any other floater: fill it, or put back what filling it replaced.
    -- One opened already full (nothing to put back) shrinks to 70% centred,
    -- the same as a monocle window.
    if win.floating then
        win = unflagFloating(win)
        local st = stateOf(win.address)
        local addr = "address:" .. win.address
        local mon = win.monitor or hl.get_active_monitor()
        if not mon then return end
        local area = fillArea(win, mon)
        if not isFitted(win, area) then
            -- whatever size it is now is the one to come back to
            st.restore = nil
            fillFloating(win)
        elseif st.restore then
            local r = st.restore
            st.restore = nil
            hl.dispatch(hl.dsp.window.resize({ x = r.w, y = r.h, window = addr }))
            hl.dispatch(hl.dsp.window.move({ x = r.x, y = r.y, window = addr }))
        else
            hl.dispatch(hl.dsp.window.resize({
                x = math.floor(area.w * 0.7), y = math.floor(area.h * 0.7), window = addr }))
            hl.dispatch(hl.dsp.window.center({ window = addr }))
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

-- Hides a window below the screen, or restores it, the way windows open
-- and close (windowAnim): slid off the screen (up for drop, down otherwise),
-- faded out where it is (shrinking to windowShrink for the styles that have
-- one) and only then moved away, or moved away at once. It stays transparent
-- while hidden, so the fade back in starts from nothing. A tiled window is
-- floated where it is first, since only floaters can be moved off-screen.
-- Refocusing a hidden window any other way restores it too -- see
-- maximizeFocused() above.
local function hiddenRect(r, mon)
    local y = windowAnim == "drop" and mon.y - r.h - 100 or mon.y + mon.height + 100
    return { x = r.x, y = y, w = r.w, h = r.h }
end

local function minimizeWindow(win)
    local st = stateOf(win.address)
    local mon = win.monitor or hl.get_active_monitor()
    if not mon then return end
    local addr = "address:" .. win.address

    local tiled = not win.floating
    if not tiled then win = unflagFloating(win) end
    local r = { x = math.floor(win.at.x), y = math.floor(win.at.y),
                w = math.floor(win.size.x), h = math.floor(win.size.y),
                tiled = tiled, fullscreen = tiled and win.fullscreen or 0 }
    st.minimized = r
    st.hideGen = (st.hideGen or 0) + 1
    local gen = st.hideGen
    hl.dispatch(hl.dsp.window.tag({ tag = "+" .. minimizedTag(r), window = addr }))

    -- skipped if it was restored, or closed, in the meantime
    local function current()
        return windowState[win.address] == st and st.hideGen == gen
    end

    -- Moving it off-screen doesn't move focus, so hand focus to the most
    -- recently used window left on this workspace -- never another hidden
    -- one, since focusing that would bring it back. Only once it's gone:
    -- a monocle window is raised as it takes focus, and would cover the
    -- animation.
    local function focusNext()
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

    local function gone()
        if not current() then return end
        if not windowSlides then jumpTo(addr, hiddenRect(r, mon)) end
        focusNext()
    end
    local function hide()
        if not current() then return end
        if windowAnim == "none" then return gone() end
        if windowSlides then
            moveTo(addr, hiddenRect(r, mon))
        else
            setProp(addr, "opacity", "0")
            if windowShrink then moveTo(addr, shrunk(r)) end
        end
        afterAnimation(windowSlides and windowSpeed or fadeSpeed, gone)
    end

    if tiled then
        if r.fullscreen ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen({
                mode = r.fullscreen == 1 and "maximized" or "fullscreen", action = "unset", window = addr }))
        end
        hl.dispatch(hl.dsp.window.float({ action = "enable", window = addr }))
        jumpTo(addr, r, hide)
    else
        hide()
    end
end

function toggleMinimize()
    local win = hl.get_active_window()
    if not win then return end
    if stateOf(win.address).minimized then restoreMinimized(win) else minimizeWindow(win) end
end

-- SUPER+D and the bar's show-desktop button. With any window showing on
-- the active workspace, hides them all as SUPER+C does, tagged
-- "showdesktop"; with none, brings back the ones it tagged and focuses the
-- one used last. Bringing one back any other way (the window strip,
-- ALT+Tab) drops its tag. The bar reads the tag to light its button, so
-- it's told to look again. A global so the button can run it through
-- `hyprctl eval`.
function singularityShowDesktop()
    local ws = hl.get_active_workspace()
    if not ws or ws.special then return end
    local showing, hidden = {}, {}
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not w.hidden and w.workspace and w.workspace.id == ws.id
                and w.class ~= "org.quickshell" then
            if not stateOf(w.address).minimized then
                showing[#showing + 1] = w
            elseif hasTag(w, "showdesktop") then
                hidden[#hidden + 1] = w
            end
        end
    end
    if #showing > 0 then
        for _, w in ipairs(showing) do
            hl.dispatch(hl.dsp.window.tag({ tag = "+showdesktop", window = "address:" .. w.address }))
            minimizeWindow(w)
        end
    elseif #hidden > 0 then
        local last
        for _, w in ipairs(hidden) do
            restoreMinimized(w)
            if not last or w.focus_history_id < last.focus_history_id then last = w end
        end
        hl.dispatch(hl.dsp.focus({ window = "address:" .. last.address }))
    end
    hl.dispatch(hl.dsp.exec_cmd("qs ipc call desktop changed"))
end

-- After a reload, windows SUPER+C hid get their windowState back from the
-- tag it left. One a reload caught mid-fade, before the timer above moved
-- it away, is moved away now.
for _, w in ipairs(hl.get_windows()) do
    for _, t in ipairs(type(w.tags) == "table" and w.tags or { w.tags }) do
        local x, y, width, height, tiled, fullscreen =
            tostring(t):match("^minimized_(%-?%d+)_(%-?%d+)_(%d+)_(%d+)_([01])_(%d+)$")
        if x then
            local r = { x = tonumber(x), y = tonumber(y), w = tonumber(width), h = tonumber(height),
                        tiled = tiled == "1", fullscreen = tonumber(fullscreen) }
            stateOf(w.address).minimized = r
            local mon = w.monitor
            if mon and w.at.y + w.size.y > mon.y and w.at.y < mon.y + mon.height then jumpTo("address:" .. w.address, hiddenRect(r, mon)) end
        end
    end
end

-- WINDOW KEYS: SUPER+SHIFT/ALT/CTRL + arrows and SUPER+O. Global so the
-- binds can reach them.
--
-- A monocle window filling its monitor has nowhere to move or grow on it,
-- so the arrows leave it alone, except that SHIFT+left/right sends it to
-- the monitor that way. SUPER+X shrinks it first to move or size it by hand.
local NUDGE = 40
local ARROWS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }

local function isFullMonocle(win)
    return isMonocleWin(win) and not stateOf(win.address).small
end

-- Re-fits a monocle window to the monitor it landed on. The focus hook
-- would catch it too, but only on the next focus change.
local function refitAfterMove(win)
    if not isMonocleWin(win) or stateOf(win.address).small then return end
    local moved = hl.get_window("address:" .. win.address)
    if moved and moved.monitor then sizeToFullFloat(moved, moved.monitor) end
end

-- Tiled: along the layout, and on to the next monitor past its edge.
-- Floating: nudged, since a floater moved by direction jumps to the edge.
function moveWindowDir(dir)
    local win = hl.get_active_window()
    if not win then return end
    if not win.floating then
        hl.dispatch(hl.dsp.window.move({ direction = dir }))
    elseif isFullMonocle(win) then
        if dir ~= "left" and dir ~= "right" then return end
        hl.dispatch(hl.dsp.window.move({ monitor = dir == "left" and "l" or "r" }))
        refitAfterMove(win)
    else
        local d = ARROWS[dir]
        hl.dispatch(hl.dsp.window.move({ x = d[1] * NUDGE, y = d[2] * NUDGE, relative = true }))
    end
end

-- Tiled only: a floater has no place in the layout to trade. Hyprland
-- reports a missing neighbour as an error, which is nothing here.
function swapWindowDir(dir)
    local win = hl.get_active_window()
    if not win or win.floating then return end
    pcall(hl.dispatch, hl.dsp.window.swap({ direction = dir }))
end

-- On a tiled window the arrow moves the split it shares with its
-- neighbour that way. A floater grows to the right and down and shrinks to
-- the left and up, about its centre.
function resizeWindowDir(dir)
    local win = hl.get_active_window()
    if not win or isFullMonocle(win) then return end
    local d = ARROWS[dir]
    hl.dispatch(hl.dsp.window.resize({ x = d[1] * NUDGE, y = d[2] * NUDGE, relative = true }))
end

function sendToNextMonitor()
    local win = hl.get_active_window()
    if not win or #hl.get_monitors() < 2 then return end
    hl.dispatch(hl.dsp.window.move({ monitor = "+1" }))
    refitAfterMove(win)
end

-- monocleRule and the fullscreen entries' rules act on windows as they map,
-- nearly always on the active workspace, so they're switched to match it on
-- every workspace change and on SUPER+M. That's what gives a pinned
-- workspace its layout at map time, with no float-then-tile flicker. The
-- bar's layout toast hears of a workspace change only when the layout
-- changes; SUPER+M always announces.
local rulesMonocle = nil
local function applyLayoutRules(announce)
    local ws = hl.get_active_workspace()
    if ws and ws.special then return end
    local on = monocleOn(ws)
    monocleRule:set_enabled(on)
    for _, rule in ipairs(fullscreenRules) do rule:set_enabled(on) end
    if announce or (rulesMonocle ~= nil and rulesMonocle ~= on) then
        hl.exec_cmd("qs ipc call layout set " .. (on and "monocle" or "dwindle"))
    end
    rulesMonocle = on
end
applyLayoutRules()
-- wrapped: the event handler is called with the workspace, and anything
-- truthy in that first argument would toast on every workspace change
hl.on("workspace.active", function() applyLayoutRules() end)

-- SUPER+M: monocle or dwindle everywhere that isn't pinned. The rules only
-- act at map time, so the windows already open on the workspace are
-- converted here too. On a pinned workspace nothing moves and the toast
-- says so. Global so the SUPER+M bind can reach it.
function toggleLayout()
    monocleEnabled = not monocleEnabled

    local ws = hl.get_active_workspace()
    local pin = ws and workspaceLayouts[tostring(ws.id)]
    if pin then
        hl.exec_cmd("notify-send -a Hyprland -t 3000 'Layout' 'Workspace " .. ws.id
            .. " is pinned to " .. (pin == "monocle" and "monocle" or "tiled")
            .. "; windows opened or moved elsewhere now go "
            .. (monocleEnabled and "monocle" or "tiled") .. "'")
        return
    end

    applyLayoutRules(true)

    local win = hl.get_active_window()
    if not win or not win.workspace then return end
    local mon = win.monitor or hl.get_active_monitor()
    for _, w in ipairs(win.workspace:get_windows()) do
        setWindowMonocle(w, monocleEnabled, mon)
    end
end
