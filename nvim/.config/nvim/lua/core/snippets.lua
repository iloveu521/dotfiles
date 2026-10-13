--[[
lua/core/snippets.lua — 编辑反馈与诊断显示

保留参考配置中与代码片段无关但实用的全局显示行为：让 treesitter 的语法色优先于
LSP 语义 token，并统一诊断圆点、浮窗来源和悬停行为。复制高亮已经由
core/autocmds.lua 负责，因此这里不重复注册 TextYankPost。
]]

local M = {}

function M.setup()
  -- treesitter 默认优先级为 100；语义 token 稍低，避免 LSP 覆盖更细致的语法高亮。
  vim.hl.priorities.semantic_tokens = 95
  -- 光标停留半秒后才显示诊断详情，移动时只保留圆点提示。
  vim.o.updatetime = 500

  vim.diagnostic.config({
    -- 行内不显示消息；左侧 sign column 只保留按严重级别着色的圆点。
    virtual_text = false,
    -- 不关闭 underline：沿用 Neovim/主题当前的诊断下划线设置。
    update_in_insert = false,
    float = { source = true },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = '● ',
        [vim.diagnostic.severity.WARN] = '● ',
        [vim.diagnostic.severity.INFO] = '● ',
        [vim.diagnostic.severity.HINT] = '● ',
      },
    },
  })

  local group = vim.api.nvim_create_augroup('nvim-workspace-diagnostics', { clear = true })
  vim.api.nvim_create_autocmd('CursorHold', {
    group = group,
    desc = 'Show diagnostics after the cursor rests on a line',
    callback = function()
      vim.diagnostic.open_float(nil, { focus = false, scope = 'cursor' })
    end,
  })
end

return M
