--[[
lua/core/ros.lua — ROS 2 项目支持：环境脚本、colcon 动作、编译库刷新与缓冲区快捷键。

职责与地位：
  * 本模块是 core 层中唯一了解 ROS 领域的部分，向上只暴露“纯函数式”的入口：
    环境脚本推导、colcon 命令拼接、构建/测试/运行/开 shell、编译库刷新、按键绑定。
  * 真正的“跑在哪个终端里”交给 core/terminal.lua；项目类型识别交给 core/project.lua；
    因此本文件不直接调用 jobstart/terminal，只做策略与编排。
加载时机：
  * 由 init 侧显式调用 M.setup()，注册 BufReadPost/BufNewFile 自动命令；
    之后每打开一个缓冲区都会尝试 attach，靠 is_ros() 与 mappings_attached 过滤，开销极低。
约定：
  * 所有需要 ROS 上下文的入口都以 assert(is_ros(context)) 做前置校验，避免误用于普通 C++ 工程。
]]

local M = {}
-- 已就“某工作空间缺 compile_commands.json”提醒过的根目录集合，防止每次刷新都刷屏
local missing_notified = {}
-- 已挂过 ROS 快捷键的 bufnr 集合，避免同一缓冲区重复 set keymap
local mappings_attached = {}
-- setup() 的幂等开关，防止重复注册自动命令
local setup_complete = false

-- 判断路径是否为已存在的普通文件（目录不算）；参数 path 为字符串，返回 boolean。
local function is_file(path)
  if type(path) ~= 'string' or path == '' then return false end
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'file'
end

-- 根据 ROS_DISTRO、Ubuntu 版本和 /opt/ros 下的实际安装情况定位底座 setup.zsh。
-- 参数 root：ROS 安装根目录，默认 /opt/ros；找不到唯一候选时返回 nil。
local function distro_setup(root)
  local distro = vim.env.ROS_DISTRO
  if distro and distro ~= '' then
    local configured = root .. '/' .. distro .. '/setup.zsh'
    if is_file(configured) then return configured end
  end

  local version
  local ok_read, lines = pcall(vim.fn.readfile, '/etc/os-release')
  if ok_read then
    for _, line in ipairs(lines) do
      local value = line:match('^VERSION_ID="?([^" ]+)"?$')
      if value then version = value break end
    end
  end
  local expected = ({ ['24.04'] = 'jazzy', ['22.04'] = 'humble', ['20.04'] = 'foxy' })[version]
  if expected then
    local mapped = root .. '/' .. expected .. '/setup.zsh'
    if is_file(mapped) then return mapped end
  end

  local candidates = vim.fn.glob(root .. '/*/setup.zsh', false, true)
  if #candidates == 1 then return candidates[1] end
  return nil
end

-- 校验 compile_commands.json 是否真的可用，而不仅仅是“文件存在”。
-- 参数 path：待校验文件路径。返回 boolean：true 表示可作为编译库使用。
-- 校验点：可读取、可 JSON 解码、是非空数组，且每个条目的 file/directory 为字符串、
-- 并至少提供 command 或 arguments 之一——这些字段是 clangd 索引该条目的最低要求。
local function valid_compile_database(path)
  if not is_file(path) then return false end
  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then return false end
  local ok_decode, entries = pcall(vim.json.decode, table.concat(lines, '\n'))
  if not ok_decode or type(entries) ~= 'table' or #entries == 0 then return false end
  for _, entry in ipairs(entries) do
    if type(entry) ~= 'table' or type(entry.file) ~= 'string' or type(entry.directory) ~= 'string' then return false end
    if type(entry.command) ~= 'string' and type(entry.arguments) ~= 'table' then return false end
  end
  return true
end

-- 判断项目上下文是否属于 ROS（工作空间或单个包）。参数 context 可为 nil，返回 boolean。
local function is_ros(context)
  return context and (context.kind == 'ros_workspace' or context.kind == 'ros_package')
end

-- 取 ROS 工作空间的根目录：优先显式 workspace_root（包上下文），否则退回 root（工作空间上下文）。
local function workspace_root(context)
  return context.workspace_root or context.root
end

