--[[
lua/core/agents.lua — CLI 编码助手（codex / claude / gemini / opencode）探测、切换与生命周期。

职责与地位：
  * core 层中负责“把外部 AI 编码 CLI 接进 Neovim”的模块：探测可执行文件、开竖屏终端、
    在多个助手之间切换、挑一个最近用过的恢复、以及彻底 kill。
  * 自身不定义按键；由 init 侧把 M.toggle / M.select / M.kill / M.last 绑到 <leader>a*。
加载时机：
  * 按需调用，无 setup()；但实例在首次 toggle 时才创建（惰性），未用到的助手不占资源。
关键设计：
  * 每个助手最多一个实例（instances[name]），toggle 只显隐，会话与上下文得以保留；
  * 同一时刻只允许一个助手“活跃”（active_name），切到别的助手会把前一个 close() 收起，
    避免两个 TUI 抢焦点/抢同一份代码上下文；last_name 用于“恢复上次”。
]]

local M = {}

-- 受支持的助手清单：name 为标识与显示名，cmd 为可执行名，guidance 是缺失时的安装提示。
-- 顺序即 telescope 列表顺序；guidance 属于面向用户的英文文案，原样保留。
local definitions = {
  { name = 'codex', cmd = 'codex', guidance = 'Install the Codex CLI and authenticate outside Neovim.' },
  { name = 'claude', cmd = 'claude', guidance = 'Install the Claude CLI and authenticate outside Neovim.' },
  { name = 'gemini', cmd = 'gemini', guidance = 'Install the Gemini CLI and authenticate outside Neovim.' },
  { name = 'opencode', cmd = 'opencode', guidance = 'Install the OpenCode CLI and configure it outside Neovim.' },
}

-- 可执行文件探测函数。默认 vim.fn.executable；测试可通过 M._set_executable 替换。
local executable_lookup = vim.fn.executable
-- 助手名 -> Terminal 实例，实现“每个助手一个常驻会话”
local instances = {}
-- 当前处于打开状态的助手名；nil 表示当前没有助手面板可见
local active_name
-- 最近一次打开过的助手名；用于 M.last() 快速回到上一次的助手
local last_name

-- 把 executable 类返回值归一为 boolean。参数 value：数字/字符串/布尔。返回 boolean。
-- vim.fn.executable 返回 0/1；注入的假实现可能返回路径字符串或 true，
-- 因此空字符串视为未安装，非空字符串与 1/true 一律视为已安装。
local function available(value)
  if type(value) == 'string' then return value ~= '' end
  return value == true or value == 1
end

-- 探测全部助手的安装情况。参数 executable_fn：可选的自定义探测函数（默认用内置的）。
-- 返回数组，每项 { name, cmd, installed, label, guidance }，顺序与 definitions 一致。
-- label 在已安装时为纯名字，未安装时追加 ' — unavailable'，作为 telescope 的显示文本；
-- ordinal 另取 name，保证已安装/未安装的前缀不影响搜索排序。
function M.discover(executable_fn)
  executable_fn = executable_fn or executable_lookup
  local result = {}
  for _, definition in ipairs(definitions) do
    local installed = available(executable_fn(definition.cmd))
    table.insert(result, {
      name = definition.name,
      cmd = definition.cmd,
      installed = installed,
      label = installed and definition.name or (definition.name .. ' — unavailable'),
      guidance = definition.guidance,
    })
  end
  return result
end

-- 按名字查回定义项。参数 name：助手名。返回 (定义项, 在列表中的下标)，未找到返回 nil。
-- 下标用于给终端分配互不冲突的 count（100 + index），保证多个助手分屏编号稳定。
local function definition(name)
  for index, item in ipairs(M.discover()) do
    if item.name == name then return item, index end
  end
end

