--[[
lua/core/terminal.lua — 角色化（role）终端实例管理：复用、构建终端与 ROS 交互 shell。

职责与地位：
  * 把 toggleterm 的 Terminal 按“角色名”缓存起来，成为 core 层唯一的终端出入口；
    core/ros.lua、core/debug.lua 等都不直接用 toggleterm，而是调用本模块。
  * 提供三类角色：general:<n>（编号常驻终端）、build:<名字>（一次性构建/运行）、
    ros-shell:<root>（每个工作空间一个已 source 环境的 shell）。
加载时机：
  * 由 init 侧调用 M.setup()，注册 :Terminal 用户命令；其余函数按需被调用。
复用策略（重要）：
  * 同一个角色名只对应一个 Terminal 实例，反复 toggle 只是显示/隐藏，不丢历史与工作目录；
    这正是“常驻终端”的来源。角色名中带 index / 构建名 / root，用来把不同用途彼此隔离。
]]

local M = {}
-- 角色名 -> Terminal 实例。这是复用策略的唯一状态载体，M._reset() 会整体清空。
local roles = {}
-- :Terminal 命令只注册一次的幂等开关
local commands_created = false

-- 把环境脚本列表拼成一段 shell 前缀：'source <脚本>' 之间用 && 串接。
-- 参数 scripts：nil、字符串或字符串列表。返回拼接后的字符串，nil 表示无需 source。
-- 用 shellescape 包裹路径，避免含空格/特殊字符的路径被 shell 拆词；
-- 用 && 连接是为了“前一个 source 失败就不继续”，避免带着半套环境去构建。
local function source_prefix(scripts)
  if not scripts then return nil end
  if type(scripts) == 'string' then scripts = { scripts } end
  local commands = {}
  for _, script in ipairs(scripts) do
    table.insert(commands, 'source ' .. vim.fn.shellescape(script))
  end
  return table.concat(commands, ' && ')
end

-- 按角色取出或新建终端实例（复用策略入口）。
-- 参数 role：角色名（字符串）；opts：toggleterm Terminal 的构造参数。返回 Terminal 实例。
-- 已存在同名实例时直接返回旧的并忽略 opts，以保证角色配置在生命周期内稳定。
local function create(role, opts)
  if roles[role] then return roles[role] end
  roles[role] = require('toggleterm.terminal').Terminal:new(opts)
  return roles[role]
end

-- 取出（必要时新建）并 toggle 该角色终端。参数 role/opts 同上；返回 Terminal 实例。
local function open(role, opts)
  local instance = create(role, opts)
  instance:toggle()
  return instance
end

-- 打开第 index 号常驻终端。参数 index：编号（字符串/数字，非法值回退为 1）。
-- 返回 Terminal 实例。角色名含编号，故 1/2/3 号终端互不干扰；
-- hidden = true 表示初始不占屏幕，只由 toggle 显隐；size = 14 为横向分屏高度。
function M.general(index)
  index = tonumber(index) or 1
  return open('general:' .. index, {
    count = index,
    direction = 'horizontal',
    size = 14,
    display_name = 'Terminal ' .. index,
    hidden = true,
  })
end

-- 在复用式构建终端里执行一条命令（构建/测试/运行的统一入口）。
-- 参数 name：角色显示名与角色键的一部分；argv：命令数组；cwd：工作目录；
--   env_script：环境脚本（nil/字符串/列表）；options：可选表，支持 on_exit 回调。
-- 返回 Terminal 实例。副作用：命令以 zsh -lc 形式在指定目录执行。
-- 关键语义：同名构建终端若已存在，先 shutdown 再重建——让新的 colcon 从头开始，
-- 而不是把命令打进上一轮可能仍在运行的 shell（也避免重复 source 叠加环境）。
-- close_on_exit = false 使命令结束后终端仍保留，便于回看编译错误。
function M.run_build(name, argv, cwd, env_script, options)
  assert(type(name) == 'string' and name ~= '', 'terminal role name is required')
  assert(type(argv) == 'table' and #argv > 0, 'build argv is required')
  assert(type(cwd) == 'string' and cwd ~= '', 'build cwd is required')

  local command = require('core.commands').shell_join(argv)
  local prefix = source_prefix(env_script)
  if prefix then command = prefix .. ' && ' .. command end

  local role = 'build:' .. name
  if roles[role] then
    roles[role]:shutdown()
    roles[role] = nil
  end
  return open(role, {
    cmd = command,
    dir = cwd,
    direction = 'horizontal',
    size = 14,
    close_on_exit = false,
    display_name = name,
    hidden = true,
    on_exit = options and options.on_exit or nil,
  })
end

-- 打开“已 source 好 ROS 环境”的交互 shell。参数 context：需含 root 与 env_scripts/env_script。
-- 返回 Terminal 实例。sourced 后 exec $SHELL，把当前 zsh 替换为真正的交互 shell，
-- 从而继承 source 出的 ROS_*/AMENT_* 等变量；用 shellescape 保证 vim.o.shell 路径安全。
-- 角色名按 root 区分，因此每个工作空间各有一份自己的 ROS shell，可来回 toggle。
function M.ros_shell(context)
  assert(context and context.root, 'ROS project context is required')
  local scripts = context.env_scripts or context.env_script
  assert(scripts, 'ROS environment script is required')
  local command = source_prefix(scripts) .. ' && exec ' .. vim.fn.shellescape(vim.o.shell)
  return open('ros-shell:' .. context.root, {
    cmd = command,
    dir = context.root,
    direction = 'horizontal',
    size = 14,
    display_name = 'ROS shell',
    hidden = true,
  })
end

-- 测试辅助：清空角色表，丢弃全部缓存实例（不影响已开着的终端进程本身）。无参数、无返回值。
function M._reset()
  roles = {}
end

-- 模块初始化：注册 :Terminal [n] 用户命令。无参数、无返回值。幂等（commands_created）。
-- nargs = '?' 允许省略编号；args.args 为空串时回退为 1，因此裸 :Terminal 打开 1 号终端。
-- desc 字符串会被 :command 与帮助补全直接展示，保持英文原文。
function M.setup()
  if commands_created then return end
  commands_created = true
  vim.api.nvim_create_user_command('Terminal', function(args) M.general(args.args ~= '' and args.args or 1) end, {
    nargs = '?',
    desc = 'Open a persistent numbered terminal',
  })
end

return M
