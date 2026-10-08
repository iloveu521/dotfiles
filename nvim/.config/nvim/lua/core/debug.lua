--[[
lua/core/debug.lua — C/C++ 调试支持：适配器探测/注册、ROS 环境变量注入与 dapui 打开时机。

职责与地位：
  * 属于 core 层，是 nvim-dap 相关配置的“纯逻辑 + 适配”部分：不写 keymap、不设图标，
    只负责回答两件事——用哪个调试器（gdb / codelldb），以及启动/附加时该带上什么环境。
  * gdb 与 ROS 结合的关键难点：调试器进程由 DAP 启动，默认拿不到我在 shell 里 source 的
    ROS 环境；因此本模块在配置里挂一个 env 函数，运行到启动那一刻再抓取真实环境。
加载时机：
  * M.register_adapters / M.setup_dynamic_context / M.setup_ui 需由 dap 配置显式调用，
    本文件自身没有 setup()，也不会 require dap 或 dapui。
]]

local M = {}

-- 归一化探测器结果：把“路径/0/1/布尔”统一成“路径或 nil”。
-- 参数 lookup：探测函数；name：可执行名。返回字符串路径或 nil（表示不可用）。
-- vim.fn.executable / exepath 的返回类型不一致，这里做一次兼容，
-- 使 register_adapters 里可以统一用 command = path。
local function resolve_lookup(lookup, name)
  local value = lookup(name)
  if type(value) == 'number' or type(value) == 'boolean' then
    if value == 1 or value == true then return name end
    return nil
  end
  if type(value) == 'string' and value ~= '' then return value end
end

-- 默认探测：先查 PATH（exepath），再为 codelldb 补一条 mason 安装位置。
-- 参数 name：可执行名。返回路径字符串，找不到返回 ''（空串与 falsy 语义一致）。
-- codelldb 由 :MasonInstall codelldb 装在 stdpath('data')/mason/bin 下，
-- 该目录通常不在 PATH 中，故单独兜底；用 stdpath 而非硬编码路径以保证可移植。
local function default_executable(name)
  local path = vim.fn.exepath(name)
  if path ~= '' then return path end
  if name == 'codelldb' then
    local mason_path = vim.fn.stdpath('data') .. '/mason/bin/codelldb'
    if vim.fn.executable(mason_path) == 1 then return mason_path end
  end
  return ''
end

-- 汇总两个适配器的可用状态。参数 executable_fn：可选探测函数（默认 default_executable）。
-- 返回 { gdb = {...}, codelldb = {...} }，每项含 available/path，以及用途标记：
--   gdb.primary_for_ros = true —— ROS 场景首选（能直接吃 env 表，且系统自带）；
--   codelldb.optional = true   —— 纯 C/C++ 或需要 LLDB 特性时的可选补充。
-- 该返回值同时被 register_adapters 复用，避免重复探测。
function M.adapter_status(executable_fn)
  executable_fn = executable_fn or default_executable
  local gdb = resolve_lookup(executable_fn, 'gdb')
  local codelldb = resolve_lookup(executable_fn, 'codelldb')
  return {
    gdb = { available = gdb ~= nil, path = gdb, primary_for_ros = true },
    codelldb = { available = codelldb ~= nil, path = codelldb, optional = true },
  }
end

-- 向 nvim-dap 注册可用的适配器。参数 dap：dap 模块；executable_fn：可选探测函数。
-- 返回值同 adapter_status。副作用：写入 dap.adapters，并在两者都缺失时 warn 一次。
-- gdb：以 --interpreter=dap 起子进程，属 'executable' 型；--quiet 抑制版权横幅。
-- codelldb：DAP server 型，用 ${port} 占位让 dap 自行分配端口并拉起进程。
-- 只有探测到的适配器才写进表，避免留一个必然失败的配置项。
function M.register_adapters(dap, executable_fn)
  local status = M.adapter_status(executable_fn)
  if status.gdb.available then
    dap.adapters.gdb = {
      type = 'executable',
      command = status.gdb.path,
      args = { '--interpreter=dap', '--quiet' },
    }
  end
  if status.codelldb.available then
    dap.adapters.codelldb = {
      type = 'server',
      port = '${port}',
      executable = { command = status.codelldb.path, args = { '--port', '${port}' } },
    }
  end
  if not status.gdb.available and not status.codelldb.available then
    vim.notify('No C/C++ debug adapter found. Install system GDB or run :MasonInstall codelldb.', vim.log.levels.WARN, {
      title = 'C/C++ debugging',
    })
  end
  return status
end

-- 取出该上下文应 source 的环境脚本。参数 context：项目上下文（可为 nil）。返回列表或 nil。
-- 仅 ROS 工程需要；core.ros 负责具体路径（发行版 setup.zsh + workspace overlay）。
-- 空列表统一转成 nil，使调用方只需判断真值即可决定要不要注入环境。
local function scripts_for(context)
  if not context or (context.kind ~= 'ros_workspace' and context.kind ~= 'ros_package') then return nil end
  local scripts = require('core.ros').environment_scripts(context)
  return #scripts > 0 and scripts or nil
end

