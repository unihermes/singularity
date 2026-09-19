-- Loaded on VeryLazy. LazyVim's defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Follow the shell's look live: AppearanceSync.qml rewrites the palette file
-- whenever the look, colour mode or wallpaper changes (by atomic rename, so
-- watch the directory, not the file), and every open nvim reloads the scheme.
local palette = require("config.palette")
local watcher = vim.uv.new_fs_event()
local reload = vim.uv.new_timer()
if watcher and reload then
  local dir = vim.fs.dirname(palette.path)
  vim.fn.mkdir(dir, "p")
  watcher:start(dir, {}, function(err, name)
    if err or name ~= vim.fs.basename(palette.path) then return end
    reload:start(100, 0, vim.schedule_wrap(function()
      if vim.g.colors_name == "neutrino" then vim.cmd.colorscheme("neutrino") end
    end))
  end)
end
