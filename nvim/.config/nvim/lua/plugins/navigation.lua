--[[
lua/plugins/navigation.lua — 检索与侧栏 spec

包含：Telescope（模糊查找文件/内容/缓冲区/帮助/命令）、fzf 原生排序扩展、
neo-tree（文件树侧栏）、aerial（符号大纲），以及它们共用的 plenary.nvim。

加载时机：全部键位触发——Telescope 与 neo-tree 只声明 cmd，快捷键由 lazy.nvim
预注册成“先加载、再执行”，所以首屏不加载任何检索插件；aerial 同理，
只有打开大纲时才启动。

在整体配置中的地位：所有“找东西”的入口集中在此；检索范围经 core.project 解析，
保证在多包 ROS 工作空间里落到当前功能包，而不是整个工作空间。
]]

-- 工厂函数：生成一个把检索范围锁定在“当前项目根”的 Telescope 调用闭包。
-- name 是 telescope.builtin 里的 picker 名，extra 用来覆盖默认参数。
local function project_picker(name, extra)
  -- 返回可直接作为键位 rhs 的函数：Telescope 在按下键那一刻才执行它。
  return function()
    -- 默认 cwd 取 core.project 识别出的项目根；extra 里的同名键优先级更高（force）。
    local opts = vim.tbl_extend('force', { cwd = require('core.project').current().root }, extra or {})
    -- 调用对应 picker：find_files / live_grep / oldfiles。
    require('telescope.builtin')[name](opts)
  end
end

