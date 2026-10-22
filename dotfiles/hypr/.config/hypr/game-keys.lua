-- Singularity - Hyprland
-- ~/.config/hypr/game-keys.lua
--
-- While a game has focus, fullscreen or windowed, every SUPER bind,
-- CTRL+SPACE and the bare right-hand modifiers (media taps) are off, so a
-- stray key can't pull up the launcher, move the game or skip the music;
-- ALT+Tab and every other bind stay live. Required before
-- binds.lua: it wraps hl.bind to keep each bind's handle with its keys,
-- and returns the sync for hyprland.lua to run once they're all bound.
-- The Tabs binds are left to windows.lua's own switch (shared.tabBinds).
-- Also keeps games fullscreen and out of the scratchpad, and on the
-- desktop holds Power Saver while one is open.

local S = require("shared")

local held = {}

local bind = hl.bind
hl.bind = function(keys, ...)
    local handle = bind(keys, ...)
    local k = type(keys) == "string" and keys:upper():gsub("%s", "") or ""
    if handle and (k:find("SUPER", 1, true) or k == "CTRL+SPACE" or k:match("_R$")) then
        table.insert(held, handle)
    end
    return handle
end

-- Steam's games (Proton and native), gamescope, and anything that says
-- it's a game through the content-type protocol
local function isGame(win)
    if not win then return false end
    local class = win.class or ""
    return class:match("^steam_app_%d+$") ~= nil or class == "gamescope"
        or win.content_type == "game"
end

local inGame = false
local function sync()
    local on = isGame(hl.get_active_window())
    if on == inGame then return end
    inGame = on
    local tabs = {}
    for _, b in ipairs(S.tabBinds or {}) do tabs[b] = true end
    for _, b in ipairs(held) do
        if on then b:set_enabled(false)
        elseif not tabs[b] then b:set_enabled(true) end
    end
end

hl.on("window.active", sync)
hl.on("window.close", sync)

-- A game opened while the scratchpad is up would land in it, floating under
-- the bar; it goes to the workspace below instead, and the scratchpad closes.
hl.on("window.open", function(win)
    if not (win and isGame(win) and win.workspace and win.workspace.name == "special:scratchpad") then return end
    local mon = win.monitor
    local ws = mon and mon.active_workspace
    if not ws then return end
    local target = "address:" .. win.address
    hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = target }))
    if mon.active_special_workspace then
        hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
    end
    hl.dispatch(hl.dsp.focus({ window = target }))
end)

-- A window opened over a fullscreen game un-fullscreens it for good, and the
-- game, still screen-sized, floats half under the bar. Focused again, a
-- screen-sized game goes back to fullscreen.
hl.on("window.active", function()
    local win = hl.get_active_window()
    local mon = win and win.monitor
    if not (mon and isGame(win) and win.floating and win.fullscreen == 0) then return end
    if win.size.x >= mon.width / mon.scale and win.size.y >= mon.height / mon.scale then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = "address:" .. win.address }))
    end
end)

-- Desktop: Power Saver while any game is open, the picked profile back
-- after the last one closes (unless it was changed meanwhile). The 7700X
-- runs a game's shader compiling at 85 °C on Balanced and ~57 °C on Power
-- Saver, and games here are GPU-bound, so it costs no frames.
if S.state("machine", "") == "desktop" then
    local PPD = "busctl %s-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles"
        .. " org.freedesktop.UPower.PowerProfiles ActiveProfile"
    local saved = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/singularity-game-profile"
    local get = PPD:format("get") .. " | cut -d'\"' -f2"
    local hold = "p=$(" .. get .. "); [ \"$p\" != power-saver ] && [ ! -f " .. saved .. " ]"
        .. " && echo \"$p\" > " .. saved .. " && " .. PPD:format("set") .. " s power-saver"
    -- (not "[": exec_cmd reads a leading [...] as window rules)
    local release = "test -f " .. saved .. " && { [ \"$(" .. get .. ")\" = power-saver ] && "
        .. PPD:format("set") .. " s \"$(cat " .. saved .. ")\"; rm -f " .. saved .. "; }"

    local holding  -- nil until the first sync, so a reload settles a left-over hold
    local function syncProfile()
        local any = false
        for _, w in ipairs(hl.get_windows()) do
            if isGame(w) then any = true break end
        end
        if any == holding then return end
        holding = any
        hl.exec_cmd(any and hold or release)
    end
    hl.on("hyprland.start", syncProfile)
    hl.on("window.open", syncProfile)
    -- once the closed window is off the list
    hl.on("window.close", function() hl.timer(syncProfile, { timeout = 500, type = "oneshot" }) end)
    syncProfile()
end

return sync
