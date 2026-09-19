-- Loaded before LazyVim's plugins. LazyVim's defaults:
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local o = vim.opt

-- Absolute numbers only, so the gutter stays still as the cursor moves;
-- <space>ul toggles relative numbers when a count is wanted.
o.relativenumber = false
o.numberwidth = 4

o.mouse = "a"
o.mousemoveevent = true -- hover highlight on tabs
o.winborder = "rounded"
o.list = true
o.listchars = { tab = "\u{2502} ", trail = "\u{00b7}" }
o.fillchars:append({ vert = "\u{2502}" })
