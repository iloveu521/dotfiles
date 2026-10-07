local M = {}

local function resolve_lookup(lookup, name)
  local value = lookup(name)
  if type(value) == 'number' or type(value) == 'boolean' then
    if value == 1 or value == true then return name end
    return nil
  end
  if type(value) == 'string' and value ~= '' then return value end
end

local function default_executable(name)
  local path = vim.fn.exepath(name)
  if path ~= '' then return path end
  if name == 'codelldb' then
    local mason_path = vim.fn.stdpath('data') .. '/mason/bin/codelldb'
    if vim.fn.executable(mason_path) == 1 then return mason_path end
  end
  return ''
end

function M.adapter_status(executable_fn)
  executable_fn = executable_fn or default_executable
  local gdb = resolve_lookup(executable_fn, 'gdb')
  local codelldb = resolve_lookup(executable_fn, 'codelldb')
  return {
    gdb = { available = gdb ~= nil, path = gdb, primary_for_ros = true },
    codelldb = { available = codelldb ~= nil, path = codelldb, optional = true },
  }
end

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

local function scripts_for(context)
  if not context or (context.kind ~= 'ros_workspace' and context.kind ~= 'ros_package') then return nil end
  local scripts = require('core.ros').environment_scripts(context)
  return #scripts > 0 and scripts or nil
end

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

local function adapter_for(context)
  local status = M.adapter_status()
  if context and (context.kind == 'ros_workspace' or context.kind == 'ros_package') and status.gdb.available then return 'gdb' end
  if status.codelldb.available then return 'codelldb' end
  return 'gdb'
end

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

function M.setup_dynamic_context(dap)
  dap.listeners.on_config.nvim_environment = function(configuration)
    if not configuration._dynamic_project then return configuration end
    return M.apply_context(configuration, require('core.project').current())
  end
end

function M.setup_ui(dap, dapui)
  dap.listeners.after.event_initialized.nvim_environment = function() dapui.open() end
  dap.listeners.after.event_stopped.nvim_environment = function() dapui.open() end
end

return M
