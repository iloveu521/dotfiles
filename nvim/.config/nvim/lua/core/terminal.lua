local M = {}
local roles = {}
local commands_created = false

local function source_prefix(scripts)
  if not scripts then return nil end
  if type(scripts) == 'string' then scripts = { scripts } end
  local commands = {}
  for _, script in ipairs(scripts) do
    table.insert(commands, 'source ' .. vim.fn.shellescape(script))
  end
  return table.concat(commands, ' && ')
end

local function create(role, opts)
  if roles[role] then return roles[role] end
  roles[role] = require('toggleterm.terminal').Terminal:new(opts)
  return roles[role]
end

local function open(role, opts)
  local instance = create(role, opts)
  instance:toggle()
  return instance
end

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

function M._reset()
  roles = {}
end

function M.setup()
  if commands_created then return end
  commands_created = true
  vim.api.nvim_create_user_command('Terminal', function(args) M.general(args.args ~= '' and args.args or 1) end, {
    nargs = '?',
    desc = 'Open a persistent numbered terminal',
  })
end

return M
