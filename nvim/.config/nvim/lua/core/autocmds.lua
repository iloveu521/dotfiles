local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup('nvim-workspace-core', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    desc = 'Use Google-style four-space indentation for C and C++',
    callback = function()
      vim.bo.expandtab = true
      vim.bo.shiftwidth = 4
      vim.bo.tabstop = 4
      vim.bo.softtabstop = 4
    end,
  })

  vim.api.nvim_create_autocmd('TextYankPost', {
    group = group,
    desc = 'Highlight text after yanking',
    callback = function() vim.highlight.on_yank({ timeout = 180 }) end,
  })
end

return M

