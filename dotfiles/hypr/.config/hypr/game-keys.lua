-- Singularity - Hyprland
-- ~/.config/hypr/game-keys.lua
--
-- While a game has focus, fullscreen or windowed, every SUPER bind and
-- CTRL+SPACE are off, so a stray key can't pull up the launcher or move
-- the game; ALT+Tab and every other bind stay live. Required before
-- binds.lua: it wraps hl.bind to keep each bind's handle with its keys,
-- and returns the sync for hyprland.lua to run once they're all bound.
-- The Tabs binds are left to windows.lua's own switch (shared.tabBinds).

local S = require("shared")

local held = {}

local bind = hl.bind
hl.bind = function(keys, ...)
    local handle = bind(keys, ...)
    local k = type(keys) == "string" and keys:upper():gsub("%s", "") or ""
    if handle and (k:find("SUPER", 1, true) or k == "CTRL+SPACE") then
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

return sync
