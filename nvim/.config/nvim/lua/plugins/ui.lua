--[[
lua/plugins/ui.lua — 界面外观类插件 spec

范围：配色 catppuccin、光标拖尾 smear-cursor、图标 nvim-web-devicons、状态栏
lualine、标签栏 bufferline、按键提示 which-key，以及消息系统 nvim-notify + noice。

加载时机：本文件在启动时被 plugins/init.lua require，但自身只返回 spec 表。
catppuccin 用 lazy = false + priority = 1000 强制最先 setup 并立即生效；
smear-cursor / lualine / bufferline / which-key / noice 用 event = 'VeryLazy'，
首屏渲染完成后才加载；nvim-web-devicons、nui、nvim-notify 用 lazy = true，
等别的插件依赖它们时再加载。

在整体配置中的地位：纯显示层，不参与补全/LSP 等功能逻辑；这里的调色板
（base/mantle/mauve/teal 等）与 guides.lua 中硬编码的高亮色刻意保持一致。
]]

-- lualine 自定义组件：把 core.project 识别到的项目渲染成“图标 + 名称”。
local function project_label()
  -- 取当前缓冲区的项目上下文（kind / root / package_name，内部有缓存）。
  local context = require('core.project').current()
  -- 图标与 core.project 的 kind 一一对应：standalone 单文件、cpp 普通 C++ 工程、
  -- cmake CMake 工程、ros_package ROS 功能包、ros_workspace ROS 工作空间。
  local icons = {
    standalone = '󰈙',
    cpp = '',
    cmake = '',
    ros_package = '󰏗',
    ros_workspace = '󰒍',
  }
  -- 显示名优先取 ROS 包名，没有包名时退回项目根目录名。
  local name = context.package_name or vim.fs.basename(context.root)
  -- 未知 kind 用通用图标兜底；输出格式为“图标 + 空格 + 名称”。
  return string.format('%s %s', icons[context.kind] or '󰘬', name)
end

-- 宽窗口显示完整状态信息；小于等于 100 列时隐藏次要项并缩短模式名。
local function statusline_is_wide()
  return vim.fn.winwidth(0) > 100
end

local statusline_mode = {
  'mode',
  fmt = function(mode)
    return string.format(' %s', statusline_is_wide() and mode or mode:sub(1, 1))
  end,
}

local statusline_diagnostics = {
  'diagnostics',
  sources = { 'nvim_diagnostic' },
  sections = { 'error', 'warn' },
  symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
  colored = false,
  update_in_insert = false,
  cond = statusline_is_wide,
}

local statusline_diff = {
  'diff',
  symbols = { added = ' ', modified = ' ', removed = ' ' },
  colored = false,
  cond = statusline_is_wide,
}

