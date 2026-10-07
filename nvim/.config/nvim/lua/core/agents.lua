local M = {}

local definitions = {
  { name = 'codex', cmd = 'codex', guidance = 'Install the Codex CLI and authenticate outside Neovim.' },
  { name = 'claude', cmd = 'claude', guidance = 'Install the Claude CLI and authenticate outside Neovim.' },
  { name = 'gemini', cmd = 'gemini', guidance = 'Install the Gemini CLI and authenticate outside Neovim.' },
  { name = 'opencode', cmd = 'opencode', guidance = 'Install the OpenCode CLI and configure it outside Neovim.' },
}

local executable_lookup = vim.fn.executable
local instances = {}
local active_name
local last_name

local function available(value)
  if type(value) == 'string' then return value ~= '' end
  return value == true or value == 1
end

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

local function definition(name)
  for index, item in ipairs(M.discover()) do
    if item.name == name then return item, index end
  end
end

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

function M.last()
  if not last_name then
    vim.notify('No agent session has been opened yet.', vim.log.levels.INFO, { title = 'Agents' })
    return nil
  end
  local instance = instances[last_name]
  if instance and instance:is_open() then return instance end
  return M.toggle(last_name)
end

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

function M._set_executable(fn)
  executable_lookup = fn
end

function M._reset()
  instances = {}
  active_name = nil
  last_name = nil
  executable_lookup = vim.fn.executable
end

return M
