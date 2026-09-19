-- Loaded on VeryLazy, after LazyVim's own keys:
-- https://www.lazyvim.org/keymaps  (or <space>sk to search them)
--
-- LazyVim already covers most of the everyday ones -- Ctrl+S save, Shift+H/L
-- between tabs, <space>e file tree, <space>ff files, <space>/ grep,
-- <space>gg lazygit, <space>xx problems, <space>cf format, <space>cr rename.
-- These add the shortcuts other editors use. Alacritty speaks the kitty
-- keyboard protocol, so Ctrl+/ , Ctrl+` and Ctrl+Shift+F arrive as
-- themselves; ^_ and ^\ are the fallbacks for terminals that don't.

local map = function(mode, lhs, rhs, desc, opts)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { desc = desc, silent = true }, opts or {}))
end

map("n", "<C-p>", function() Snacks.picker.files() end, "Find file")
map("n", "<C-S-f>", function() Snacks.picker.grep() end, "Search in files")
map("n", "<C-S-p>", function() Snacks.picker.commands() end, "Command palette")
map("n", "<C-b>", function() Snacks.explorer() end, "Toggle file tree")
map("n", "<C-S-m>", "<cmd>Trouble diagnostics toggle<cr>", "Problems")

-- Ctrl+/ comments, as everywhere else. LazyVim puts its terminal there, so
-- the terminal moves to Ctrl+` (and Ctrl+\).
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
  pcall(vim.keymap.del, { "n", "t" }, key)
  map("n", key, "gcc", "Toggle comment", { remap = true })
  map("x", key, "gc", "Toggle comment", { remap = true })
  map("i", key, "<esc>gcca", "Toggle comment", { remap = true })
end
for _, key in ipairs({ "<C-`>", "<C-\\>" }) do
  map({ "n", "t" }, key, function() Snacks.terminal.toggle() end, "Toggle terminal")
end

-- Alt+Up/Down moves lines (LazyVim's own are Alt+J/K).
map("n", "<A-Up>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", "Move line up")
map("n", "<A-Down>", "<cmd>execute 'move .+' . v:count1<cr>==", "Move line down")
map("i", "<A-Up>", "<esc><cmd>move .-2<cr>==gi", "Move line up")
map("i", "<A-Down>", "<esc><cmd>move .+1<cr>==gi", "Move line down")
map("x", "<A-Up>", ":move '<-2<cr>gv=gv", "Move selection up")
map("x", "<A-Down>", ":move '>+1<cr>gv=gv", "Move selection down")

-- tabs
map("n", "<C-PageDown>", "<cmd>BufferLineCycleNext<cr>", "Next tab")
map("n", "<C-PageUp>", "<cmd>BufferLineCyclePrev<cr>", "Previous tab")
for i = 1, 9 do
  map("n", "<A-" .. i .. ">", "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", "Go to tab " .. i)
end

-- code
map("n", "<F12>", function() Snacks.picker.lsp_definitions() end, "Go to definition")
map("n", "<S-F12>", function() Snacks.picker.lsp_references() end, "References")
map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
map({ "n", "x" }, "<C-.>", vim.lsp.buf.code_action, "Code action")
map({ "n", "x" }, "<A-S-f>", function() LazyVim.format({ force = true }) end, "Format")
map("n", "<F8>", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next problem")
map("n", "<S-F8>", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous problem")