-- 取出或惰性创建某助手的终端实例。参数 agent：定义项；index：列表下标。返回 Terminal 实例。
-- 复用语义：已存在就直接返回，因此再次 toggle 会接续同一会话；
-- 工作目录取 core.project.current().root，使助手在项目根启动；
-- direction = vertical / size = 52 给 TUI 一个够宽的右栏；close_on_exit = false
-- 让 CLI 退出后仍能看到它的最后输出。
local function instance_for(agent, index)
  if instances[agent.name] then return instances[agent.name] end
  local root = require('core.project').current().root
  instances[agent.name] = require('toggleterm.terminal').Terminal:new({
    cmd = agent.cmd,
    count = 100 + index,
    dir = root,
    direction = 'vertical',
    size = 52,
    display_name = 'Agent: ' .. agent.name,
    hidden = true,
    close_on_exit = false,
  })
  return instances[agent.name]
end

-- 切换某助手的终端显示/隐藏（模块主入口）。
-- 参数 name：助手名。返回 Terminal 实例；若未安装则 notify 提示并返回 nil；名字未知时 assert 失败。
-- 切换语义：先关掉另一个正开着的助手（互斥），再 toggle 目标实例；
-- 随后按 is_open() 的真实结果回写 active_name（开则记为当前，关掉的若是自己则清空），
-- last_name 只在真正打开时更新，使 M.last() 始终指向“最近用过的”。
function M.toggle(name)
  local agent, index = definition(name)
  assert(agent, 'unknown agent: ' .. tostring(name))
  if not agent.installed then
    vim.notify(agent.guidance, vim.log.levels.WARN, { title = agent.name .. ' unavailable' })
    return nil
  end

  if active_name and active_name ~= name then
    local active = instances[active_name]
    if active and active:is_open() then active:close() end
  end

  local instance = instance_for(agent, index)
  instance:toggle()
  if instance:is_open() then
    active_name = name
    last_name = name
  elseif active_name == name then
    active_name = nil
  end
  return instance
end

-- 回到最近使用的助手。无参数；返回 Terminal 实例或 nil。
-- 若该助手面板当前已打开则直接返回（不再 toggle，避免把它关掉）；
-- 否则重新 toggle 出来。从未用过任何助手时只给一个 info 提示。
function M.last()
  if not last_name then
    vim.notify('No agent session has been opened yet.', vim.log.levels.INFO, { title = 'Agents' })
    return nil
  end
  local instance = instances[last_name]
  if instance and instance:is_open() then return instance end
  return M.toggle(last_name)
end

-- 彻底结束某助手会话。参数 name：助手名，省略时依次回退到 active_name、last_name。
-- 返回 boolean：true 表示确实杀掉了一个实例，false 表示无可杀对象（并给出 info 提示）。
-- kill 语义与 toggle/close 不同：shutdown 终止进程并丢弃实例缓存，
-- 下次 toggle 会重新创建（新会话、新上下文）；同时清理 active_name/last_name 以免留下悬空引用。
function M.kill(name)
  name = name or active_name or last_name
  if not name or not instances[name] then
    vim.notify('No matching agent session is running.', vim.log.levels.INFO, { title = 'Agents' })
    return false
  end
  instances[name]:shutdown()
  instances[name] = nil
  if active_name == name then active_name = nil end
  if last_name == name then last_name = nil end
  return true
end

-- 用 telescope 列出全部助手并选择一个打开。无参数、无返回值。
-- 列表来自 M.discover()，显示 label（含 unavailable 标记），排序键为 ordinal = name；
-- 默认回车动作被替换为：先关选择器，再对选中项调用 M.toggle。
-- telescope 的 require 放在函数体内，避免未安装/未使用 telescope 时也要加载它。
function M.select()
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local entries = M.discover()

  pickers.new({}, {
    prompt_title = 'Coding agents',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(agent)
        return { value = agent, display = agent.label, ordinal = agent.name }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then M.toggle(selection.value.name) end
      end)
      return true
    end,
  }):find()
end

-- 测试辅助：替换可执行文件探测函数。参数 fn：接收入参名、返回 0/1/路径/布尔的函数。无返回值。
function M._set_executable(fn)
  executable_lookup = fn
end

-- 测试辅助：把实例表、当前/最近助手与探测函数全部重置为初始状态。无参数、无返回值。
function M._reset()
  instances = {}
  active_name = nil
  last_name = nil
  executable_lookup = vim.fn.executable
end

return M
