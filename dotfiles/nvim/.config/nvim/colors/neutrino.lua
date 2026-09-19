-- Singularity - nvim colour scheme
-- ~/.config/nvim/colors/neutrino.lua
--
-- The shell's active look (see lua/config/palette.lua), so the editor
-- changes with the bar, the terminal and the notifications. Syntax is carried
-- by weight and lightness instead of hue: comments recede, strings and
-- constants sit mid ramp, keywords and identifiers come forward. The look's
-- three hues are used the way the shell uses them: accent for marks (the
-- current line number, the current tab, search hits, the mode), good and
-- alert for state (added/removed lines, errors).

local palette = require("config.palette")
local c = palette.load()
local mix = palette.mix

vim.cmd.highlight("clear")
vim.o.background = c.light and "light" or "dark"
vim.g.colors_name = "neutrino"

local groups = {
  -- editor --------------------------------------------------------------
  Normal         = { fg = c.text,    bg = c.bg },
  NormalNC       = { fg = c.text,    bg = c.bg },
  NormalFloat    = { fg = c.text,    bg = c.panel },
  FloatBorder    = { fg = c.border,  bg = c.panel },
  FloatTitle     = { fg = c.bright,  bg = c.panel, bold = true },
  CursorLine     = { bg = c.bg_alt },
  CursorColumn   = { bg = c.bg_alt },
  ColorColumn    = { bg = c.bg_alt },
  CursorLineNr   = { fg = c.accent,  bold = true },
  LineNr         = { fg = c.muted },
  SignColumn     = { bg = c.bg },
  FoldColumn     = { fg = c.muted,   bg = c.bg },
  Folded         = { fg = c.subtext, bg = c.surface },
  VertSplit      = { fg = c.border },
  WinSeparator   = { fg = c.border },
  Visual         = { bg = c.overlay },
  Search         = { fg = c.bg,      bg = c.subtext },
  CurSearch      = { fg = c.bg,      bg = c.accent },
  IncSearch      = { fg = c.bg,      bg = c.accent },
  Substitute     = { fg = c.bg,      bg = c.text },
  MatchParen     = { fg = c.accent,  bg = c.overlay, bold = true },
  Pmenu          = { fg = c.text,    bg = c.surface },
  PmenuSel       = { fg = c.bg,      bg = c.text },
  PmenuSbar      = { bg = c.surface },
  PmenuThumb     = { bg = c.muted },
  StatusLine     = { fg = c.subtext, bg = c.bg_alt },
  StatusLineNC   = { fg = c.muted,   bg = c.bg_alt },
  TabLine        = { fg = c.muted,   bg = c.bg_alt },
  TabLineFill    = { bg = c.bg_alt },
  TabLineSel     = { fg = c.bright,  bg = c.bg, bold = true },
  WinBar         = { fg = c.subtext, bg = c.bg },
  WinBarNC       = { fg = c.muted,   bg = c.bg },
  Title          = { fg = c.bright,  bold = true },
  Directory      = { fg = c.text,    bold = true },
  Whitespace     = { fg = c.overlay },
  NonText        = { fg = c.overlay },
  SpecialKey     = { fg = c.muted },
  EndOfBuffer    = { fg = c.bg },
  ErrorMsg       = { fg = c.bright,  bold = true },
  WarningMsg     = { fg = c.text },
  MoreMsg        = { fg = c.text },
  ModeMsg        = { fg = c.accent,  bold = true },
  Question       = { fg = c.text },
  QuickFixLine   = { bg = c.overlay },
  SpellBad       = { undercurl = true, sp = c.subtext },
  SpellCap       = { undercurl = true, sp = c.muted },

  -- syntax --------------------------------------------------------------
  Comment        = { fg = c.muted,   italic = true },
  Constant       = { fg = c.text },
  String         = { fg = c.subtext },
  Character      = { fg = c.subtext },
  Number         = { fg = c.text },
  Boolean        = { fg = c.text,    bold = true },
  Identifier     = { fg = c.text },
  Function       = { fg = c.bright,  bold = true },
  Statement      = { fg = c.bright },
  Keyword        = { fg = c.bright,  bold = true },
  Operator       = { fg = c.subtext },
  Delimiter      = { fg = c.subtext },
  PreProc        = { fg = c.subtext },
  Type           = { fg = c.text,    bold = true },
  Special        = { fg = c.subtext },
  Underlined     = { underline = true },
  Todo           = { fg = c.bg,      bg = c.subtext, bold = true },
  Error          = { fg = c.bright,  bg = c.overlay },

  -- treesitter ----------------------------------------------------------
  -- Most captures already link to the syntax groups above by default; these
  -- are the ones whose defaults carry hue.
  ["@variable"]           = { fg = c.text },
  ["@variable.builtin"]   = { fg = c.text,    italic = true },
  ["@variable.parameter"] = { fg = c.text,    italic = true },
  ["@variable.member"]    = { fg = c.text },
  ["@property"]           = { fg = c.text },
  ["@module"]             = { fg = c.text },
  ["@constructor"]        = { fg = c.bright },
  ["@punctuation"]        = { fg = c.subtext },
  ["@tag"]                = { fg = c.bright },
  ["@tag.attribute"]      = { fg = c.subtext, italic = true },
  ["@tag.delimiter"]      = { fg = c.muted },
  ["@markup.heading"]     = { fg = c.bright,  bold = true },
  ["@markup.strong"]      = { bold = true },
  ["@markup.italic"]      = { italic = true },
  ["@markup.link"]        = { fg = c.subtext, underline = true },
  ["@markup.raw"]         = { fg = c.subtext },
  ["@markup.list"]        = { fg = c.subtext },
  ["@lsp.type.comment"]   = {},

  -- diff / git ----------------------------------------------------------
  DiffAdd        = { bg = mix(c.bg, c.good, 0.15) },
  DiffDelete     = { fg = c.muted,   bg = mix(c.bg, c.alert, 0.12) },
  DiffChange     = { bg = c.bg_alt },
  DiffText       = { bg = c.overlay, bold = true },
  Added          = { fg = c.good },
  Changed        = { fg = c.subtext },
  Removed        = { fg = c.alert },
  GitSignsAdd    = { fg = c.good },
  GitSignsChange = { fg = c.subtext },
  GitSignsDelete = { fg = c.alert },
  GitSignsCurrentLineBlame = { fg = c.muted, italic = true },

  -- diagnostics ---------------------------------------------------------
  DiagnosticError = { fg = c.alert,  bold = true },
  DiagnosticWarn  = { fg = c.text },
  DiagnosticInfo  = { fg = c.subtext },
  DiagnosticHint  = { fg = c.muted },
  DiagnosticOk    = { fg = c.good },
  DiagnosticUnderlineError = { undercurl = true, sp = c.alert },
  DiagnosticUnderlineWarn  = { undercurl = true, sp = c.subtext },
  DiagnosticUnderlineInfo  = { underline = true, sp = c.muted },
  DiagnosticUnderlineHint  = { underline = true, sp = c.border },
  DiagnosticVirtualTextError = { fg = c.alert,   bg = c.bg_alt },
  DiagnosticVirtualTextWarn  = { fg = c.muted,   bg = c.bg_alt },
  DiagnosticVirtualTextInfo  = { fg = c.muted,   bg = c.bg_alt },
  DiagnosticVirtualTextHint  = { fg = c.muted,   bg = c.bg_alt },
  DiagnosticUnnecessary      = { fg = c.muted },
  LspReferenceText  = { bg = c.surface },
  LspReferenceRead  = { bg = c.surface },
  LspReferenceWrite = { bg = c.surface, underline = true },
  LspInlayHint      = { fg = c.muted, italic = true },
  LspSignatureActiveParameter = { fg = c.bright, bold = true, underline = true },

  -- explorer, command line, jump labels ---------------------------------
  SnacksPickerDir         = { fg = c.muted },
  SnacksPickerPathHidden  = { fg = c.muted },
  SnacksPickerPathIgnored = { fg = c.border },
  SnacksPickerGitStatusAdded     = { fg = c.good },
  SnacksPickerGitStatusUntracked = { fg = c.good },
  SnacksPickerGitStatusModified  = { fg = c.subtext },
  SnacksPickerGitStatusDeleted   = { fg = c.alert },
  SnacksPickerGitStatusStaged    = { fg = c.accent },
  SnacksPickerTree        = { fg = c.border },
  NoiceCmdlinePopup       = { fg = c.text,    bg = c.panel },
  NoiceCmdlinePopupBorder = { fg = c.border,  bg = c.panel },
  NoiceCmdlinePopupTitle  = { fg = c.bright,  bg = c.panel, bold = true },
  NoiceCmdlineIcon        = { fg = c.accent },
  NoiceCmdlinePopupBorderSearch = { fg = c.border, bg = c.panel },
  NoiceCmdlineIconSearch  = { fg = c.accent },
  NoiceConfirmBorder      = { fg = c.border,  bg = c.panel },
  NoiceMini               = { fg = c.subtext, bg = c.bg_alt },
  FlashBackdrop           = { fg = c.muted },
  FlashMatch              = { fg = c.text,    bg = c.overlay },
  FlashCurrent            = { fg = c.bright,  bg = c.overlay, bold = true },
  FlashLabel              = { fg = c.bg,      bg = c.accent, bold = true },
  LazyNormal              = { fg = c.text,    bg = c.panel },
  LazyH1                  = { fg = c.bg,      bg = c.accent, bold = true },
  LazyButton              = { fg = c.text,    bg = c.surface },
  LazyButtonActive        = { fg = c.bg,      bg = c.text, bold = true },
  LazySpecial             = { fg = c.accent },
  MasonNormal             = { fg = c.text,    bg = c.panel },
  MasonHeader             = { fg = c.bg,      bg = c.accent, bold = true },
  MasonHighlight          = { fg = c.accent },
  MasonHighlightBlock     = { fg = c.bg,      bg = c.accent },
  MasonHighlightBlockBold = { fg = c.bg,      bg = c.accent, bold = true },
  MasonMuted              = { fg = c.muted },
  MasonMutedBlock         = { fg = c.text,    bg = c.surface },
  RenderMarkdownCode      = { bg = c.bg_alt },
  RenderMarkdownCodeInline = { fg = c.text,   bg = c.surface },
  RenderMarkdownBullet    = { fg = c.subtext },
  TodoBgTODO              = { fg = c.bg,      bg = c.text, bold = true },
  TodoFgTODO              = { fg = c.text },

  -- completion ----------------------------------------------------------
  BlinkCmpMenu            = { fg = c.text,    bg = c.panel },
  BlinkCmpMenuBorder      = { fg = c.border,  bg = c.panel },
  BlinkCmpMenuSelection   = { bg = c.overlay, bold = true },
  BlinkCmpLabelMatch      = { fg = c.accent,  bold = true },
  BlinkCmpLabelDeprecated = { fg = c.muted,   strikethrough = true },
  BlinkCmpKind            = { fg = c.subtext },
  BlinkCmpSource          = { fg = c.muted },
  BlinkCmpLabelDetail     = { fg = c.muted },
  BlinkCmpLabelDescription = { fg = c.muted },
  BlinkCmpDoc             = { fg = c.text,    bg = c.panel },
  BlinkCmpDocBorder       = { fg = c.border,  bg = c.panel },
  BlinkCmpGhostText       = { fg = c.muted,   italic = true },
  BlinkCmpSignatureHelp   = { fg = c.text,    bg = c.panel },
  BlinkCmpSignatureHelpBorder = { fg = c.border, bg = c.panel },

  -- picker / which-key / indent -----------------------------------------
  SnacksPickerMatch       = { fg = c.accent,  bold = true },
  SnacksPickerTitle       = { fg = c.bright,  bg = c.panel, bold = true },
  SnacksPickerPrompt      = { fg = c.bright },
  SnacksPickerSelected    = { fg = c.bright },
  SnacksIndent            = { fg = c.surface },
  SnacksIndentScope       = { fg = c.border },
  SnacksDashboardHeader   = { fg = c.bright },
  SnacksDashboardIcon     = { fg = c.subtext },
  SnacksDashboardKey      = { fg = c.accent,  bold = true },
  SnacksDashboardDesc     = { fg = c.text },
  SnacksDashboardFooter   = { fg = c.muted,   italic = true },
  WhichKey                = { fg = c.accent,  bold = true },
  WhichKeyGroup           = { fg = c.text },
  WhichKeyDesc            = { fg = c.subtext },
  WhichKeySeparator       = { fg = c.muted },
  WhichKeyIcon            = { fg = c.subtext },
  TroubleNormal           = { fg = c.text,    bg = c.bg_alt },
  TroubleNormalNC         = { fg = c.text,    bg = c.bg_alt },

  -- tabs ----------------------------------------------------------------
  BufferLineFill              = { bg = c.bg_alt },
  BufferLineBackground        = { fg = c.muted,   bg = c.bg_alt },
  BufferLineBufferVisible     = { fg = c.subtext, bg = c.bg_alt },
  BufferLineBufferSelected    = { fg = c.bright,  bg = c.bg, bold = true },
  BufferLineIndicatorSelected = { fg = c.accent,  bg = c.bg },
  BufferLineModified          = { fg = c.muted,   bg = c.bg_alt },
  BufferLineModifiedSelected  = { fg = c.text,    bg = c.bg },
  BufferLineCloseButton       = { fg = c.muted,   bg = c.bg_alt },
  BufferLineCloseButtonSelected = { fg = c.subtext, bg = c.bg },
  BufferLineSeparator         = { fg = c.bg_alt,  bg = c.bg_alt },
  BufferLineSeparatorSelected = { fg = c.bg_alt,  bg = c.bg },
  BufferLineOffsetSeparator   = { fg = c.bg,      bg = c.bg_alt },
}

-- mini.icons draws every file and folder icon (LazyVim routes devicons
-- through it too); its nine hues become steps on the ramp.
for name, col in pairs({
  Azure = c.text, Blue = c.text, Cyan = c.subtext, Green = c.subtext, Grey = c.muted,
  Orange = c.text, Purple = c.subtext, Red = c.text, Yellow = c.bright,
}) do
  groups["MiniIcons" .. name] = { fg = col }
end

for group, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, group, spec)
end

-- Terminal buffers (the toggle terminal, lazygit) get the same ANSI slots
-- AppearanceSync gives alacritty: normal climbs muted -> text, bright climbs
-- subtext -> bright, each ending on its role exactly.
vim.g.terminal_color_0 = c.surface
vim.g.terminal_color_8 = c.border
for i = 1, 6 do
  vim.g["terminal_color_" .. i] = mix(c.muted, c.text, i / 7)
  vim.g["terminal_color_" .. (i + 8)] = mix(c.subtext, c.bright, i / 7)
end
vim.g.terminal_color_7 = c.text
vim.g.terminal_color_15 = c.bright
