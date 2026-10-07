local M = {}

local valid_kinds = {
  standalone = true,
  cpp = true,
  cmake = true,
  ros_package = true,
  ros_workspace = true,
}

local cache = {}
local override_context
local commands_created = false

local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'file'
end

local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'directory'
end

local function start_directory(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  if is_file(path) then return vim.fs.dirname(path) end
  return path
end

local function ancestors(path)
  local result = {}
  local current = start_directory(path)
  while current do
    table.insert(result, current)
    local parent = vim.fs.dirname(current)
    if not parent or parent == current then break end
    current = parent
  end
  return result
end

local function read_file(path)
  local file = io.open(path, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  return content
end

local function ros_package_info(package_xml)
  local content = read_file(package_xml)
  if not content then return nil end
  if not content:find('ament_', 1, true)
    and not content:find('rclcpp', 1, true)
    and not content:find('rosidl', 1, true)
    and not content:find('<export', 1, true)
  then
    return nil
  end
  return { name = content:match('<name>%s*([^<]-)%s*</name>') }
end

local function nearest_ros_package(path)
  for _, candidate in ipairs(ancestors(path)) do
    local package_xml = candidate .. '/package.xml'
    if is_file(package_xml) then
      local info = ros_package_info(package_xml)
      if info then return candidate, info end
    end
  end
end

local function workspace_info(path)
  for _, candidate in ipairs(ancestors(path)) do
    local source_dir = candidate .. '/src'
    if is_dir(source_dir) then
      local packages = vim.fs.find('package.xml', { path = source_dir, type = 'file', limit = 50 })
      for _, package_xml in ipairs(packages) do
        if ros_package_info(package_xml) then
          local package_root, info = nearest_ros_package(path)
          return candidate, package_root, info
        end
      end
    end
  end
end

local function nearest_project_marker(path)
  for _, candidate in ipairs(ancestors(path)) do
    if is_file(candidate .. '/CMakeLists.txt') or is_file(candidate .. '/compile_commands.json') then
      return candidate, 'cmake'
    end
    if vim.uv.fs_stat(candidate .. '/.git') then return candidate, 'cpp' end
  end
end

local function make_context(kind, root, fields)
  local context = fields or {}
  context.kind = kind
  context.root = vim.fs.normalize(root)
  return context
end

function M.detect(start_path)
  if override_context then return vim.deepcopy(override_context) end
  start_path = start_path and vim.fs.normalize(vim.fn.fnamemodify(start_path, ':p')) or vim.uv.cwd()
  if cache[start_path] then return vim.deepcopy(cache[start_path]) end

  local workspace_root, package_root, package_info = workspace_info(start_path)
  local context
  if workspace_root then
    context = make_context('ros_workspace', workspace_root, {
      workspace_root = vim.fs.normalize(workspace_root),
      package_root = package_root and vim.fs.normalize(package_root) or nil,
      package_name = package_info and package_info.name or nil,
    })
  else
    package_root, package_info = nearest_ros_package(start_path)
    if package_root then
      context = make_context('ros_package', package_root, {
        package_root = vim.fs.normalize(package_root),
        package_name = package_info.name,
      })
    else
      local root, kind = nearest_project_marker(start_path)
      if root then
        context = make_context(kind, root)
      else
        context = make_context('standalone', start_directory(start_path))
      end
    end
  end

  cache[start_path] = context
  return vim.deepcopy(context)
end

function M.current(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then path = vim.uv.cwd() end
  return M.detect(path)
end

function M.override(kind, root)
  assert(valid_kinds[kind], 'invalid project kind: ' .. tostring(kind))
  assert(type(root) == 'string' and root ~= '', 'project root is required')
  override_context = make_context(kind, root, {
    workspace_root = kind == 'ros_workspace' and vim.fs.normalize(root) or nil,
    package_root = kind == 'ros_package' and vim.fs.normalize(root) or nil,
  })
  return vim.deepcopy(override_context)
end

function M.clear_override()
  override_context = nil
  cache = {}
end

local function first_existing(paths)
  for _, path in ipairs(paths) do
    if path and is_file(path) then return vim.fs.normalize(path) end
  end
end

function M.find_compile_commands(context, source_path)
  if not context then return nil end
  source_path = source_path and vim.fs.normalize(source_path) or nil

  if source_path then
    for _, candidate in ipairs(ancestors(source_path)) do
      local database = candidate .. '/compile_commands.json'
      if is_file(database) then return vim.fs.normalize(database) end
      if candidate == context.root then break end
    end
  end

  if context.kind == 'ros_workspace' then
    local package_database = context.package_name
      and (context.workspace_root .. '/build/' .. context.package_name .. '/compile_commands.json')
      or nil
    return first_existing({
      package_database,
      context.workspace_root .. '/build/compile_commands.json',
    })
  end

  return first_existing({
    context.root .. '/compile_commands.json',
    context.root .. '/build/compile_commands.json',
  })
end

function M.setup()
  if commands_created then return end
  commands_created = true

  vim.api.nvim_create_user_command('ProjectInfo', function()
    vim.notify(vim.inspect(M.current()), vim.log.levels.INFO, { title = 'Project' })
  end, { desc = 'Show detected project context' })

  vim.api.nvim_create_user_command('ProjectOverride', function(args)
    M.override(args.fargs[1], args.fargs[2] or vim.uv.cwd())
    vim.notify('Project override: ' .. args.fargs[1])
  end, {
    nargs = '+',
    desc = 'Override project kind and optional root',
    complete = function(_, line)
      if #vim.split(line, '%s+') <= 2 then return vim.tbl_keys(valid_kinds) end
      return 'dir'
    end,
  })

  vim.api.nvim_create_user_command('ProjectOverrideClear', function()
    M.clear_override()
    vim.notify('Project override cleared')
  end, { desc = 'Clear project override' })
end

return M
