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

-- A bind that starts an app focuses it instead when one of its windows is
-- open already: the one used last, or with one of them focused, the one used
-- longest ago, so pressing again goes through them all. The classes an app's
-- windows have come from shared.appClasses (binds.lua), keyed by the bind's
-- command; a command that's just a program name and isn't listed there is
-- taken as its own class.
--
-- A command that does run marks a launch first, so the window it opens gets
-- its app's window rule even with another of the app's windows open (see
-- markLaunch in windows.lua).
--
-- Wrapped here rather than per bind so that binds keep the plain
-- hl.dsp.exec_cmd("...") form the Keybinds window reads and writes.
do
    local shared = require("shared")

    local function classesOf(cmd)
        local c = shared.appClasses and shared.appClasses[cmd]
        if type(c) == "string" then return { c } end
        if c then return c end
        if type(cmd) == "string" and cmd:match("^[%w._-]+$") then return { cmd } end
    end

    -- whether the app is open, and the window to focus (none when its only
    -- window already has focus)
    local function openWindow(cmd)
        local classes = classesOf(cmd)
        if not classes then return false end
        local want = {}
        for _, c in ipairs(classes) do want[c:lower()] = true end
        local function isApp(w) return w and w.mapped and want[(w.class or ""):lower()] end
        local active = hl.get_active_window()
        local onApp = isApp(active)
        local target
        for _, w in ipairs(hl.get_windows()) do
            if isApp(w) and not (onApp and w.address == active.address) and (not target
                    or (onApp and w.focus_history_id > target.focus_history_id)
                    or (not onApp and w.focus_history_id < target.focus_history_id)) then
                target = w
            end
        end
        return onApp or target ~= nil, target
    end

    local execCmd = hl.dsp.exec_cmd
    hl.dsp.exec_cmd = function(cmd, ...)
        local dispatcher = execCmd(cmd, ...)
        return function()
            local open, target = openWindow(cmd)
            if open then
                if target then hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address })) end
                return
            end
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
