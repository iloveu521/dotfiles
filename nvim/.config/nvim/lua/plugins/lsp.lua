local function lsp_mappings(event)
  local opts = { buffer = event.buf }
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, vim.tbl_extend('force', opts, { desc = 'Go to declaration' }))
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, vim.tbl_extend('force', opts, { desc = 'References' }))
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, vim.tbl_extend('force', opts, { desc = 'Hover documentation' }))
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, vim.tbl_extend('force', opts, { desc = 'Code action' }))
  vim.keymap.set('n', '<leader>cr', vim.lsp.buf.rename, vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))
end

return {
  { 'williamboman/mason.nvim', cmd = 'Mason', opts = { ui = { border = 'rounded' } } },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      ensure_installed = { 'lua-language-server', 'stylua', 'codelldb', 'basedpyright', 'ruff' },
      run_on_start = true,
    },
  },
  { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'saghen/blink.cmp' },
    keys = {
      { '<M-d>', vim.lsp.buf.definition, desc = 'Go to definition' },
      {
        '<M-s>',
        function() require('telescope.builtin').lsp_definitions({ jump_type = 'never' }) end,
        desc = 'Preview definitions',
      },
    },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local project = require('core.project')
      local clangd = require('core.clangd')

      vim.lsp.config('clangd', {
        cmd = clangd.command(project.current()),
        capabilities = capabilities,
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
        root_markers = { 'compile_commands.json', 'CMakeLists.txt', '.git' },
        before_init = function(_, config)
          local context = project.detect(config.root_dir or vim.uv.cwd())
          config.cmd = clangd.command(context)
        end,
      })
      vim.lsp.config('lua_ls', {
        capabilities = capabilities,
        settings = { Lua = { diagnostics = { globals = { 'vim' } }, workspace = { checkThirdParty = false } } },
      })
      vim.lsp.config('basedpyright', {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoImportCompletions = true,
              diagnosticMode = 'openFilesOnly',
              typeCheckingMode = 'standard',
            },
          },
        },
      })
      vim.lsp.config('ruff', {
        capabilities = capabilities,
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      })
      vim.lsp.enable({ 'clangd', 'lua_ls', 'basedpyright', 'ruff' })

      vim.api.nvim_create_autocmd('LspAttach', { callback = lsp_mappings })
    end,
  },
}
