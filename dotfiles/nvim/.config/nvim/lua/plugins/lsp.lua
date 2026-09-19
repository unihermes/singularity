-- Language servers beyond LazyVim's language extras.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- ships with qt6-declarative, outside PATH and not in Mason. -E reads
        -- QML_IMPORT_PATH, which is how it finds Quickshell's modules.
        qmlls = {
          mason = false,
          cmd = { "/usr/lib/qt6/bin/qmlls", "-E" },
          enabled = vim.fn.executable("/usr/lib/qt6/bin/qmlls") == 1,
        },
        bashls = {},
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "bash", "c", "cpp", "css", "html", "qmljs" } },
  },
}
