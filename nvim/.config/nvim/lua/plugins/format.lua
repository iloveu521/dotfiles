--[[
  plugins/format.lua — 代码格式化（conform.nvim）

  行为：
    * 保存文件时按文件类型自动格式化（可通过 <leader>uf 逐缓冲区关闭）；
    * 也支持手动格式化：<leader>cf 与 <M-f>。

  加载时机：BufWritePre（保存前）触发，或按下相关按键 / 执行 :ConformInfo 时加载。
  格式化器由 mason-tool-installer 保证存在（stylua、ruff 等），clang-format / cmake-format 由系统提供。
]]

return {
  {
    'stevearc/conform.nvim',
    -- 保存前才需要它；手动格式化用下面的 keys 懒加载。
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>cf',
        -- 立即异步格式化当前缓冲区；没有专用格式化器时回退到 LSP 格式化（lsp_format = 'fallback'）。
        function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
        mode = { 'n', 'v' },
        desc = 'Format code',
      },
      {
        '<M-f>',
        -- 与 <leader>cf 等价，但额外支持插入模式（写完立刻格式化再继续输入）。
        function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
        mode = { 'n', 'v', 'i' },
        desc = 'Format code',
      },
      {
        '<leader>uf',
        -- 切换当前缓冲区的「保存时格式化」开关，状态存放在 core/format.lua，
        -- 保存时由下面的 format_on_save 读取，切换后弹出提示告知当前状态。
        function()
          local enabled = require('core.format').toggle()
          vim.notify('Format on save ' .. (enabled and 'enabled' or 'disabled'))
        end,
        desc = 'Toggle format on save',
      },
    },
    opts = {
      -- 文件类型 → 格式化器映射（按顺序尝试，可用多个）。
      formatters_by_ft = {
        c = { 'clang_format' },
        cpp = { 'clang_format' },
        lua = { 'stylua' },
        cmake = { 'cmake_format' },
        python = { 'ruff_format' },
      },
      -- clang_format 的实际命令名是 clang-format（此处的 key 只是上面的引用名）。
      formatters = { clang_format = { command = 'clang-format' } },
      -- conform 支持函数形式：返回 nil 表示本次保存不格式化。
      format_on_save = function(bufnr)
        -- 被 <leader>uf 关闭过格式化的缓冲区直接跳过。
        if not require('core.format').is_enabled(bufnr) then return nil end
        -- 保存时最多等 1.5 秒以免阻塞写入；没有专用格式化器时回退到 LSP 格式化。
        return { timeout_ms = 1500, lsp_format = 'fallback' }
      end,
    },
  },
}
