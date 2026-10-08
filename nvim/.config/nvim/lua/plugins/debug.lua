--[[
lua/plugins/debug.lua — C / C++（含 ROS 2 包）调试支持

用途：组合 nvim-dap（调试协议客户端）、nvim-dap-ui（变量/调用栈/断点面板）、
nvim-dap-virtual-text（行内显示变量值）、mason-nvim-dap（适配器安装）四个插件，
并把 launch / attach 配置的生成逻辑集中委托给 core.debug，使调试参数随当前工程自动变化。
加载时机：nvim-dap 通过 keys 懒加载 —— 按下 <leader>d* 或 F5/F10/F11/F12 时才载入；
nvim-dap-ui 与 nvim-dap-virtual-text 依赖 nvim-dap，会在其加载时一并带入；
mason-nvim-dap 走 cmd 懒加载（:DapInstall / :DapUninstall）；nvim-nio 是被依赖的异步库，自己不主动加载。
在配置中的地位：调试能力只覆盖本配置关心的 C/C++ 场景（gdb 为主、codelldb 可选），
整体是 CMake / ROS 两条构建链的下游 —— 构建与编译数据库由那些模块负责，这里只负责启动调试会话。
]]

-- 取当前缓冲区的工程上下文（kind / root / package_name 等），由 core.project 向上探测得到。
-- 每次调用都重新探测，因此在不同工程的文件间切换时，调试配置会跟着变。
local function context()
  return require('core.project').current()
end

-- 交互式询问要调试的可执行文件，默认前缀是当前工程根目录（方便用 Tab 逐级补全），
-- 这里只返回字符串；真正的询问时机被推迟到用户按下 <leader>dl 的那一刻。
local function choose_program()
  return vim.fn.input('Executable: ', require('core.project').current().root .. '/', 'file')
end

return {
  -- nvim-dap-ui 的底层异步 IO 依赖；lazy = true 表示它自己不是入口，
  -- 只在 dap-ui 被加载时作为依赖带上，避免无谓的启动开销。
  { 'nvim-neotest/nvim-nio', lazy = true },
  {
    'mfussenegger/nvim-dap',
    keys = {
      -- 中断/继续：没有会话时启动 launch 配置，停在断点后则是继续运行（<F5> 同义，照顾 IDE 习惯）
      { '<leader>dc', function() require('dap').continue() end, desc = 'Debug continue' },
      -- 在当前行切换断点，调试中最常用的操作
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
      -- attach 到已在运行的进程：pick_process() 列出系统进程让用户选 pid，
      -- 再交给 core.debug.attach_configuration 组装成 attach 配置（ROS 工程会自动带上环境变量）
      { '<leader>da', function()
        local dap = require('dap')
        dap.run(require('core.debug').attach_configuration(context(), require('dap.utils').pick_process()))
      end, desc = 'Attach process' },
      -- 启动调试：choose_program()（注意不带括号传入，此处是函数引用，dap 在真正启动前才求值）
      -- 让用户挑可执行文件，core.debug.launch_configuration 负责补齐 cwd、适配器与环境
      { '<leader>dl', function() require('dap').run(require('core.debug').launch_configuration(context(), choose_program())) end, desc = 'Launch executable' },
      -- 收起调试面板，回到纯编辑视图；面板在断点命中时会自动打开，所以需要这个手动关闭入口
      { '<leader>du', function() require('dapui').close() end, desc = 'Close debug UI' },
      -- 下面四个功能键对齐常见 IDE：继续、单步跳过、单步进入、单步跳出
      { '<F5>', function() require('dap').continue() end, desc = 'Debug continue' },
      { '<F10>', function() require('dap').step_over() end, desc = 'Debug step over' },
      { '<F11>', function() require('dap').step_into() end, desc = 'Debug step into' },
      { '<F12>', function() require('dap').step_out() end, desc = 'Debug step out' },
    },
    config = function()
      local dap = require('dap')
      local debug = require('core.debug')
      -- 按可用性注册适配器：优先使用系统 gdb（ROS 场景的首选），存在 codelldb 时作为可选项一并注册；
      -- 两者都缺会弹出一次安装提示，不会中断启动。
      debug.register_adapters(dap)
      -- 挂上 dap.listeners.on_config：凡是 core.debug 生成的配置（带 _dynamic_project 标记）
      -- 在启动前都会被替换成当前工程的 cwd 与 ROS 环境变量，因此配置只需写一份、跟着工程走。
      debug.setup_dynamic_context(dap)
      -- cpp 的两条配置分别是「启动可执行文件」与「附加到进程」，都指定 gdb 作为适配器；
      -- 传给 core.debug 的是函数引用，实际参数在每次启动调试时才计算。
      dap.configurations.cpp = {
        debug.launch_configuration(context(), choose_program, 'gdb'),
        debug.attach_configuration(context(), function() return require('dap.utils').pick_process() end, 'gdb'),
      }
      -- C 与 C++ 复用同一份配置表：这里直接共享引用，C 文件即可使用同样的 launch/attach，
      -- 省去重复声明；副作用是日后若单独改写其中之一，两者会同时变化。
      dap.configurations.c = dap.configurations.cpp
    end,
  },
  {
    'rcarriga/nvim-dap-ui',
    -- 显式声明依赖：dap-ui 需要 nvim-dap 提供会话与事件，需要 nvim-nio 提供异步原语
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    -- 浮动面板用圆角边框，与 lazy.nvim 界面风格保持一致
    opts = { floating = { border = 'rounded' } },
    config = function(_, opts)
      local dapui = require('dapui')
      dapui.setup(opts)
      -- setup_ui 注册 event_initialized / event_stopped 两个监听：会话开始或命中断点时自动展开面板，
      -- 用户不必再手动调用 :DapUI open。
      require('core.debug').setup_ui(require('dap'), dapui)
    end,
  },
  {
    'theHamsta/nvim-dap-virtual-text',
    -- 只依赖 nvim-dap，通过 opts 由 lazy.nvim 自动 setup，无需 config
    dependencies = { 'mfussenegger/nvim-dap' },
    -- enabled 打开行内虚拟文本；clear_on_continue 使继续运行后立即清除旧值，避免显示过期的变量；
    -- virt_text_pos = 'eol' 把值放在行尾，不遮挡源码本身，阅读时干扰最小。
    opts = { enabled = true, clear_on_continue = true, virt_text_pos = 'eol' },
  },
  {
    'jay-babu/mason-nvim-dap.nvim',
    -- 仅在手动执行 :DapInstall / :DapUninstall 时才加载
    cmd = { 'DapInstall', 'DapUninstall' },
    dependencies = { 'williamboman/mason.nvim', 'mfussenegger/nvim-dap' },
    -- ensure_installed 声明期望的适配器（codelldb，LLDB 系，可作 gdb 之外的备选）；
    -- automatic_installation = false 表示启动时不静默安装、交给用户显式执行安装命令；
    -- handlers = {} 表示不做任何自动配置，适配器的注册完全由 core.debug.register_adapters 掌握。
    opts = { ensure_installed = { 'codelldb' }, automatic_installation = false, handlers = {} },
  },
}
