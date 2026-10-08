--[[
  plugins/completion.lua — 补全菜单与代码片段（blink.cmp）

  组成：
    * friendly-snippets —— 社区维护的代码片段库，作为 blink.cmp 的 snippets 补全来源；
    * blink.cmp        —— 补全引擎，模糊匹配由 Rust 实现，输入延迟低。

  加载时机：进入插入模式时才加载（event = 'InsertEnter'），不拖慢启动。
  按键：预设 'enter'（回车接受补全），并额外把 Alt+I / Alt+K 接到「选择上一项 / 下一项」，
        与 core/keymaps.lua 的 Alt 方向键体系统一。
]]

return {
  -- 片段库是纯数据，用 lazy = true 按需加载（blink.cmp 真正取片段时才 require 它）。
  { 'rafamadriz/friendly-snippets', lazy = true },
  {
    'saghen/blink.cmp',
    -- 跟随 1.x 小版本更新：既能拿到修复，又不会被大版本 API 变动破坏配置。
    version = '1.*',
    -- 补全只在编辑时用得上，进入插入模式再加载。
    event = 'InsertEnter',
    dependencies = { 'rafamadriz/friendly-snippets' },
    -- 下载/编译模糊匹配用的 Rust 动态库，首次安装与版本更新时执行。
    build = function() require('blink.cmp').build():pwait() end,
    opts = {
      keymap = {
        -- 'enter' 预设提供：回车接受、C-space 显示菜单、C-e 取消并隐藏、
        -- Tab/S-Tab 跳转片段占位符、C-n/C-p 与 Up/Down 选择、C-b/C-f 滚动文档、C-k 显示签名。
        preset = 'enter',
        -- 复用 Alt 方向键：菜单打开时选择上一项/下一项；
        -- fallback_to_mappings 保证菜单未打开时回退到 core/keymaps.lua 的光标移动映射。
        ['<M-i>'] = { 'select_prev', 'fallback_to_mappings' },
        ['<M-k>'] = { 'select_next', 'fallback_to_mappings' },
      },
      -- 图标按等宽字形渲染，避免 Nerd Font 图标把补全列表撑得宽度不一。
      appearance = { nerd_font_variant = 'mono' },
      completion = {
        -- 补全菜单使用圆角边框，与其它浮动窗口（noice、telescope）风格一致。
        menu = { border = 'rounded' },
        -- 文档窗口延迟 250ms 自动弹出：既能看到类型与说明，快速输入时又不会频繁闪烁。
        documentation = { auto_show = true, auto_show_delay_ms = 250, window = { border = 'rounded' } },
      },
      -- 输入函数实参时显示参数签名提示（圆角窗口）。
      signature = { enabled = true, window = { border = 'rounded' } },
      -- 补全来源与优先级：LSP 语义补全优先，其次路径、片段、当前缓冲区中的单词。
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      -- 模糊匹配使用 Rust 实现（比内置 Lua 回退实现快），需上面的 build 步骤编译。
      fuzzy = { implementation = 'rust' },
    },
    -- 允许后续模块向 sources.default 追加来源，而不是整表覆盖已有来源。
    opts_extend = { 'sources.default' },
  },
}