-- 以下插件共同提供“找文件、找内容、看结构”的能力。
return {
  -- Lua 工具库：Telescope、neo-tree、todo-comments 共用，被依赖时才加载。
  { 'nvim-lua/plenary.nvim', lazy = true },
  -- fzf 排序扩展：用 C 实现替换 Lua 排序器，大仓库检索明显更快。
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',  -- 安装或更新后执行 make 编译出共享库；未编译则该扩展不可用
    -- 只在系统里存在 make 时才安装本插件，缺少构建工具的环境自动跳过
    cond = function() return vim.fn.executable('make') == 1 end,
  },
  -- 模糊查找器：统一入口检索文件、内容、缓冲区、帮助与命令。
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',  -- 懒加载触发点：首次执行 :Telescope 或按下下面任一快捷键时才加载
    -- plenary 提供底层工具函数，fzf-native 提供高速排序
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-fzf-native.nvim' },
    keys = {
      -- 空格 f f（普通模式）：按文件名查找项目文件；hidden 让点号开头的隐藏文件也进入候选
      { '<leader>ff', project_picker('find_files', { hidden = true }), desc = 'Find project files' },
      -- 空格 f g（普通模式）：项目内全文搜索（live_grep，依赖 ripgrep 可执行文件）
      { '<leader>fg', project_picker('live_grep'), desc = 'Grep project' },
      -- 空格 f r（普通模式）：最近打开过的文件；only_cwd 只保留项目根之下的条目
      { '<leader>fr', project_picker('oldfiles', { only_cwd = true }), desc = 'Recent project files' },
      -- 空格 f b（普通模式）：查找全部已列出的缓冲区；sort_mru 按最近使用排序，当前缓冲区也保留
      { '<leader>fb', '<Cmd>Telescope buffers sort_mru=true<CR>', desc = 'Find buffers' },
      -- 空格 f h（普通模式）：检索帮助标签，用来按关键词找 :help 主题
      { '<leader>fh', '<Cmd>Telescope help_tags<CR>', desc = 'Help tags' },
      -- 空格 f c（普通模式）：列出所有可用命令（含用户自定义命令）
      { '<leader>fc', '<Cmd>Telescope commands<CR>', desc = 'Commands' },
      -- 空格 b b（普通模式）：与 f b 同功能的另一组映射，贴合“切换缓冲区”的习惯
      { '<leader>bb', '<Cmd>Telescope buffers sort_mru=true<CR>', desc = 'Switch buffer' },
    },
    opts = {
      defaults = {
        -- 结果窗口带边框，与其它浮窗风格统一。
        border = true,
        -- 横向布局：结果列表在左、预览在右，宽屏下信息量最大。
        layout_strategy = 'horizontal',
        -- 结果自上而下排列。
        sorting_strategy = 'ascending',
        -- 输入框放在顶部（配合 ascending 才是“上输入、下结果”）；
        -- 宽度 0.9、高度 0.85 保留背景上下文，同时给结果留足空间。
        layout_config = { prompt_position = 'top', width = 0.9, height = 0.85 },
        -- Telescope 的 prompt 会安装局部映射，因此需要在这里显式接入全局 Alt 方向键体系：
        -- I/K 选择上一项/下一项，J/L 向上/向下滚动右侧只读预览。
        mappings = {
          i = {
            ['<M-i>'] = function(prompt_bufnr)
              require('telescope.actions').move_selection_previous(prompt_bufnr)
            end,
            ['<M-k>'] = function(prompt_bufnr)
              require('telescope.actions').move_selection_next(prompt_bufnr)
            end,
            ['<M-j>'] = function(prompt_bufnr)
              require('telescope.actions').preview_scrolling_up(prompt_bufnr)
            end,
            ['<M-l>'] = function(prompt_bufnr)
              require('telescope.actions').preview_scrolling_down(prompt_bufnr)
            end,
          },
        },
      },
      -- 启用 fzf 扩展：开启模糊匹配，并让普通排序与文件排序都走 fzf 实现。
      extensions = { fzf = { fuzzy = true, override_generic_sorter = true, override_file_sorter = true } },
    },
    config = function(_, opts)
      -- 取出 telescope 主模块（extensions 里的配置在加载扩展时才读取）。
      local telescope = require('telescope')
      -- 注册上面的 defaults 与 extensions 配置。
      telescope.setup(opts)
      -- 用 pcall 包裹：make 缺失导致扩展未编译时静默跳过，不影响 Telescope 本身。
      pcall(telescope.load_extension, 'fzf')
    end,
  },
  -- 文件树侧栏：以树形浏览项目结构，并提供文件操作类命令。
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',  -- 固定 v3 分支：v3 之后配置结构有破坏性变化，锁分支避免配置失效
    cmd = 'Neotree',  -- 懒加载触发点：首次执行 :Neotree（或按下面的快捷键）时加载
    -- plenary 工具函数、nui 浮窗组件、devicons 文件图标
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'nvim-tree/nvim-web-devicons' },
    -- 空格 e（普通模式）：切换左侧文件树；reveal 让树定位并展开到当前文件
    keys = { { '<leader>e', '<Cmd>Neotree toggle reveal left<CR>', desc = 'File explorer' } },
    opts = {
      -- 关闭最后一个普通窗口时一并关闭文件树，避免留下只剩侧栏的空界面。
      close_if_last_window = true,
      -- 以浮窗形式打开时用圆角边框，与其它浮窗保持一致。
      popup_border_style = 'rounded',
      -- follow_current_file：文件树跟随当前缓冲区，自动展开并定位；
      -- use_libuv_file_watcher：用 libuv 监听磁盘变化，外部改动即时刷新。
      filesystem = { follow_current_file = { enabled = true }, use_libuv_file_watcher = true },
      -- 侧栏固定 34 列：够显示两层文件名与图标，又不侵占编辑区。
      window = { width = 34 },
    },
  },
  -- 符号大纲：按 LSP/treesitter 列出当前文件的函数、类、变量等符号。
  {
    'stevearc/aerial.nvim',
    -- 懒加载触发点：只有执行这两个命令（或按下面的快捷键）时才加载
    cmd = { 'AerialToggle', 'AerialNavToggle' },
    -- 空格 c s（普通模式）：在右侧切换大纲；! 表示打开后把光标移入大纲，便于直接跳转
    keys = { { '<leader>cs', '<Cmd>AerialToggle! right<CR>', desc = 'Symbol outline' } },
    -- 后端按顺序尝试：LSP 最准（含未保存内容）-> treesitter（无 LSP 时）-> markdown/man 文档解析；
    -- min_width 保证深层符号名不被截断。
    opts = { backends = { 'lsp', 'treesitter', 'markdown', 'man' }, layout = { min_width = 28 } },
  },
}
