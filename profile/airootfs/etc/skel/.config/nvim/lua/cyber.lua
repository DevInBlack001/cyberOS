-- CyberOS colourscheme. Colours come from cyberos-theme so the editor
-- follows the rest of the desktop when light/dark is switched.
vim.cmd.colorscheme("habamax")
local ok, c = pcall(require, "cyber_colors")
if not ok then return end
vim.o.background = c.dark and "dark" or "light"
local hi = function(g, s) vim.api.nvim_set_hl(0, g, s) end
hi("Normal",       { fg = c.fg, bg = c.bg })
hi("NormalFloat",  { fg = c.fg, bg = c.surface })
hi("LineNr",       { fg = c.muted })
hi("CursorLineNr", { fg = c.accent, bold = true })
hi("Comment",      { fg = c.muted, italic = true })
hi("String",       { fg = c.accent2 })
hi("Function",     { fg = c.accent })
hi("Keyword",      { fg = c.alert })
hi("Type",         { fg = c.cyan })
hi("Constant",     { fg = c.accent2 })
hi("Visual",       { bg = c.sel })
hi("StatusLine",   { fg = c.bg, bg = c.accent, bold = true })
hi("StatusLineNC", { fg = c.muted, bg = c.surface })
hi("Pmenu",        { fg = c.fg, bg = c.surface })
hi("PmenuSel",     { fg = c.bg, bg = c.accent })
hi("Search",       { fg = c.bg, bg = c.accent2 })
hi("VertSplit",    { fg = c.border })