-- 在登录 shell 中 source 环境脚本后抓取完整环境变量表。
-- 参数 scripts：脚本列表（nil 直接返回 nil）。返回 key -> value 的表，失败时 nil。
-- 做法：拼成 `source ... && env -0`，用 vim.system 同步执行（text = false 取原始字节）。
-- 用 `env -0` 而非 `env`：环境变量值可能含换行/空格，NUL 分隔才能无损切分；
-- 解析时按 '[^%z]+' 逐条取 NUL 段，再按第一个 '=' 拆 key/value（值内的 '=' 不受影响）。
-- 退出码非 0 说明 source 失败，此时 notify 报错并返回 nil，让 dap 用默认环境继续。
local function sourced_environment(scripts)
  if not scripts then return nil end
  local commands = {}
  for _, script in ipairs(scripts) do table.insert(commands, 'source ' .. vim.fn.shellescape(script)) end
  table.insert(commands, 'env -0')
  local result = vim.system({ vim.o.shell, '-lc', table.concat(commands, ' && ') }, { text = false }):wait()
  if result.code ~= 0 then
    vim.notify('Unable to load the scoped ROS debug environment.', vim.log.levels.ERROR, { title = 'Debug' })
    return nil
  end
  local environment = {}
  for entry in (result.stdout or ''):gmatch('[^%z]+') do
    local key, value = entry:match('^([^=]+)=(.*)$')
    if key then environment[key] = value end
  end
  return environment
end

-- 为该上下文挑选默认适配器。参数 context：项目上下文（可 nil）。返回适配器名字符串。
-- 优先级：ROS 工程且有 gdb 时用 gdb（结合 env 注入最稳）；否则有 codelldb 用 codelldb；
-- 都没有时仍返回 'gdb' 作为名字，保证配置结构完整（真正可用性由 register_adapters 决定）。
local function adapter_for(context)
  local status = M.adapter_status()
  if context and (context.kind == 'ros_workspace' or context.kind == 'ros_package') and status.gdb.available then return 'gdb' end
  if status.codelldb.available then return 'codelldb' end
  return 'gdb'
end

-- 构造“启动本地可执行文件”的 DAP 配置。
-- 参数 context：项目上下文；program：可执行文件路径；adapter：可选适配器名（默认自动挑选）。
-- 返回配置表。要点：
--   cwd 取 context.root，让相对路径与 ROS 参数文件按项目根解析；
--   stopOnEntry = false，直接跑到断点而不是每次停在入口；
--   _dynamic_project = true 是给 on_config 的标记：该配置允许在真正启动前按“当前项目”重写；
--   env 写成函数而非表 —— dap 在启动那一刻才调用它，从而拿到当时最新的环境。
function M.launch_configuration(context, program, adapter)
  local scripts = scripts_for(context)
  local configuration = {
    name = 'Launch current executable',
    type = adapter or adapter_for(context),
    request = 'launch',
    program = program,
    cwd = context.root,
    stopOnEntry = false,
    _dynamic_project = true,
  }
  if scripts then
    configuration._environment_scripts = scripts
    configuration.env = function() return sourced_environment(scripts) end
  end
  return configuration
end

-- 构造“附加到已运行进程”的 DAP 配置。参数 context、process_id、可选 adapter。返回配置表。
-- 与 launch 的差异：request = 'attach' 且用 pid 代替 program；
-- 附加 ROS 节点时同样需要注入环境，否则符号/插件搜索路径会缺 ROS 部分；
-- 同样标记 _dynamic_project，使 attach 也能跟随当前项目切换工作目录与环境。
function M.attach_configuration(context, process_id, adapter)
  local scripts = scripts_for(context)
  local configuration = {
    name = 'Attach to process',
    type = adapter or adapter_for(context),
    request = 'attach',
    pid = process_id,
    cwd = context.root,
    _dynamic_project = true,
  }
  if scripts then
    configuration._environment_scripts = scripts
    configuration.env = function() return sourced_environment(scripts) end
  end
  return configuration
end

-- 把一份既有配置“重新贴合”到给定上下文：换 cwd、重算环境注入。
-- 参数 configuration：原始配置；context：目标项目上下文。返回新表（不修改入参）。
-- 先 deepcopy 再改写，避免污染 dap 保存的原始配置；
-- 先清空 _environment_scripts / env，再按新上下文决定是否重建——
-- 从 ROS 工程切到普通工程时必须清掉旧环境，否则会带着上一个工作空间的变量去调试。
function M.apply_context(configuration, context)
  local result = vim.deepcopy(configuration)
  result.cwd = context.root
  result._environment_scripts = nil
  result.env = nil
  local scripts = scripts_for(context)
  if scripts then
    result._environment_scripts = scripts
    result.env = function() return sourced_environment(scripts) end
  end
  return result
end

-- 注册“动态上下文注入”监听：dap 每次真正启动前都会经过 on_config。
-- 参数 dap：dap 模块。无返回值。副作用：写入 dap.listeners.on_config.nvim_environment。
-- 只有带 _dynamic_project 标记的配置才重写（用户手写的其它配置原样返回，不被干预）；
-- 时机上是“临启动前”取 core.project.current()，因此切换分支/工作空间后无需重建配置。
function M.setup_dynamic_context(dap)
  dap.listeners.on_config.nvim_environment = function(configuration)
    if not configuration._dynamic_project then return configuration end
    return M.apply_context(configuration, require('core.project').current())
  end
end

-- 注册 dapui 的打开时机。参数 dap：dap 模块；dapui：dapui 模块。无返回值。
-- event_initialized（会话真正建立）后打开：此时才有栈帧/作用域数据可渲染；
-- event_stopped（命中断点/单步停下）后再开一次，覆盖被手动关掉面板的情况；
-- 不监听 terminated，交给 dapui 自身的自动关闭配置决定收尾行为。
function M.setup_ui(dap, dapui)
  dap.listeners.after.event_initialized.nvim_environment = function() dapui.open() end
  dap.listeners.after.event_stopped.nvim_environment = function() dapui.open() end
end

return M
