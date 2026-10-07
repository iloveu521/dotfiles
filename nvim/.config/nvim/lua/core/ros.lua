local M = {}
local missing_notified = {}
local mappings_attached = {}
local setup_complete = false

local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'file'
end

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

local function is_ros(context)
  return context and (context.kind == 'ros_workspace' or context.kind == 'ros_package')
end

local function workspace_root(context)
  return context.workspace_root or context.root
end

function M.environment_scripts(context)
  if not is_ros(context) then return {} end
  local result = {}
  local base = '/opt/ros/jazzy/setup.zsh'
  if is_file(base) then table.insert(result, base) end
  local overlay = workspace_root(context) .. '/install/setup.zsh'
  if is_file(overlay) then table.insert(result, overlay) end
  return result
end

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

local function is_within(path, root)
  path = vim.fs.normalize(path)
  root = vim.fs.normalize(root)
  return path == root or path:sub(1, #root + 1) == root .. '/'
end

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
        { title = 'ROS 2 Jazzy' }
      )
    end
    return result
  end
  missing_notified[root] = nil
  restart_clangd(root)
  return result
end

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

function M.test(context, extra_args)
  return require('core.terminal').run_build(
    'ROS test',
    M.colcon_argv('test', context, extra_args),
    workspace_root(context),
    M.environment_scripts(context)
  )
end

function M.shell(context)
  local copy = vim.deepcopy(context)
  copy.root = workspace_root(context)
  copy.env_scripts = M.environment_scripts(context)
  return require('core.terminal').ros_shell(copy)
end

function M.run(context, executable, args)
  assert(context.package_name, 'ROS run requires a detected package')
  assert(type(executable) == 'string' and executable ~= '', 'ROS executable is required')
  local argv = { 'ros2', 'run', context.package_name, executable }
  if args then vim.list_extend(argv, args) end
  return require('core.terminal').run_build('ROS run', argv, workspace_root(context), M.environment_scripts(context))
end

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

function M.setup()
  if setup_complete then return end
  setup_complete = true
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    callback = function(event) M.attach(event.buf, require('core.project').current(event.buf)) end,
  })
end

return M
