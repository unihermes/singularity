-- Singularity - Hyprland
-- ~/.config/hypr/game-keys.lua
--
-- While a game has focus, fullscreen or windowed, every SUPER bind,
-- CTRL+SPACE and the bare right-hand modifiers (media taps) are off, so a
-- stray key can't pull up the launcher, move the game or skip the music;
-- ALT+Tab, the recorder's binds and every other bind stay live. Required before
-- binds.lua: it wraps hl.bind to keep each bind's handle with its keys,
-- and returns the sync for hyprland.lua to run once they're all bound.
-- The Tabs binds are left to windows.lua's own switch (shared.tabBinds).
-- Also opens games on the primary display, keeps them fullscreen and out of
-- the scratchpad, turns vibrance off while one is open, and on the desktop
-- holds Power Saver meanwhile.

local S = require("shared")

local held = {}

-- Commands whose binds stay live in a game, on whatever keys they're given:
-- recording and saving the instant replay. S.cmdOf maps each exec_cmd
-- dispatcher to its command; hyprland.lua's exec_cmd wrapper fills it.
local LIVE_IN_GAME = { "qs ipc call recorder " }
S.cmdOf = setmetatable({}, { __mode = "k" })
local function liveInGame(action)
    local cmd = action ~= nil and S.cmdOf[action] or nil
    if type(cmd) ~= "string" then return false end
    for _, prefix in ipairs(LIVE_IN_GAME) do
        if cmd:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local bind = hl.bind
hl.bind = function(keys, action, ...)
    local handle = bind(keys, action, ...)
    local k = type(keys) == "string" and keys:upper():gsub("%s", "") or ""
    if handle and not liveInGame(action)
        and (k:find("SUPER", 1, true) or k == "CTRL+SPACE" or k:match("_R$")) then
        table.insert(held, handle)
    end
    return handle
end

-- Steam's games (Proton and native), gamescope, Minecraft ("Minecraft* 26.1.2"),
-- and anything that says it's a game through the content-type protocol
local function isGame(win)
    if not win then return false end
    local class = win.class or ""
    return class:match("^steam_app_%d+$") ~= nil or class == "gamescope"
        or class:match("^Minecraft") ~= nil or win.content_type == "game"
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

-- The primary display (the Display page's pick), else the first, as
-- displays.lua's singularityResetWorkspaces() has it.
local function primaryMonitor()
    local mons = hl.get_monitors()
    local name = S.state("primary-display", "")
    for _, m in ipairs(mons) do
        if m.name == name then return m end
    end
    return mons[1]
end

-- Games open on the primary display's current workspace. One opened on
-- another display moves there; one opened while the scratchpad is up would
-- land in it, floating under the bar, so it moves too and the scratchpad
-- closes.
hl.on("window.open", function(win)
    if not (win and isGame(win) and win.workspace) then return end
    local mon, primary = win.monitor, primaryMonitor()
    local inScratchpad = win.workspace.name == "special:scratchpad"
    if not primary or (not inScratchpad and mon and mon.name == primary.name) then return end
    local ws = primary.active_workspace
    if not ws then return end
    local target = "address:" .. win.address
    if inScratchpad and mon and mon.active_special_workspace then
        hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))
    end
    hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = target }))
    hl.dispatch(hl.dsp.focus({ window = target }))
end)

-- A focused game in windowed fullscreen (a screen-sized window, or one that
-- still thinks it's fullscreen after something took that away) is made
-- fullscreen, so it covers the bar instead of sliding half under it.
-- Checked on focus and again just after (alt-tab and the game's own resize
-- can land late), on open and a few seconds after (games size their window
-- once loaded), and when one leaves fullscreen, as it does when another
-- window opens over it.
local function coverBar()
    local win = hl.get_active_window()
    local mon = win and win.monitor
    if not (mon and isGame(win) and win.fullscreen == 0) then return end
    local screenSized = win.size.x >= mon.width / mon.scale and win.size.y >= mon.height / mon.scale
    if (win.floating and screenSized) or (win.fullscreen_client or 0) ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = "address:" .. win.address }))
    end
end
local function coverBarLater(ms) hl.timer(coverBar, { timeout = ms, type = "oneshot" }) end
hl.on("window.active", function()
    coverBar()
    coverBarLater(300)
end)
hl.on("window.open", function(win)
    if not (win and isGame(win)) then return end
    for _, ms in ipairs({ 500, 2000, 5000 }) do coverBarLater(ms) end
end)
hl.on("window.fullscreen", function() coverBarLater(500) end)

local function anyGameOpen()
    for _, w in ipairs(hl.get_windows()) do
        if isGame(w) then return true end
    end
    return false
end

-- Vibrance off while any game is open: its screen shader has Hyprland draw
-- every game frame itself, unevenly paced, which flickers with VRR. The
-- game gets direct scanout back meanwhile (looks.lua).
local vibranceOff  -- nil until the first sync; a reload turns it back on
local function syncVibrance()
    if not S.vibranceOn then return end
    local any = anyGameOpen()
    if any == vibranceOff then return end
    vibranceOff = any
    hl.config({
        decoration = { screen_shader = any and "" or S.vibranceShader },
        render     = { direct_scanout = any and 2 or 0 },
    })
end
hl.on("window.open", syncVibrance)
hl.on("window.close", function() hl.timer(syncVibrance, { timeout = 500, type = "oneshot" }) end)
syncVibrance()

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
        local any = anyGameOpen()
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
