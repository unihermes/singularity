-- Singularity - nvim
-- ~/.config/nvim/init.lua
--
-- LazyVim (https://lazyvim.org) with the shell's look on top:
--   lua/config/lazy.lua      bootstraps lazy.nvim and LazyVim
--   lua/config/options.lua   options on top of LazyVim's defaults
--   lua/config/keymaps.lua   familiar editor shortcuts on top of LazyVim's
--   lua/config/autocmds.lua  recolours when the shell's look changes
--   lua/plugins/             language extras, theme hookup, overrides
--   colors/neutrino.lua      the colour scheme, built from the active look
--
-- Press <space> and wait to see every binding; :LazyExtras adds languages
-- and features, :Mason adds language servers.

require("config.lazy")
