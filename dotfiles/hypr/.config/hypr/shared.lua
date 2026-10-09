-- Singularity - Hyprland
-- ~/.config/hypr/shared.lua
--
-- What more than one of hyprland.lua's modules needs: the state files the
-- shell's Settings write, read once per load, and a few constants. Every
-- module gets the same table from require("shared"); binds.lua adds
-- maxWorkspaces and tabBinds to it for windows.lua.

local S = {}

-- A state file in ~/.local/state/singularity, first line only. Quickshell
-- writes one and runs `hyprctl reload config-only`, which re-runs the config
-- -- so a setting survives a restart without the repo's config being
-- rewritten.
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

-- Animation time from the bar's Appearance page: a percentage of each speed
-- in looks.lua (speed is a duration, so 50 is twice as quick), and 0 turns
-- animations off entirely.
S.animFactor = math.max(0, math.min(100, tonumber(S.state("animations", "100")) or 100)) / 100
-- Game Mode, the Control Centre's switch: "on" in its state file strips the
-- desktop's effects -- animations here, and blur, shadows, gaps and rounding
-- in overrides.lua, after the local settings, so it outranks them without
-- touching them and turning it off brings every one back as it was.
S.gameMode = S.state("game-mode", "") == "on"
S.animOff  = S.animFactor == 0 or S.gameMode
-- Which machine install.sh set this up as. The desktop's own display fixes
-- (displays.lua, autostart.lua) apply only there.
S.desktop = S.state("machine", "") == "desktop"

-- speed is in 100ms units (3 = 300ms), so lower is faster. SUPER+C times its
-- hand-made animations by these; see toggleMinimize() in windows.lua.
S.windowSpeed = 2
S.fadeSpeed   = 1.5

-- How windows open, close, minimize and restore, picked on the Appearance
-- page. "fade" is popin at full size, so the window only fades, and "none"
-- shows and hides them at once. SUPER+C follows the same choice by hand.
local windowStyles = {
    popin = "popin 92%", zoom = "popin 70%", fade = "popin 100%", fold = "gnomed",
    slide = "slide", rise = "slide bottom", drop = "slide top", none = "popin 100%",
}
S.windowAnim = S.state("window-anim", "popin")
if not windowStyles[S.windowAnim] then S.windowAnim = "popin" end
S.windowStyle    = windowStyles[S.windowAnim]
S.windowsAnimate = S.windowAnim ~= "none"
-- SUPER+C's version: the styles that move the window off-screen (up for
-- drop, down for the others), and the size the rest shrink to as they fade,
-- as fractions of width and height (fold collapses to a line, as gnomed does)
S.windowSlides = S.windowAnim == "slide" or S.windowAnim == "rise" or S.windowAnim == "drop"
S.windowShrink = ({ popin = { 0.92, 0.92 }, zoom = { 0.7, 0.7 }, fold = { 1, 0.05 } })[S.windowAnim]

-- The pointer theme picked on the Appearance page: set in env.lua, and
-- applied to the cursor Hyprland draws in autostart.lua.
local cursorTheme, cursorSize = S.state("cursor", ""):match("^(%S+)%s+(%d+)$")
S.cursorTheme = cursorTheme or "Bibata-Modern-Classic"
S.cursorSize  = cursorSize or "20"

-- The tab bar over grouped windows. A floating group draws it above the
-- windows, flush against them, so windows.lua's fillArea() leaves this much
-- room for it.
S.GROUPBAR_HEIGHT = 26

return S
