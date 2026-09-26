-- The shell's look instead of LazyVim's bundled themes. colors/singularity.lua
-- builds everything from ~/.local/state/singularity/nvim.lua (written by
-- AppearanceSync.qml), and lua/config/autocmds.lua reloads it on change.

-- Modes are told apart by lightness, with the look's accent on the ones
-- that edit.
local function lualine_theme()
  local c = require("config.palette").load()
  local edit = { fg = c.bg, bg = c.accent, gui = "bold" }
  local other = { fg = c.bg, bg = c.subtext, gui = "bold" }
  return {
    normal   = { a = { fg = c.bg, bg = c.text, gui = "bold" },
                 b = { fg = c.text, bg = c.overlay },
                 c = { fg = c.subtext, bg = c.bg_alt } },
    insert   = { a = edit },
    replace  = { a = edit },
    terminal = { a = edit },
    visual   = { a = other },
    command  = { a = other },
    inactive = { a = { fg = c.muted, bg = c.bg_alt },
                 b = { fg = c.muted, bg = c.bg_alt },
                 c = { fg = c.muted, bg = c.bg_alt } },
  }
end

return {
  { "LazyVim/LazyVim", opts = { colorscheme = "singularity" } },
  { "folke/tokyonight.nvim", enabled = false },
  { "catppuccin/nvim", enabled = false },

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options.theme = lualine_theme()
      opts.options.section_separators = { left = "", right = "" }
      opts.options.component_separators = ""
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      -- a table theme doesn't follow the scheme by itself; rebuild it
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "singularity",
        callback = function()
          opts.options.theme = lualine_theme()
          require("lualine").setup(opts)
        end,
      })
    end,
  },
}