-- 推导 ROS 环境脚本列表，顺序即 source 顺序（先发行版底座，再本工作空间 overlay）。
-- 参数 context：项目上下文，非 ROS 时返回空表。返回 { string, ... }。
-- 底座按当前环境自动发现（本配置 shell 为 zsh）；overlay 取 <root>/install/setup.zsh，
-- 两者都只在文件真实存在时才纳入，避免 source 报错中断后续命令。
function M.environment_scripts(context)
  if not is_ros(context) then return {} end
  local result = {}
  local root = vim.env.ROS_ROOT
  if not root or root == '' then root = '/opt/ros' end
  local base = distro_setup(root)
  if is_file(base) then table.insert(result, base) end
  local overlay = workspace_root(context) .. '/install/setup.zsh'
  if is_file(overlay) then table.insert(result, overlay) end
  return result
end

-- 构造 colcon 命令行数组（不经过 shell，供 shell_join 再拼接）。
-- 参数 action：'build' | 'test'；context：ROS 上下文；extra_args：追加参数（可为 nil）。返回 argv 表。
-- 取值理由：build 时固定 --symlink-install（改脚本免重装）与
-- -DCMAKE_EXPORT_COMPILE_COMMANDS=ON（产出 compile_commands.json 供 clangd 用）；
-- 有 package_name 时用 --packages-select 只编当前包，缩短反馈环。
function M.colcon_argv(action, context, extra_args)
  assert(is_ros(context), 'colcon commands require a ROS project')
  assert(action == 'build' or action == 'test', 'unsupported colcon action: ' .. tostring(action))
  local argv = { 'colcon', action }
  if action == 'build' then
    vim.list_extend(argv, { '--symlink-install', '--cmake-args', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' })
  end
  if context.package_name then vim.list_extend(argv, { '--packages-select', context.package_name }) end
  if extra_args then vim.list_extend(argv, extra_args) end
  return argv
end

-- 路径包含关系判断（自身也视为包含）。参数 path/root：字符串；返回 boolean。
-- 统一 normalize 以消除尾部斜杠与 ./ 差异，再比较前缀 root .. '/'。
local function is_within(path, root)
  path = vim.fs.normalize(path)
  root = vim.fs.normalize(root)
  return path == root or path:sub(1, #root + 1) == root .. '/'
end

-- 重启覆盖该 root 的 clangd 客户端，使其重新读取新的 compile_commands.json。
-- 参数 root：工作空间根目录。无返回值；副作用是停掉旧客户端并延迟重新启用。
-- 只处理 root_dir 落在该工作空间内的客户端，避免误伤其它工程的 clangd；
-- stop(true) 为强制停止，随后 defer 100ms 再 enable，给进程退出留出时间差。
local function restart_clangd(root)
  local found = false
  for _, client in ipairs(vim.lsp.get_clients({ name = 'clangd' })) do
    local client_root = client.config and client.config.root_dir or client.root_dir
    if type(client_root) == 'string' and is_within(client_root, root) then
      found = true
      client:stop(true)
    end
  end
  if found then
    vim.defer_fn(function() pcall(vim.lsp.enable, 'clangd') end, 100)
  end
end

-- 刷新 ROS 编译库：按“包级优先、聚合兜底”的顺序挑选 compile_commands.json。
-- 参数 context：ROS 上下文。返回 { path = <绝对路径或 nil>, source = 'package'|'aggregate'|nil }。
-- 副作用：命中时重启 clangd；两处都不可用时按工作空间去重地 warn 一次并记入 missing_notified，
-- 成功后清掉该 root 的提醒标记，使后续再次缺失仍能提示。
function M.refresh_compile_commands(context)
  assert(is_ros(context), 'compile database refresh requires a ROS project')
  local root = workspace_root(context)
  local package_path = context.package_name and (root .. '/build/' .. context.package_name .. '/compile_commands.json') or nil
  local aggregate_path = root .. '/build/compile_commands.json'
  local result
  if package_path and valid_compile_database(package_path) then
    result = { path = vim.fs.normalize(package_path), source = 'package' }
  elseif valid_compile_database(aggregate_path) then
    result = { path = vim.fs.normalize(aggregate_path), source = 'aggregate' }
  else
    result = { path = nil, source = nil }
    if not missing_notified[root] then
      missing_notified[root] = true
      vim.notify(
        'No ROS compile_commands.json found. Run the ROS build action with CMAKE_EXPORT_COMPILE_COMMANDS enabled.',
        vim.log.levels.WARN,
        { title = 'ROS 2' }
      )
    end
    return result
  end
  missing_notified[root] = nil
  restart_clangd(root)
  return result
end

-- 执行 colcon build。参数 context：ROS 上下文；extra_args：附加 colcon 参数（可 nil）。
-- 返回 core.terminal 的构建终端实例。副作用：构建成功（exit 0）后自动刷新编译库并重启 clangd。
function M.build(context, extra_args)
  return require('core.terminal').run_build(
    'ROS build',
    M.colcon_argv('build', context, extra_args),
    workspace_root(context),
    M.environment_scripts(context),
    {
      on_exit = function(_, _, exit_code)
        if exit_code == 0 then M.refresh_compile_commands(context) end
      end,
    }
  )
end

-- 执行 colcon test。参数与 build 相同；返回终端实例。
-- 不传 on_exit：测试失败属正常结果，且测试不生成编译库，无需触发刷新。
function M.test(context, extra_args)
  return require('core.terminal').run_build(
    'ROS test',
    M.colcon_argv('test', context, extra_args),
    workspace_root(context),
    M.environment_scripts(context)
  )
end

-- 打开一个已 source 好 ROS 环境的交互 shell。参数 context：ROS 上下文；返回终端实例。
-- 先 deepcopy 再改写，保证不污染调用方的 context；根目录归一为 workspace_root，
-- 并把环境脚本塞进 env_scripts 字段，由 terminal.ros_shell 负责真正 source。
function M.shell(context)
  local copy = vim.deepcopy(context)
  copy.root = workspace_root(context)
  copy.env_scripts = M.environment_scripts(context)
  return require('core.terminal').ros_shell(copy)
end

-- 运行当前包内的可执行文件（ros2 run <pkg> <exe> [args]）。
-- 参数 context：ROS 上下文（必须已识别出包名）；executable：可执行名；args：额外参数（可 nil）。
-- 返回终端实例。用 assert 明确报错，而不是拼出无法运行的命令。
function M.run(context, executable, args)
  assert(context.package_name, 'ROS run requires a detected package')
  assert(type(executable) == 'string' and executable ~= '', 'ROS executable is required')
  local argv = { 'ros2', 'run', context.package_name, executable }
  if args then vim.list_extend(argv, args) end
  return require('core.terminal').run_build('ROS run', argv, workspace_root(context), M.environment_scripts(context))
end

-- 为 ROS 缓冲区挂载 <leader>r* 快捷键。参数 bufnr：缓冲区号；context：该缓冲区的项目上下文。
-- 无返回值。非 ROS 或已挂载过则直接返回（幂等）。每条映射都延迟到触发时才解析当前上下文，
-- 因此切换分支/项目后无需重挂；desc 文案用于 which-key 等提示，保持英文原文。
function M.attach(bufnr, context)
  if not is_ros(context) or mappings_attached[bufnr] then return end
  mappings_attached[bufnr] = true
  local opts = function(desc) return { buffer = bufnr, desc = desc } end
  vim.keymap.set('n', '<leader>rb', function() M.build(require('core.project').current(bufnr)) end, opts('ROS build package'))
  vim.keymap.set('n', '<leader>rt', function() M.test(require('core.project').current(bufnr)) end, opts('ROS test package'))
  vim.keymap.set('n', '<leader>rs', function() M.shell(require('core.project').current(bufnr)) end, opts('ROS sourced shell'))
  vim.keymap.set('n', '<leader>rc', function() M.refresh_compile_commands(require('core.project').current(bufnr)) end, opts('Refresh ROS compile database'))
  vim.keymap.set('n', '<leader>rr', function()
    vim.ui.input({ prompt = 'ROS executable: ' }, function(value)
      if value and value ~= '' then M.run(require('core.project').current(bufnr), value) end
    end)
  end, opts('ROS run executable'))
end

-- 模块初始化：注册自动命令，在每次读取/新建缓冲区时尝试挂载 ROS 快捷键。
-- 无参数、无返回值。幂等（setup_complete）；先置位再注册，避免回调内重入导致重复注册。
function M.setup()
  if setup_complete then return end
  setup_complete = true
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    callback = function(event) M.attach(event.buf, require('core.project').current(event.buf)) end,
  })
end

return M
