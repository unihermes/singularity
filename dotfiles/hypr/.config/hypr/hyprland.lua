-- Singularity - Hyprland
-- ~/.config/hypr/hyprland.lua
--
-- Lua config; Hyprland loads this in preference to the deprecated
-- hyprland.conf. It only runs the modules beside it, in order:
--
--   shared     the Settings state files and constants the others share
--   displays   monitor rules, docked mode, workspaces across displays
--   env        environment variables
--   autostart  what starts with the session
--   looks      gaps, borders, shadows, blur, tabs, animations
--   input      keyboard, mouse, touchpad, gestures
--   overrides  this machine's hyprland.json, then Game Mode
--   binds      every keybind; the Keybinds window rewrites this one
--   windows    window rules, monocle, scratchpad, tabs, the window keys
--
-- Each is a plain require(): ~/.config/hypr is first on package.path, and
-- every reload starts a fresh Lua state, so each module runs once per load.

require("shared")
require("displays")
require("env")
require("autostart")
require("looks")
require("input")
require("overrides")

-- A command run from a bind marks a launch first, so the window it opens
-- gets its app's window rule even with another of the app's windows open
-- (see markLaunch in windows.lua). Wrapped here rather than per bind so that
-- binds keep the plain hl.dsp.exec_cmd("...") form the Keybinds window reads
-- and writes.
do
    local execCmd = hl.dsp.exec_cmd
    hl.dsp.exec_cmd = function(...)
        local dispatcher = execCmd(...)
        return function()
            if markLaunch then markLaunch() end
            hl.dispatch(dispatcher)
        end
    end
end

require("binds")
require("windows")

-- Escape hatch for anything the GUI doesn't cover: ~/.local/state/singularity/
-- custom.lua is run last, so whatever it sets wins over everything above, and
-- it stays on this machine. A missing file is fine; one that fails to load or
-- errors partway says so in a notification, keeping whatever ran before the
-- error.
do
    local path = os.getenv("HOME") .. "/.local/state/singularity/custom.lua"
    local ok, err = pcall(dofile, path)
    if not ok and not tostring(err):find("cannot open", 1, true) then
        hl.exec_cmd("notify-send -a Hyprland -u critical 'custom.lua' '"
            .. tostring(err):gsub("'", "’") .. "'")
    end
end
