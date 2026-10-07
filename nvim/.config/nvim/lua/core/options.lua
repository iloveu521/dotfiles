local M = {}

function M.setup()
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  local opt = vim.opt
  opt.number = true
  opt.relativenumber = true
  opt.mouse = 'a'
  opt.clipboard = 'unnamedplus'
  opt.undofile = true
  opt.ignorecase = true
  opt.smartcase = true
  opt.signcolumn = 'yes'
  opt.updatetime = 250
  opt.timeoutlen = 400
  opt.splitright = true
  opt.splitbelow = true
  opt.termguicolors = true
  opt.cursorline = true
  opt.scrolloff = 8
  opt.sidescrolloff = 8
  opt.expandtab = true
  opt.shiftwidth = 2
  opt.tabstop = 2
  opt.softtabstop = 2
  opt.smartindent = true
  opt.wrap = false
  opt.completeopt = { 'menu', 'menuone', 'noselect' }
end

return M

