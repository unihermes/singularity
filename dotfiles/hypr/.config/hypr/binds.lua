-- Singularity - Hyprland
-- ~/.config/hypr/binds.lua
--
-- Every keybind. The Keybinds window (Settings > Keybinds, SUPER+K) reads
-- and rewrites this file and no other, so its changes land in the repo, to
-- be committed.
-- Sections are marker comments, `-- --- Name ---`: the window groups binds
-- by them and adds new ones to the end of the chosen section. It edits a
-- bind on a line of its own in the plain forms -- see HyprBinds.js -- and
-- lists the rest read-only.

local shared = require("shared")
local altTabKey = require("alttab")

-- Workspaces 1..MAX_WORKSPACES get SUPER+n binds, and are the only ones a
-- window-rules.json entry may send a window to (windows.lua reads it from
-- shared). Quickshell's copy is Settings.workspaceCount
-- (services/Settings.qml); keep the two equal.
local MAX_WORKSPACES = 5
shared.maxWorkspaces = MAX_WORKSPACES

-- The programs the launcher binds run: binary names, not .desktop names.
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
-- Maximize goes through toggleMaximize() (windows.lua) so that shrinking a
-- window on purpose sticks: it records the choice, and the focus hook that
-- re-maximizes in monocle leaves such windows alone. Wrapped in closures,
-- like every function bind here, because windows.lua defines them after
-- this file runs.
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
hl.bind(mod .. " + grave", function() toggleScratchpad(terminal) end)  -- Show or hide the scratchpad
hl.bind(mod .. " + SHIFT + grave", function() toggleStashed() end)  -- Move window into or out of the scratchpad

-- --- Show desktop ---
-- Hides every window on the workspace as SUPER+C does, so they stay on it
-- and in the bar's window strip; the next press brings them back. See
-- singularityShowDesktop() in windows.lua.
hl.bind(mod .. " + D", function() singularityShowDesktop() end)  -- Show the desktop, or bring its windows back

-- --- Notes ---
-- Quickshell's sticky notes (windows/NotesWindow.qml), pinned in the
-- top-right corner over every workspace; see the "notes" rule in windows.lua
hl.bind(mod .. " + N", hl.dsp.exec_cmd("qs ipc call notes toggle"))  -- Show or hide sticky notes

-- --- Focus ---
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))  -- Focus window to the left
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))  -- Focus window to the right
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))  -- Focus window above
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))  -- Focus window below

-- --- Move & resize ---
-- moveWindowDir() and friends, in windows.lua: tiled windows move, swap and resize
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
-- (AltTabSwitcher.qml): hold ALT and tap Tab to move the highlight, release
-- ALT to focus what you landed on. altTabKey and why every Tab needs a bind
-- are in alttab.lua.
hl.bind("ALT + Tab",         altTabKey("~/.config/hypr/alttab-ipc.sh tab"),  { repeating = true })  -- Switch windows
hl.bind("ALT + SHIFT + Tab", altTabKey("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards
hl.bind("ALT + grave",       altTabKey("~/.config/hypr/alttab-ipc.sh prev"), { repeating = true })  -- Switch windows, backwards

-- Not a bare Alt_L/Alt_R `global` bind for the release: that changes how
-- Hyprland treats ALT everywhere, including the drag/resize mod.

-- --- Tabs ---
-- For the apps opened as tabs (TABBED_CLASSES in windows.lua), and only
-- while one has focus: the TABS hooks there turn these off for anything
-- else, so other apps keep the keys (a browser's own CTRL+Tab).
local tabNextBind  = hl.bind("CTRL + Tab",         hl.dsp.group.next())  -- Next tab
local tabPrevBind  = hl.bind("CTRL + SHIFT + Tab", hl.dsp.group.prev())  -- Previous tab
local tabCloseBind = hl.bind(mod .. " + SHIFT + Q", function() closeAllTabs() end)  -- Close all tabs
shared.tabBinds = { tabNextBind, tabPrevBind, tabCloseBind }

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
-- Close turns the screen off and, after the delay set in Settings > Lock
-- Screen, suspends if it's still shut; open turns it back on and cancels
-- that. logind's own lid handling is
-- inhibited in autostart.lua so this is the only thing acting on the lid. All of
-- it -- the debounce for this laptop's bouncing lid switch, the suspend
-- timer, re-suspending after a wake with the lid shut, docked mode -- lives
-- in lid.sh. misc:key_press_enables_dpms and mouse_move_enables_dpms are the
-- backstop: any key or mouse movement wakes a wrongly-blanked screen. lid.sh
-- turns both off while the lid is shut, or the keyboard and touchpad the
-- closing lid presses on would wake the panel it just blanked.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("~/.config/hypr/lid.sh event"), { locked = true })  -- Lid closed: screen off, suspend later if still shut
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
