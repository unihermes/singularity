-- Singularity - Hyprland
-- ~/.config/hypr/binds.lua
--
-- Every keybind. The Keybinds window (SUPER+K) reads and rewrites this file
-- only; link.sh copies the repo's default where there's none yet. Sections
-- are `-- --- Name ---` markers; plain one-line binds are editable (see
-- HyprBinds.js), the rest listed read-only.

local shared = require("shared")
local altTabKey = require("alttab")

-- Workspaces 1..MAX_WORKSPACES get SUPER+n binds and are the only ones a
-- Window Rules entry may target; keep equal to Settings.workspaceCount.
local MAX_WORKSPACES = 5
shared.maxWorkspaces = MAX_WORKSPACES

-- The programs the launcher binds run: binary names, not .desktop names.
-- The terminal is whichever Settings > Terminal picks (terminal.sh).
local terminal    = "~/.config/singularity/terminal.sh"
local fileManager = "thunar"
local editor      = "codium"
local zen         = "zen-browser"
local floorp      = "floorp"
-- the window classes each app bind opens, so the bind focuses an open one
-- (hyprland.lua); an unlisted plain program name is its own class
shared.appClasses = {
    [terminal]    = { "Alacritty", "com.mitchellh.ghostty" },
    [fileManager] = "thunar",
    [editor]      = { "codium", "VSCodium" },
    [zen]         = "zen",
    [floorp]      = "floorp",
}
-- the Quickshell launcher; wofi (with the shell's stylesheet) only when the
-- shell isn't running, pkill first so a second press dismisses it
local menu        = "qs ipc call launcher toggle apps || pkill wofi || { s=~/.local/state/singularity/wofi.css; [ -r \"$s\" ] || s=~/.config/wofi/style.css; wofi --show drun --style \"$s\" --term ~/.config/singularity/terminal.sh; }"

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
-- Maximize fills the usable area (below the bar); fullscreen covers the
-- whole output. Function binds are closures, as windows.lua defines them
-- after this file runs.
hl.bind(mod .. " + X", function() toggleMaximize() end)  -- Maximize or restore window
hl.bind(mod .. " + CTRL + F",  hl.dsp.window.fullscreen())  -- Fullscreen window, covering the bar
hl.bind(mod .. " + equal",     function() stepWindowSize(1) end)  -- Grow window a size step
hl.bind(mod .. " + minus",     function() stepWindowSize(-1) end)  -- Shrink window a size step
hl.bind(mod .. " + C",         function() toggleMinimize() end)  -- Minimize or restore window
hl.bind(mod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))  -- Float or tile window
hl.bind(mod .. " + P",         hl.dsp.window.pseudo())  -- Keep window's own size in its tile
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"))  -- Split side by side or stacked
hl.bind(mod .. " + M",         function() toggleLayout() end)  -- Switch between tiled and one-window layout

-- --- Scratchpad ---
-- A terminal on its own special workspace (first press starts it). SHIFT
-- stashes the focused window there, or puts a stashed one back.
hl.bind(mod .. " + grave", function() toggleScratchpad(terminal) end)  -- Show or hide the scratchpad
hl.bind(mod .. " + SHIFT + grave", function() toggleStashed() end)  -- Move window into or out of the scratchpad

-- --- Show desktop ---
-- hides every window as SUPER+C does; again brings them back
hl.bind(mod .. " + D", function() singularityShowDesktop() end)  -- Show the desktop, or bring its windows back

-- --- Notes ---
-- Quickshell's sticky notes, pinned top-right (window-rules.lua)
hl.bind(mod .. " + N", hl.dsp.exec_cmd("qs ipc call notes toggle"))  -- Show or hide sticky notes

-- --- Focus ---
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))  -- Focus window to the left
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))  -- Focus window to the right
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))  -- Focus window above
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))  -- Focus window below

-- --- Move & resize ---
-- tiled windows move, swap and resize in the layout; floaters nudge 40px
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

