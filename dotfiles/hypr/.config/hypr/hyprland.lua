-- Singularity - Hyprland
-- ~/.config/hypr/hyprland.lua
--
-- The Lua config. It only runs the modules beside it, in order:
--
--   shared     the Settings state files and constants the others share
--   displays   monitor rules, docked mode, workspaces across displays
--   env        environment variables
--   autostart  what starts with the session
--   looks      gaps, borders, shadows, blur, tabs, animations
--   input      keyboard, mouse, touchpad, gestures
--   overrides  this machine's hyprland.json, then Game Mode
--   game-keys  SUPER binds and CTRL+SPACE off while a game has focus
--   binds      every keybind; the Keybinds window rewrites this one
--   windows    monocle, popouts, scratchpad, tabs (with window-rules and
--              window-keys)
--
-- Every reload starts a fresh Lua state, so each module runs once per load.

require("shared")
require("displays")
require("env")
require("autostart")
require("looks")
require("input")
require("overrides")
local syncGameKeys = require("game-keys")

-- An app bind focuses the app when it's open (cycling through its windows,
-- least recently used next), classes from shared.appClasses; otherwise it
-- marks a launch (markLaunch) and runs. Wrapped here so binds keep the plain
-- hl.dsp.exec_cmd("...") form the Keybinds window edits.
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
        local run = function()
            local open, target = openWindow(cmd)
            if open then
                if target then
                    local addr = "address:" .. target.address
                    -- focus alone leaves a floating window under the others
                    hl.dispatch(hl.dsp.focus({ window = addr }))
                    hl.dispatch(hl.dsp.window.bring_to_top({ window = addr }))
                end
                return
            end
            if markLaunch then markLaunch() end
            hl.dispatch(dispatcher)
        end
        -- what it runs, for game-keys.lua
        shared.cmdOf[run] = cmd
        return run
    end
end

require("binds")
require("windows")
syncGameKeys()

-- ~/.local/state/singularity/custom.lua runs last, so it wins; a failure
-- shows a notification.
do
    local path = os.getenv("HOME") .. "/.local/state/singularity/custom.lua"
    local ok, err = pcall(dofile, path)
    if not ok and not tostring(err):find("cannot open", 1, true) then
        hl.exec_cmd("notify-send -a Hyprland -u critical 'custom.lua' '"
            .. tostring(err):gsub("'", "’") .. "'")
    end
end
