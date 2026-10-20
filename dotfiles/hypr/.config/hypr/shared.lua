-- Singularity - Hyprland
-- ~/.config/hypr/shared.lua
--
-- What several modules need: the Settings state files, read once per load,
-- and constants. binds.lua adds maxWorkspaces, tabBinds and appClasses.

local S = {}

-- a state file's first line (Quickshell writes it, then reloads config-only)
function S.state(name, default)
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/" .. name)
    if not f then return default end
    local v = f:read("l")
    f:close()
    return v or default
end

-- JSON from json.lua beside this file; missing or broken, every file it
-- reads decodes to nil.
do
    local ok, decoder = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/json.lua")
    S.decodeJson = ok and decoder or function() return nil end
end

-- Animation time, "<all> <windows> <workspaces>" percentages of looks.lua's
-- speeds; all scales everything (0: off), the others their own leaves.
do
    local all, win, ws = S.state("animations", ""):match("^(%d+)%s+(%d+)%s+(%d+)$")
    S.animFactor       = math.min(100, tonumber(all) or 100) / 100
    S.windowsFactor    = math.min(200, tonumber(win) or 100) / 100
    S.workspacesFactor = math.min(200, tonumber(ws) or 100) / 100
end
-- Game Mode strips animations here, and blur, shadows, gaps and rounding in
-- overrides.lua, without touching the saved settings.
S.gameMode = S.state("game-mode", "") == "on"
S.animOff  = S.animFactor == 0 or S.gameMode
-- This machine's display fixes by EDID model, a Lua file returning
--   { pcTimings  = { ["DELL P2418HZm"] = "modeline 138.50 ..." },
--     toneCurves = { ["DELL P2418HZm"] = 0.7 } }
-- pcTimings for TV-timed 1080p60 panels (displays.lua); toneCurves lift
-- shadows, out = in^value (autostart.lua). Missing or broken: none.
do
    local ok, t = pcall(dofile, os.getenv("HOME") .. "/.local/state/singularity/display-fixes.lua")
    S.displayFixes = ok and type(t) == "table" and t or {}
end

-- speed is in 100ms units (3 = 300ms), so lower is faster. SUPER+C times its
-- hand-made animations by these; see toggleMinimize() in windows.lua.
S.windowSpeed = 2
S.fadeSpeed   = 1.5

-- window open/close/minimize style from Appearance ("fade" is popin at full
-- size, "none" instant); SUPER+C follows it
local windowStyles = {
    popin = "popin 92%", zoom = "popin 70%", fade = "popin 100%", fold = "gnomed",
    slide = "slide", rise = "slide bottom", drop = "slide top", none = "popin 100%",
}
S.windowAnim = S.state("window-anim", "popin")
if not windowStyles[S.windowAnim] then S.windowAnim = "popin" end
S.windowStyle    = windowStyles[S.windowAnim]
S.windowsAnimate = S.windowAnim ~= "none"
-- SUPER+C: the styles that slide off-screen, and the shrink factor the rest
-- fade to
S.windowSlides = S.windowAnim == "slide" or S.windowAnim == "rise" or S.windowAnim == "drop"
S.windowShrink = ({ popin = { 0.92, 0.92 }, zoom = { 0.7, 0.7 }, fold = { 1, 0.05 } })[S.windowAnim]

-- The pointer theme picked on the Appearance page: set in env.lua, and
-- applied to the cursor Hyprland draws in autostart.lua.
local cursorTheme, cursorSize = S.state("cursor", ""):match("^(%S+)%s+(%d+)$")
S.cursorTheme = cursorTheme or "Bibata-Modern-Classic"
S.cursorSize  = cursorSize or "20"

-- the grouped windows' tab bar height, which fillArea() leaves room for
S.GROUPBAR_HEIGHT = 26

return S
