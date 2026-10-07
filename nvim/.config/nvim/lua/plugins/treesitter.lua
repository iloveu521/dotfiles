local parsers = { 'c', 'cpp', 'cmake', 'lua', 'bash', 'json', 'yaml', 'markdown', 'markdown_inline', 'vim', 'vimdoc' }

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    opts = {
      install_dir = vim.fn.stdpath('data') .. '/site',
      ensure_installed = parsers,
    },
    config = function(_, opts)
      local treesitter = require('nvim-treesitter')
      treesitter.setup({ install_dir = opts.install_dir })
      treesitter.install(opts.ensure_installed)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'c', 'cpp', 'cmake', 'lua', 'sh', 'json', 'yaml', 'markdown', 'vim', 'vimdoc' },
        callback = function(event)
          if not pcall(vim.treesitter.start, event.buf) then return end
          if vim.bo[event.buf].filetype ~= 'cpp' then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
