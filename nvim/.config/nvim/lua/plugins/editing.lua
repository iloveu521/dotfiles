--[[
lua/plugins/editing.lua — 编辑增强 spec

包含：gitsigns（缓冲区内的 Git 改动标记与 hunk 操作）、nvim-autopairs（自动配对
括号引号）、todo-comments（TODO/FIXME 等注释的高亮与检索）、persistence（按项目
保存与恢复会话）。

加载时机：全部惰性——gitsigns 与 todo-comments 在打开文件时加载，autopairs 在首次
进入插入模式时加载，persistence 在读取第一个文件之前挂载并等快捷键触发；
启动阶段不加载任何条目。

在整体配置中的地位：只改编辑体验，不涉及语言服务器与格式化；快捷键统一挂在
leader 的 g / f / q / b 前缀下。
]]

return {
  -- Git 集成：在符号列标出新增/修改/删除，并提供 hunk 级操作。
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },  -- 打开文件之前就挂载，保证符号列第一次绘制就带 Git 标记
    keys = {
      -- 空格 g p（普通模式）：在浮动窗口里预览光标所在 hunk 的改动
      { '<leader>gp', '<Cmd>Gitsigns preview_hunk<CR>', desc = 'Preview Git hunk' },
      -- 空格 g s（普通/可视模式）：暂存当前 hunk，可视模式下暂存选中范围
      { '<leader>gs', '<Cmd>Gitsigns stage_hunk<CR>', desc = 'Stage Git hunk', mode = { 'n', 'v' } },
      -- 空格 g r（普通/可视模式）：撤销当前 hunk 的改动
      { '<leader>gr', '<Cmd>Gitsigns reset_hunk<CR>', desc = 'Reset Git hunk', mode = { 'n', 'v' } },
      -- 空格 g b（普通模式）：显示光标所在行的 blame 信息
      { '<leader>gb', '<Cmd>Gitsigns blame_line<CR>', desc = 'Blame line' },
    },
    -- 符号列样式：add/change 都用左半竖块，细窄不挤占行号空间，靠颜色区分；
    -- delete 用一个行尾小标记表示此处有被删除的行。
    opts = { signs = { add = { text = '▎' }, change = { text = '▎' }, delete = { text = '' } } },
  },
  -- 自动配对：输入左括号或引号时自动补右半边，回车时按语法智能换行缩进。
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',  -- 只有进入插入模式才可能用到，首次 InsertEnter 时加载
    -- check_ts 用 treesitter 判断是否位于字符串或注释内，避免误补括号；
    -- fast_wrap 允许用默认快捷键把选中内容快速包上括号，空表即使用默认值。
    opts = { check_ts = true, fast_wrap = {} },
  },
  -- 注释标记：高亮 TODO/FIXME/HACK/NOTE 等关键字，并支持跨项目检索。
  {
    'folke/todo-comments.nvim',
    -- 需要缓冲区内容才能识别关键字，所以用 BufReadPost 而非 BufReadPre
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },  -- 检索与底层工具依赖 plenary
    -- 空格 f t（普通模式）：用 Telescope 列出项目中所有 TODO 类注释，便于集中清理
    keys = { { '<leader>ft', '<Cmd>TodoTelescope<CR>', desc = 'Find TODO comments' } },
    opts = { signs = true },  -- 在符号列显示待办图标，滚动时也能看到它们的位置
  },
  -- 会话管理：按项目保存并恢复窗口与缓冲区布局。
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',  -- 读入第一个文件之前挂载，才能接管恢复会话时的缓冲区加载
    -- 会话文件写入 stdpath('state') 而不是配置目录，避免被 dotfiles 仓库跟踪
    opts = { dir = vim.fn.stdpath('state') .. '/sessions/' },
    keys = {
      -- 空格 q s（普通模式）：恢复当前项目的会话
      { '<leader>qs', function() require('persistence').load() end, desc = 'Restore session' },
      -- 空格 q l（普通模式）：恢复上一次会话（可跨项目，适合接着上次的进度继续）
      { '<leader>ql', function() require('persistence').load({ last = true }) end, desc = 'Restore last session' },
      -- 空格 q d（普通模式）：停止本次会话的自动保存，退出时不再写会话文件
      { '<leader>qd', function() require('persistence').stop() end, desc = 'Do not save session' },
      -- 空格 b d（普通模式）：删除（关闭）当前缓冲区，与会话/缓冲区管理放在一起
      { '<leader>bd', '<Cmd>bdelete<CR>', desc = 'Delete buffer' },
    },
  },
}
