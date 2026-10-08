--[[
lua/plugins/guides.lua — 缩进与作用域可视化 spec

包含两个插件：hlchunk.nvim（语法块框线 + 缩进参考线）与
rainbow-delimiters.nvim（嵌套括号按层级上色）。目标是在不依赖 LSP 的前提下，
用 treesitter 与缩进信息表达代码层级。

加载时机：两者都按 Buffer 事件惰性加载（BufReadPre/BufNewFile 与
BufReadPost/BufNewFile），只有打开或新建文件时才启动，不拖慢首屏。

在整体配置中的地位：与 ui.lua 共用同一套强调色（mauve / pink / blue / teal），
属于纯显示层插件，不修改缓冲区内容。
]]

-- 排除清单：下列窗口不是普通代码缓冲区——浮层、面板、终端、帮助页等，
-- 在其中绘制分块框线或缩进线只会变成视觉噪声。
local excluded = {
  ['neo-tree'] = true,  -- 文件树；名字含连字符，只能写成方括号键
  TelescopePrompt = true,  -- 选择器输入窗
  toggleterm = true,  -- 终端（toggleterm）
  terminal = true,  -- 终端（内置 :terminal 的 filetype）
  help = true,  -- 帮助页
  dashboard = true,  -- 启动页
  aerial = true,  -- 符号大纲侧栏
  lazy = true,  -- 插件管理器界面
  mason = true,  -- 安装器界面
  notify = true,  -- 通知浮窗
  noice = true,  -- 消息浮窗
}

-- 下面两个插件共同负责“看清代码结构”，都用 Buffer 事件惰性加载。
return {
  -- 语法块框线：用框线标出光标所在的语法块，并绘制缩进参考线。
  {
    'shellRaining/hlchunk.nvim',
    -- 打开已有文件或新建文件时加载，覆盖绝大多数编辑入口，不必占用启动时间
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      -- chunk：语法块框线部分。
      chunk = {
        -- 启用块高亮。
        enable = true,
        -- 用 treesitter 节点确定块边界，比纯缩进推断准确。
        use_treesitter = true,
        -- 重绘无延迟：光标一动就更新框线。
        delay = 0,
        -- 无动画时长，直接绘制终态，避免动画带来的闪烁。
        duration = 0,
        -- 用直线连接而非圆角或箭头，减少字符干扰。
        straight = true,
        -- 超过 1MB 的文件不绘制，避免大文件卡顿。
        max_file_size = 1024 * 1024,
        -- 框线使用的字符集合（需要终端字体支持这些制表符）。
        chars = {
          horizontal_line = '─',
          vertical_line = '│',
          left_top = '┌',
          left_bottom = '└',
          right_arrow = '─',
        },
        -- 颜色按嵌套层级循环取用。
        style = {
          -- 第 1 层：mauve，与主题主强调色一致。
          { fg = '#b4a0ff' },
          -- 第 2 层：catppuccin pink；两层交替足以区分内外层。
          { fg = '#f38ba8' },
        },
        -- 复用上面的排除表，避免在浮层与终端里画框线。
        exclude_filetypes = excluded,
      },
      -- indent：缩进参考线部分。
      indent = {
        -- 启用缩进线。
        enable = true,
        -- 缩进线不用 treesitter：按 shiftwidth/缩进计算，更快也更贴近实际缩进。
        use_treesitter = false,
        -- 每层一根竖线（数组形式表示按层循环取用字符）。
        chars = { '│' },
        -- 用低对比度的 surface0 灰：作为背景参考而不抢视线。
        style = { '#313244' },
        -- 光标停留 80ms 后再重绘，减少频繁移动时的开销。
        delay = 80,
        -- 同样复用排除表。
        exclude_filetypes = excluded,
      },
    },
  },
  -- 彩虹括号：给嵌套的圆括号/方括号/花括号按层级上色，快速判断配对层级。
  {
    'HiPhish/rainbow-delimiters.nvim',
    -- 需要缓冲区内容与 treesitter 解析器就绪，所以用 BufReadPost 而非 BufReadPre
    event = { 'BufReadPost', 'BufNewFile' },
    main = 'rainbow-delimiters.setup',  -- 插件主模块名与仓库名不同，显式声明以便正确加载并注入 opts
    opts = {
      -- 按嵌套层级循环使用的高亮组名；catppuccin 不提供这些组，由下面的 config 注册。
      highlight = {
        -- 顺序即层级顺序：蓝 -> 紫 -> 青 -> 绿，用尽后从头循环。
        'RainbowDelimiterBlue',
        'RainbowDelimiterViolet',
        'RainbowDelimiterCyan',
        'RainbowDelimiterGreen',
      },
    },
    -- 自定义 config：先注册高亮组再 setup，保证首帧就有颜色。
    config = function(_, opts)
      -- 把四个高亮组映射到本配置的调色板，与主题保持一致。
      local colors = {
        -- 与主题 blue 同值。
        RainbowDelimiterBlue = '#89b4fa',
        -- mauve，主题主强调色。
        RainbowDelimiterViolet = '#b4a0ff',
        -- sapphire，偏青的次级蓝。
        RainbowDelimiterCyan = '#74c7ec',
        -- teal，与新增标记、光标拖尾共用同一色。
        RainbowDelimiterGreen = '#5de4c7',
      }
      -- 遍历映射表，逐个注册高亮组。
      for group, color in pairs(colors) do
        -- 只设前景色并写入全局命名空间（0 表示全局），背景交给主题，避免整行变色。
        vim.api.nvim_set_hl(0, group, { fg = color })
      end
      -- 应用上面的选项，完成扩展初始化。
      require('rainbow-delimiters.setup').setup(opts)
    end,
  },
}
