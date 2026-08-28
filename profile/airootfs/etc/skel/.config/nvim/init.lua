-- CyberOS Neovim: sane defaults, no plugin manager required.
-- Students can add lazy.nvim later; see :help lua-guide.
local o = vim.opt
o.number = true
o.relativenumber = true
o.tabstop = 4
o.shiftwidth = 4
o.expandtab = true
o.smartindent = true
o.wrap = false
o.ignorecase = true
o.smartcase = true
o.termguicolors = true
o.signcolumn = "yes"
o.scrolloff = 8
o.clipboard = "unnamedplus"
o.undofile = true
o.updatetime = 250
o.splitright = true
o.splitbelow = true
o.mouse = "a"

vim.g.mapleader = " "
local map = vim.keymap.set
map("n", "<leader>w", ":w<CR>", { desc = "save" })
map("n", "<leader>q", ":q<CR>", { desc = "quit" })
map("n", "<leader>e", ":Explore<CR>", { desc = "file explorer" })
map("n", "<C-h>", "<C-w>h"); map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k"); map("n", "<C-l>", "<C-w>l")
map("n", "<Esc>", ":nohlsearch<CR>", { silent = true })

require("cyber")
