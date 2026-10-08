--[[
lua/core/autocmds.lua — 核心自动命令

用途：集中定义与插件无关的自动命令（autocmd），即“某事件发生时自动执行的动作”。
加载时机：由 init.lua 调用 require('core.autocmds').setup()，排在 options 之后、keymaps 之前。
地位：属于 core 基础层；这里只放跨项目通用的行为，语言或插件专属的规则交给对应插件配置。
]]

local M = {}

-- 注册自动命令；无参数、无返回值，副作用是在命名分组里创建若干 autocmd。
function M.setup()
  -- 创建（并清空重建）命名分组：clear = true 保证重载配置时旧规则被移除，不会重复叠加。
  local group = vim.api.nvim_create_augroup('nvim-workspace-core', { clear = true })

  -- C 系语言统一采用 Google 风格的 4 空格缩进，其余语言沿用 options.lua 的 2 空格。
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    -- 仅在识别出这些文件类型后触发；objc/objcpp/cuda 遵循同一套缩进规范。
    pattern = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    -- :autocmd 列表里显示的说明文字，保留英文原文以便检索。
    desc = 'Use Google-style four-space indentation for C and C++',
    -- 回调只改缓冲区局部选项（bo），不会污染其他文件类型的默认值。
    callback = function()
      vim.bo.expandtab = true   -- C 系也用空格缩进，不写入真实制表符
      vim.bo.shiftwidth = 4     -- 每级缩进 4 个空格，符合 Google 风格
      vim.bo.tabstop = 4        -- 文件里已有的制表符按 4 列显示
      vim.bo.softtabstop = 4    -- 插入模式下按 Tab 相当于 4 个空格
    end,
  })

  -- 复制（yank）之后短暂高亮被复制的区域，给操作一个视觉确认。
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = group,
    desc = 'Highlight text after yanking',
    -- 180ms 的短闪烁：足够看见，又不会干扰连续编辑。
    callback = function() vim.highlight.on_yank({ timeout = 180 }) end,
  })
end

return M
