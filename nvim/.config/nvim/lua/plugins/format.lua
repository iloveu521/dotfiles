return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>cf',
        function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
        mode = { 'n', 'v' },
        desc = 'Format code',
      },
      {
        '<M-f>',
        function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
        mode = { 'n', 'v', 'i' },
        desc = 'Format code',
      },
      {
        '<leader>uf',
        function()
          local enabled = require('core.format').toggle()
          vim.notify('Format on save ' .. (enabled and 'enabled' or 'disabled'))
        end,
        desc = 'Toggle format on save',
      },
    },
    opts = {
      formatters_by_ft = {
        c = { 'clang_format' },
        cpp = { 'clang_format' },
        lua = { 'stylua' },
        cmake = { 'cmake_format' },
        python = { 'ruff_format' },
      },
      formatters = { clang_format = { command = 'clang-format' } },
      format_on_save = function(bufnr)
        if not require('core.format').is_enabled(bufnr) then return nil end
        return { timeout_ms = 1500, lsp_format = 'fallback' }
      end,
    },
  },
}
