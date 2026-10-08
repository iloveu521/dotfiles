--[[
  plugins/lsp.lua — 语言服务器（LSP）与配套工具链

  分工：
    * mason.nvim            —— LSP / 格式化器 / 调试器二进制的统一安装界面（:Mason）；
    * mason-tool-installer  —— 声明式工具清单，启动时自动补齐缺失的工具；
    * fidget.nvim           —— 右下角显示 LSP 进度（索引进度、加载状态）；
    * nvim-lspconfig        —— 各语言服务器的配置与启用（Neovim 0.11+ 的 vim.lsp.config / vim.lsp.enable 写法）。

  加载时机：
    * nvim-lspconfig 在读取缓冲区时加载（BufReadPre / BufNewFile），保证一打开文件就能挂上服务器；
    * 下面 keys 中声明的映射是「全局懒加载键」，即使还没打开文件也能按，按键时才加载插件。
  本文件启用的服务器：clangd（C/C++/CUDA）、lua_ls、basedpyright、ruff。
]]

-- 语言服务器挂载到缓冲区后（LspAttach）注册的缓冲区级映射。
-- 使用 buffer 局部绑定，既能覆盖默认键又只影响当前缓冲区，避免全局污染，
-- 也因此只有真正支持 LSP 的文件才会有这些按键（见文件末尾的 LspAttach 回调）。
local function lsp_mappings(event)
  local opts = { buffer = event.buf }
  -- gd：跳到定义（最常用的跳转）
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
  -- gD：跳到声明（声明与定义分离的语言，如 C/C++ 头文件）
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, vim.tbl_extend('force', opts, { desc = 'Go to declaration' }))
  -- gr：列出所有引用（配合 telescope 选择跳转）
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, vim.tbl_extend('force', opts, { desc = 'References' }))
  -- K：悬浮显示类型与文档（Vim 原生 K 是查 man，这里改为 LSP 语义）
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, vim.tbl_extend('force', opts, { desc = 'Hover documentation' }))
  -- <leader>ca：代码操作，包括快速修复、自动导入、提取变量等
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, vim.tbl_extend('force', opts, { desc = 'Code action' }))
  -- <leader>cr：跨文件重命名符号
  vim.keymap.set('n', '<leader>cr', vim.lsp.buf.rename, vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))
end

return {
  -- mason：工具安装界面。用 cmd 懒加载，只有执行 :Mason 时才会启动该插件。
  { 'williamboman/mason.nvim', cmd = 'Mason', opts = { ui = { border = 'rounded' } } },
  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      -- 启动时确保这些工具存在，缺什么装什么（幂等）：
      --   lua-language-server —— Lua 语言服务器
      --   stylua              —— Lua 格式化器（配合 plugins/format.lua）
      --   codelldb            —— C/C++/Rust 调试适配器（配合 plugins/debug.lua）
      --   basedpyright        —— Python 类型检查/补全
      --   ruff                —— Python 代码检查与格式化
      ensure_installed = { 'lua-language-server', 'stylua', 'codelldb', 'basedpyright', 'ruff' },
      -- 每次启动都检查一次，保证换机器/重装后能自动补齐。
      run_on_start = true,
    },
  },
  -- fidget：LSP 进度提示。等服务器真正挂载（LspAttach）时才加载，空窗口不浪费内存。
  { 'j-hui/fidget.nvim', event = 'LspAttach', opts = {} },
  {
    'neovim/nvim-lspconfig',
    -- 一打开文件就加载，确保文件类型对应的服务器能及时挂上。
    event = { 'BufReadPre', 'BufNewFile' },
    -- 依赖 blink.cmp：下面要用它提供 LSP 客户端能力（capabilities）。
    dependencies = { 'saghen/blink.cmp' },
    keys = {
      -- 全局懒加载键：还没打开任何文件也能直接按，顺带把插件加载起来。
      { '<M-d>', vim.lsp.buf.definition, desc = 'Go to definition' },
      {
        '<M-s>',
        -- 在 telescope 里预览定义位置而不直接跳走（jump_type = 'never'），
        -- 多个同名定义时可以逐个查看后再决定，避免来回跳转丢上下文。
        function() require('telescope.builtin').lsp_definitions({ jump_type = 'never' }) end,
        desc = 'Preview definitions',
      },
    },
    config = function()
      -- blink.cmp 提供的能力集合（补全、签名帮助等），统一交给各服务器。
      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local project = require('core.project')
      local clangd = require('core.clangd')

      -- clangd：C/C++/CUDA 服务器，启动参数由 core/clangd.lua 生成。
      vim.lsp.config('clangd', {
        cmd = clangd.command(project.current()),
        capabilities = capabilities,
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
        -- 在这些标记文件所在目录向上寻找项目根目录，决定 clangd 的工作区范围。
        root_markers = { 'compile_commands.json', 'CMakeLists.txt', '.git' },
        -- 启动前再解析一次项目上下文（此时 root_dir 已确定）：
        -- 这样 --compile-commands-dir 才能指向正确的编译数据库（ROS 工作空间与普通 CMake 工程不同）。
        before_init = function(_, config)
          local context = project.detect(config.root_dir or vim.uv.cwd())
          config.cmd = clangd.command(context)
        end,
      })
      -- lua_ls：编辑本配置时提供补全与诊断。
      vim.lsp.config('lua_ls', {
        capabilities = capabilities,
        -- globals 声明 vim 为全局变量，避免满屏 undefined-global 警告；
        -- checkThirdParty 关闭后不会再提示"是否配置第三方库"。
        settings = { Lua = { diagnostics = { globals = { 'vim' } }, workspace = { checkThirdParty = false } } },
      })
      -- basedpyright：Python 类型检查与补全。
      vim.lsp.config('basedpyright', {
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoImportCompletions = true,       -- 补全时自动提示可导入的符号
              diagnosticMode = 'openFilesOnly',   -- 只诊断已打开的文件，大项目下更快
              typeCheckingMode = 'standard',      -- 标准级别检查，比 strict 少噪音
            },
          },
        },
      })
      -- ruff：Python lint / 格式化，与 basedpyright 分工（一个管风格与错误，一个管类型）。
      vim.lsp.config('ruff', {
        capabilities = capabilities,
        -- 关闭 ruff 的 hover：类型信息交给 basedpyright，避免同一个 K 弹出两份重复内容。
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      })
      -- 启用上面配置好的服务器；lspconfig 会在匹配的文件类型上自动挂载。
      vim.lsp.enable({ 'clangd', 'lua_ls', 'basedpyright', 'ruff' })

      -- 服务器挂载后注册缓冲区级映射（gd / gD / gr / K / <leader>ca / <leader>cr）。
      vim.api.nvim_create_autocmd('LspAttach', { callback = lsp_mappings })
    end,
  },
}
