-- Singularity - Hyprland
-- ~/.config/hypr/overrides.lua
--
-- This machine's changes over the repo's settings, then Game Mode over
-- everything.

local S = require("shared")

-- Local settings (Settings > Input, Appearance > Windows) from hyprland.json,
-- applied over input.lua and looks.lua one value at a time, so a rejected
-- one only skips itself. Missing or broken: nothing.
do
    local f = io.open(os.getenv("HOME") .. "/.local/state/singularity/hyprland.json")
    local t = f and S.decodeJson(f:read("a"))
    if f then f:close() end

    local function apply(tbl, wrap)
        for k, v in pairs(tbl) do
            local function nest(x) return wrap({ [k] = x }) end
            if type(v) == "table" then
                apply(v, nest)
            else
                pcall(hl.config, nest(v))
            end
        end
    end
    if type(t) == "table" then apply(t, function(x) return x end) end
end

if S.gameMode then
    hl.config({
        general    = { gaps_in = 0, gaps_out = 0 },
        decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } },
        animations = { enabled = false },
    })
end