-- Windows-style ALT+Tab drawn by Quickshell: hold ALT, tap Tab, release to
-- focus. Why every Tab needs a bind: alttab.lua.
hl.bind("ALT + Tab",         altTabKey("~/.config/hypr/alttab-ipc.sh tab"),  { repeating = true })  -- Switch windows
hl.bind("ALT + SHIFT + Tab", altTabKey("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards
hl.bind("ALT + grave",       altTabKey("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards

-- Not a bare Alt_L/Alt_R `global` bind for the release: that changes how
-- Hyprland treats ALT everywhere, including the drag/resize mod.

-- --- Tabs ---
-- for the apps opened as tabs (TABBED_CLASSES in windows.lua), live only
-- while one has focus
local tabNextBind  = hl.bind("CTRL + Tab",         hl.dsp.group.next())  -- Next tab
local tabPrevBind  = hl.bind("CTRL + SHIFT + Tab", hl.dsp.group.prev())  -- Previous tab
local tabCloseBind = hl.bind(mod .. " + SHIFT + Q", function() closeAllTabs() end)  -- Close all tabs
shared.tabBinds = { tabNextBind, tabPrevBind, tabCloseBind }

-- --- Workspaces ---
-- the workspace grid (WorkspaceOverlay.qml)
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
-- two more launcher modes; Tab cycles through all four
hl.bind(mod .. " + slash", hl.dsp.exec_cmd("qs ipc call launcher toggle calc"))   -- Calculator
hl.bind(mod .. " + S",     hl.dsp.exec_cmd("qs ipc call launcher toggle files"))  -- Search files

-- --- Shell windows ---
-- The bar's standalone windows; an empty page opens each on its default page
hl.bind(mod .. " + comma",  hl.dsp.exec_cmd("qs ipc call settings open ''"))  -- Open Settings
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("qs ipc call system open ''"))    -- Open System
hl.bind(mod .. " + K",      hl.dsp.exec_cmd("qs ipc call keybinds open"))     -- Open Keybinds

-- --- Session ---
-- through logind, so hypridle's lock_cmd runs it
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
-- Close blanks the screen and suspends after Settings > Lock Screen's delay;
-- open undoes it. logind's lid handling is inhibited (autostart.lua);
-- everything else is in lid.sh.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid closed: screen off, suspend later if still shut
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid opened: screen on

-- --- Function Keys ---
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })  -- Volume up
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })  -- Volume down
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })  -- Mute or unmute sound
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("~/.config/hypr/mic-mute.sh"),                       { locked = true })  -- Mute or unmute microphone
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("~/.config/hypr/brightness.sh up"),                { locked = true, repeating = true })  -- Brightness up
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/brightness.sh down"),              { locked = true, repeating = true })  -- Brightness down

-- --- Media Keys ---
-- Drive the player the bar's media module follows (services/Media.qml)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("qs ipc call media toggle"),   { locked = true })  -- Play or pause media
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("qs ipc call media pause"),    { locked = true })  -- Pause media
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd("qs ipc call media stop"),     { locked = true })  -- Stop media
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("qs ipc call media next"),     { locked = true })  -- Next track
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("qs ipc call media previous"), { locked = true })  -- Previous track
-- The right-hand modifiers alone, on release: a tap plays, skips or goes
-- back, while one held for another key (SHIFT+a) does nothing. Each names
-- its own mod, which is still held as it's let go. They still reach apps
-- as modifiers (non_consuming), and are off while a game has focus
-- (game-keys.lua).
hl.bind("SHIFT + Shift_R", hl.dsp.exec_cmd("qs ipc call media toggle"),   { release = true, non_consuming = true })  -- Play or pause media
hl.bind("CTRL + Control_R", hl.dsp.exec_cmd("qs ipc call media next"),     { release = true, non_consuming = true })  -- Next track
hl.bind("ALT + Alt_R",     hl.dsp.exec_cmd("qs ipc call media previous"), { release = true, non_consuming = true })  -- Previous track

-- --- Lock Keys ---
-- pass-through: the lock toggles as usual and the shell toasts it (on press,
-- as a release bind never fires on these keys)
hl.bind("Caps_Lock", hl.dsp.exec_cmd("qs ipc call locks changed caps"), { non_consuming = true })  -- Show Caps Lock state
hl.bind("Num_Lock",  hl.dsp.exec_cmd("qs ipc call locks changed num"),  { non_consuming = true })  -- Show Num Lock state
