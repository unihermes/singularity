-- The active look's palette, as the shell hands it out. AppearanceSync.qml
-- writes ~/.local/state/singularity/nvim.lua whenever the look, the colour mode
-- or the wallpaper palette changes; until the shell has run once (or outside
-- the desktop) this falls back to Neutrino's ramp from Looks.js.

local M = {}

M.path = vim.fn.expand("~/.local/state/singularity/nvim.lua")

local fallback = {
  base = "#0b0b0b", bar = "#121212", panel = "#141414", surface = "#1a1a1a",
  overlay = "#242424", border = "#303030", muted = "#4d4d4d", subtext = "#7a7a7a",
  text = "#d4e4f4", bright = "#ebebeb",
  accent = "#ebebeb", good = "#7d9b7d", alert = "#a87676",
}

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

-- a + (b - a) * t per channel, the same as AppearanceSync's mix()
function M.mix(a, b, t)
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  local ch = function(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return string.format("#%02x%02x%02x", ch(ar, br), ch(ag, bg), ch(ab, bb))
end

function M.load()
  local ok, roles = pcall(dofile, M.path)
  if not ok or type(roles) ~= "table" then roles = {} end
  local r = vim.tbl_extend("force", fallback, roles)

  -- The names the colour scheme and statusline use, mapped onto the shell's
  -- roles: the editor sits on base, its chrome (tabs, statusline, tree) on
  -- the bar's ground, and floats on the flyouts' panel.
  local r_, g_, b_ = rgb(r.base)
  return {
    bg = r.base, bg_alt = r.bar, panel = r.panel, surface = r.surface,
    overlay = r.overlay, border = r.border, muted = r.muted, subtext = r.subtext,
    text = r.text, bright = r.bright,
    accent = r.accent, good = r.good, alert = r.alert,
    -- a light look swaps grounds and foreground; nvim wants to know
    light = (0.2126 * r_ + 0.7152 * g_ + 0.0722 * b_) > 128,
  }
end

return M