-- 以下是本模块的插件 spec 列表，交给 lazy.nvim 调度。
return {
  -- 配色主题：统一界面配色，并作为 lualine/bufferline 等插件的主题来源。
  {
    'catppuccin/nvim',
    name = 'catppuccin',  -- 仓库名与 Lua 模块名不同，显式声明插件名，require('catppuccin') 才可用
    priority = 1000,  -- 最高优先级：确保配色在其它插件读取主题之前就绪
    lazy = false,  -- 禁用懒加载：主题必须在首帧生效，否则会先闪一下默认配色
    -- 以下选项经 lazy.nvim 的 opts 机制传给 catppuccin.setup。
    opts = {
      -- 使用深色的 mocha 风味（本配置只维护这一套暗色）。
      flavour = 'mocha',
      -- 全局透明背景，让编辑器与终端底色融合。
      transparent_background = true,
      -- 浮动窗口保持不透明（保证可读），但不填充实心底色，避免完全遮挡下层内容。
      float = { transparent = false, solid = false },
      -- 覆盖官方调色板，让主题色与配置中硬编码的颜色值一致。
      color_overrides = {
        -- 只改 mocha 这一套；其余风味保持官方取值。
        mocha = {
          -- 主背景，比官方 mocha 更深，并与 noice/notify 的背景色保持同值。
          base = '#11111b',
          -- 侧栏与浮动窗口底色，比 base 再深一层。
          mantle = '#0d0d16',
          -- 最深一层背景，用于需要强对比的区域（如状态栏）。
          crust = '#080811',
          -- 主强调色：浮动窗口边框；与 guides.lua 的代码块框线首色相同。
          mauve = '#b4a0ff',
          -- 次要强调色，保留官方 mocha 取值。
          purple = '#c6a0f6',
          -- teal 与 green 取同一个青绿色：新增标记、诊断正常、调试停留行共用它。
          teal = '#5de4c7',
          green = '#5de4c7',
          -- 常规蓝色，作为信息类颜色，与其它模块的硬编码保持一致。
          blue = '#89b4fa',
          -- 偏青的天蓝，用于次级信息高亮。
          sapphire = '#74c7ec',
        },
      },
      -- 在调色板基础上微调若干高亮组，集中处理透明与强调色。
      custom_highlights = function(colors)
        return {
          -- 主窗口背景交给终端（NONE 表示不绘制背景）。
          Normal = { bg = 'NONE' },
          -- 非当前窗口同样透明，多分屏时不出现底色差异。
          NormalNC = { bg = 'NONE' },
          -- 符号列透明，Git/诊断标记直接浮在终端背景上。
          SignColumn = { bg = 'NONE' },
          -- 缓冲区末尾的 ~ 行不绘制背景，视觉上更干净。
          EndOfBuffer = { bg = 'NONE' },
          -- 分屏分隔线用 surface1：弱化存在感但仍可辨识。
          WinSeparator = { fg = colors.surface1, bg = 'NONE' },
          -- 浮动窗口边框用 mauve、底色用 mantle，让浮层与编辑区区分开。
          FloatBorder = { fg = colors.mauve, bg = colors.mantle },
          -- 浮动窗口背景统一为 mantle，保证浮层内容可读。
          NormalFloat = { bg = colors.mantle },
          -- 新增行标记用 teal，与下面 gitsigns 的左侧竖条配合。
          GitSignsAdd = { fg = colors.teal },
          -- 诊断正常（Ok）也用 teal，正向状态统一一种颜色。
          DiagnosticOk = { fg = colors.teal },
          -- 调试停留行加粗，执行时便于一眼定位。
          DapStopped = { fg = colors.teal, bold = true },
        }
      end,
    },
    -- 自定义 config：lazy.nvim 会把上面的 opts 原样传入。
    config = function(_, opts)
      -- 应用调色板与自定义高亮。
      require('catppuccin').setup(opts)
      -- 显式激活 mocha，用户无需再手动执行 :colorscheme。
      vim.cmd.colorscheme('catppuccin-mocha')
    end,
  },
  -- 光标平滑拖尾：光标大范围跳动时更容易被眼睛追上；纯视觉，禁用不影响功能。
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',  -- 首屏渲染完成后再加载，避免动画拖慢启动
    opts = {
      -- 拖尾颜色与主题的 teal 强调色一致。
      cursor_color = '#5de4c7',
      -- 背景透明导致采样失败时的回退底色，等于 mocha 的 base。
      transparent_bg_fallback_color = '#11111b',
      -- 正常模式的跟随刚度：越大越紧跟光标。
      stiffness = 0.8,
      -- 拖尾刚度略低，形成轻微的滞后拖影。
      trailing_stiffness = 0.6,
      -- 插入模式更柔和：输入时抖动更小。
      stiffness_insert_mode = 0.7,
      -- 插入模式拖尾刚度与跟随刚度接近，避免来回拉扯。
      trailing_stiffness_insert_mode = 0.7,
      -- 阻尼接近 1：运动平滑，不产生回弹振荡。
      damping = 0.95,
      -- 插入模式同样取高阻尼。
      damping_insert_mode = 0.95,
      -- 与光标距离小于 0.5 格就停止动画，省下无意义的绘制。
      distance_stop_animating = 0.5,
      -- 关闭粒子特效，画面保持简洁。
      particles_enabled = false,
    },
  },
  -- 文件与文件类型图标库：被 lualine、bufferline、neo-tree 依赖，按需加载。
  { 'nvim-tree/nvim-web-devicons', lazy = true },
  -- 状态栏：把模式、分支/差异/诊断、文件名、项目、编码与行列位置集中到一行。
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',  -- 界面就绪后接管状态栏，减少启动耗时
    dependencies = { 'nvim-tree/nvim-web-devicons' },  -- 文件名与文件类型需要 devicons 提供图标
    opts = {
      options = {
        -- 复用 catppuccin 官方主题，配色与整体保持一致。
        theme = 'catppuccin-mocha',
        -- 所有窗口共用底部一条状态栏，分屏时不再各自重复。
        globalstatus = true,
        -- 参考配置的斜切 Nerd Font 分隔符；比实心圆角占用更小。
        component_separators = { left = '', right = '' },
        section_separators = { left = '', right = '' },
        -- 文件树自身已有路径与状态信息，不再重复绘制底部状态栏。
        disabled_filetypes = { 'neo-tree' },
      },
      sections = {
        -- 模式在宽屏显示全名，窄屏只显示首字母。
        lualine_a = { statusline_mode },
        lualine_b = { 'branch' },
        -- lualine_c：文件名；path = 1 表示显示相对当前工作目录的路径层级。
        lualine_c = { { 'filename', path = 1 } },
        -- 项目、诊断、diff、编码和文件类型属于辅助信息，窄窗口自动收起。
        lualine_x = {
          { project_label, _project_component = true, cond = statusline_is_wide },
          statusline_diagnostics,
          statusline_diff,
          { 'encoding', cond = statusline_is_wide },
          { 'filetype', cond = statusline_is_wide },
        },
        -- lualine_y：光标在文件中的百分比位置。
        lualine_y = { 'progress' },
        -- lualine_z（最右）：行列号。
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { { 'location', padding = 0 } },
        lualine_y = {},
        lualine_z = {},
      },
    },
  },
  -- 顶部标签栏：把已打开的缓冲区显示成带图标的标签页，便于多文件切换。
  {
    'akinsho/bufferline.nvim',
    version = '*',  -- 跟随最新稳定版（官方推荐写法，避免用到未发布的改动）
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    -- diagnostics 取 'nvim_lsp'：诊断只由 LSP 提供，无需合并其它来源；
    -- 使用细分隔线和下划线标记当前项，避免斜角与关闭图标让顶栏显得拥挤。
    opts = {
      options = {
        diagnostics = 'nvim_lsp',
        separator_style = 'thin',
        indicator = { style = 'underline' },
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },
  -- 按键提示：按下 leader 键后延迟弹出可用快捷键列表，帮助记住自定义映射。
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',  -- 首次按键之前无需加载
    -- preset = 'modern' 使用新版紧凑布局与图标风格；
    -- win.border = 'rounded' 与 core/lazy.lua 里的浮窗边框设置保持一致。
    opts = { preset = 'modern', win = { border = 'rounded' } },
  },
  -- UI 组件库：提供浮窗、输入框等构件，被 noice 与 neo-tree 复用，按需加载。
  { 'MunifTanjim/nui.nvim', lazy = true },
  -- 通知后端：把 vim.notify 的消息渲染成浮窗，最终由 noice 接管统一风格。
  {
    'rcarriga/nvim-notify',
    lazy = true,  -- 不主动加载：等 noice 依赖它或出现首条通知时再加载
    -- background_colour 与主题 base 同值；
    -- render = 'compact' 用紧凑排版少占屏；
    -- stages = 'fade_in_slide_out' 淡入滑出，提示更柔和。
    opts = { background_colour = '#11111b', render = 'compact', stages = 'fade_in_slide_out' },
  },
  -- 消息与命令行界面：替代默认的 cmdline 与消息区，统一成居中浮窗。
  {
    'folke/noice.nvim',
    event = 'VeryLazy',  -- 首条消息或首次输入命令之前不加载
    -- 需要 nui 提供浮窗构件、notify 作为通知后端
    dependencies = { 'MunifTanjim/nui.nvim', 'rcarriga/nvim-notify' },
    opts = {
      -- command_palette：把 : 命令行变成顶部命令面板（带补全与历史）；
      -- long_message_to_split：超长消息自动放进分屏，避免遮挡编辑区；
      -- lsp_doc_border：给 LSP 悬浮文档加边框，与其它浮窗风格统一。
      presets = { command_palette = true, long_message_to_split = true, lsp_doc_border = true },
      -- hover（文档悬浮窗）与 popupmenu（补全菜单）都使用圆角边框。
      views = { hover = { border = { style = 'rounded' } }, popupmenu = { border = { style = 'rounded' } } },
    },
  },
}
