--[[
lua/core/snippets.lua — 编辑反馈与诊断显示

保留参考配置中与代码片段无关但实用的全局显示行为：让 treesitter 的语法色优先于
LSP 语义 token，并统一诊断虚拟文本、浮窗来源和符号。复制高亮已经由
core/autocmds.lua 负责，因此这里不重复注册 TextYankPost。
]]

local M = {}

-- 让诊断虚拟文本跟随透明主题；主题切换后需要重新应用，因为 colorscheme 会重建高亮组。
local function make_diagnostic_virtual_text_transparent()
  for _, group in ipairs({
    'DiagnosticVirtualText',
    'DiagnosticVirtualTextError',
    'DiagnosticVirtualTextWarn',
    'DiagnosticVirtualTextInfo',
    'DiagnosticVirtualTextHint',
    'DiagnosticVirtualTextOk',
  }) do
    vim.cmd(('highlight %s guibg=NONE ctermbg=NONE'):format(group))
  end
end

function M.setup()
  -- treesitter 默认优先级为 100；语义 token 稍低，避免 LSP 覆盖更细致的语法高亮。
  vim.hl.priorities.semantic_tokens = 95

  vim.diagnostic.config({
    virtual_text = {
      prefix = '●',
      -- 语言服务器提供 code 时渲染为 “[代码] 消息”，没有 code 时只显示消息。
      format = function(diagnostic)
        local code = diagnostic.code and string.format('[%s]', diagnostic.code) or ''
        return code == '' and diagnostic.message or string.format('%s %s', code, diagnostic.message)
      end,
    },
    -- 不关闭 underline：沿用 Neovim/主题当前的诊断下划线设置。
    update_in_insert = true,
    float = { source = true },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = ' ',
        [vim.diagnostic.severity.WARN] = ' ',
        [vim.diagnostic.severity.INFO] = ' ',
        [vim.diagnostic.severity.HINT] = '󰌵 ',
      },
    },
  })

  local group = vim.api.nvim_create_augroup('nvim-workspace-diagnostics', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    desc = 'Keep diagnostic virtual text backgrounds transparent',
    callback = make_diagnostic_virtual_text_transparent,
  })
  make_diagnostic_virtual_text_transparent()
end

return M
