local M = {}

function M.setup()
  local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  if not vim.uv.fs_stat(path) then
    vim.fn.system({
      'git',
      'clone',
      '--filter=blob:none',
      '--branch=stable',
      'https://github.com/folke/lazy.nvim.git',
      path,
    })
    if vim.v.shell_error ~= 0 then error('Unable to install lazy.nvim') end
  end

  vim.opt.runtimepath:prepend(path)
  require('lazy').setup(require('plugins'), {
    change_detection = { notify = false },
    checker = { enabled = false },
    rocks = { enabled = false },
    ui = { border = 'rounded' },
  })
end

return M
