--[[
lua/plugins/terminal.lua — toggleterm 终端与编码助手会话的懒加载入口

用途：声明 toggleterm.nvim 插件本体，并集中定义「打开终端 / 切换终端 / 管理编码助手会话」的全局键位。
加载时机：本文件被 lua/plugins/init.lua 拼接进 lazy.nvim 的 spec 列表，启动时立即被解析，
但插件本体要等首次触发才加载 —— cmd 列出 :ToggleTerm / :TermExec，keys 里每个映射都带函数体，
lazy.nvim 会先把映射登记好，按下时才 require 插件。core.terminal / core.agents 是纯 Lua 模块，
不依赖 toggleterm 已加载，因此这些映射可以安全地做懒加载入口。
在配置中的地位：所有「与 shell 或交互式进程打交道」的能力都收拢到 toggleterm 之上；
具体终端实例的角色划分（general / build / ros-shell / agent）交给 core.terminal 与 core.agents，
本文件只负责插件本体、外观参数与全局键位。
注意：lua/plugins/ros.lua 声明了同名插件（akinsho/toggleterm.nvim），lazy.nvim 按插件名合并两条 spec，
那边的 init 会并入下面这一条，因此这里不必重复声明 ROS 相关内容。
]]

return {
  {
    'akinsho/toggleterm.nvim',
    -- 跟随最新 release tag，避免直接吃 master 上的破坏性改动
    version = '*',
    -- 命令式懒加载入口：用到这两个命令时才载入插件
    cmd = { 'ToggleTerm', 'TermExec' },
    keys = {
      -- <leader>tt / t2 / t3：按编号复用同一批常驻终端。core.terminal.general 以
      -- 'general:<index>' 作为角色名缓存 Terminal 实例，重复按下只是 toggle，
      -- 之前跑过的进程与滚动历史依然保留，适合「一个终端跑构建、一个跑日志」的用法。
      { '<leader>tt', function() require('core.terminal').general(1) end, desc = 'Terminal 1' },
      { '<leader>t2', function() require('core.terminal').general(2) end, desc = 'Terminal 2' },
      { '<leader>t3', function() require('core.terminal').general(3) end, desc = 'Terminal 3' },
      -- <C-\>：沿用 toggleterm 的经典键位习惯，但显式重绑到 1 号通用终端，
      -- 与 <leader>tt 指向同一实例，不会出现两个互不相干的「1 号终端」。
      { [[<C-\>]], function() require('core.terminal').general(1) end, desc = 'Toggle terminal' },
      -- 编码助手会话（codex / claude / gemini / opencode）也寄生在 toggleterm 上，由 core.agents 管理：
      -- 竖直大终端、按 agent 名缓存实例、当前缓冲区所在工程根目录作为工作目录。
      -- <leader>aa 打开选择器（未安装的 CLI 会显示为 unavailable 并给出安装提示）。
      { '<leader>aa', function() require('core.agents').select() end, desc = 'Select coding agent' },
      -- <leader>al 直接召回上一次用过的 agent（会话仍在就直接聚焦，已关闭则重开）。
      { '<leader>al', function() require('core.agents').last() end, desc = 'Reopen last agent' },
      -- <leader>ak 结束当前/最近一个 agent 会话，用于释放卡死的 CLI 或换用别的助手。
      { '<leader>ak', function() require('core.agents').kill() end, desc = 'Kill agent session' },
    },
    opts = {
      -- 垂直分割宽度：默认占一半编辑器宽度，形成均等分栏。
      size = function()
        return math.floor(vim.o.columns / 2)
      end,
      -- 关键取舍：不注册插件自带的 <C-\> 映射。上面的 keys 已经显式绑定了 <C-\>，
      -- 若让插件再占一次，会在懒加载完成后覆盖自定义回调；置 false 意味着
      -- 「打开终端的时机与方式完全由本配置决定」，而不是 toggleterm 的默认行为。
      open_mapping = false,
      -- 关闭终端背景着色，配色与编辑器一致，便于鼠标选中和复制文本
      shade_terminals = false,
      -- 手动拖动过分割大小后记住新尺寸，下次 toggle 不再跳回 14
      persist_size = true,
      -- 切走再切回时恢复离开前的模式，避免每次回到终端都被扔进 insert 模式
      persist_mode = true,
      -- 默认在右侧垂直均等分割；编码助手的布局由 core.agents 单独指定。
      direction = 'vertical',
    },
    config = function(_, opts)
      -- 这里手动 setup 而非交给 lazy.nvim 自动处理 opts，是为了紧接着补一条终端模式映射
      require('toggleterm').setup(opts)
      -- 终端模式（t 模式）下 <Esc> 会被原样送给 shell，无法退出终端模式；
      -- 插件默认的 <C-\><C-n> 太别扭，于是提供 <Esc><Esc> 这个可预期的逃生键，
      -- 退出后仍停留在该缓冲区上，可直接用普通模式的按键滚动、复制。
      vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { desc = 'Leave terminal mode' })
    end,
  },
}
