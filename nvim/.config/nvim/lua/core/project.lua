--[[
lua/core/project.lua — 项目类型识别、上下文缓存与编译数据库定位
加载时机：init.lua 启动阶段即 require('core.project').setup()，注册三个用户
命令；其余模块（lsp、ros、debug、navigation、ui 等）在需要时再调用
M.current/M.detect 查询，本模块因此是整个配置的「项目事实来源」。
识别顺序（见 M.detect）：ros_workspace → ros_package → cmake/cpp → standalone。
所有判定都从起始路径向上遍历祖先目录，取最近命中的那一层，所以子目录中的
文件会继承最近的项目根；结果按起始路径缓存，可用 :ProjectOverride 强制指定
类型与根目录、用 :ProjectOverrideClear 撤销并清缓存。
]]

local M = {} -- 模块表

-- 合法项目类型白名单：既用于 M.override 的参数校验，
-- 也供 :ProjectOverride 的补全枚举全部可选值
local valid_kinds = {
  standalone = true, -- 无任何工程标志物，root 取起始目录
  cpp = true, -- 仅凭 .git 认定的一般 C/C++ 仓库
  cmake = true, -- 存在 CMakeLists.txt 或 compile_commands.json
  ros_package = true, -- 含有效 package.xml 的单个 ROS 包
  ros_workspace = true, -- 形如 <ws>/src/<pkg> 的 ROS 工作空间
}

local cache = {} -- start_path → context 的探测缓存，避免反复 fs_stat
local override_context -- 用户强制指定的上下文；非空时 M.detect 直接返回它
local commands_created = false -- setup 幂等标记，防止重复注册同名用户命令而报错

-- 判断路径是否为普通文件（目录、指向目录的符号链接都返回 false）。
-- 返回: boolean
local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'file'
end

-- 判断路径是否存在且为目录。
-- 返回: boolean
local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'directory'
end

-- 求向上遍历的起点：路径补成绝对形式并规范化；
-- 若给的是文件则退到其所在目录，保证 ancestors 始终从目录出发
local function start_directory(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  if is_file(path) then return vim.fs.dirname(path) end
  return path
end

-- 自起始目录向上收集祖先目录。
-- 返回: 数组，第 1 项是起始目录本身，最后一项是文件系统根。
-- 根目录的 dirname 仍是自身，故用 parent == current 终止循环，避免死循环
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

-- 一次性整体读取文件内容。
-- 返回: 文件内容字符串；文件不存在或不可读时返回 nil。
-- 副作用: 打开并关闭一个文件句柄。
local function read_file(path)
  local file = io.open(path, 'r')
  if not file then return nil end
  local content = file:read('*a')
  file:close()
  return content
end

-- 解析 package.xml，判断它是否代表一个真正参与构建的 ROS 包。
-- 依据: 内容中出现 ament_ / rclcpp / rosidl / <export 任一关键字；
-- 这样可以过滤掉只有 package.xml 外壳、实际不参与构建的目录。
-- 返回: { name = <name> 标签内容或 nil }；不像 ROS 包时返回 nil。
local function ros_package_info(package_xml)
  local content = read_file(package_xml)
  if not content then return nil end
  -- find 用 plain=true，避免 _ 被当成 Lua 模式字符
  if not content:find('ament_', 1, true)
    and not content:find('rclcpp', 1, true)
    and not content:find('rosidl', 1, true)
    and not content:find('<export', 1, true)
  then
    return nil
  end
  -- <name> 标签内外允许空白；取第一对匹配
  return { name = content:match('<name>%s*([^<]-)%s*</name>') }
end

-- 向上寻找最近的、有有效 package.xml 的 ROS 包根。
-- 返回: package_root 目录, 该包的解析结果；找不到时无返回值（nil）。
-- 命中第一个有效包即停止，不再继续向上，保证「最近优先」。
local function nearest_ros_package(path)
  for _, candidate in ipairs(ancestors(path)) do
    local package_xml = candidate .. '/package.xml'
    if is_file(package_xml) then
      local info = ros_package_info(package_xml)
      if info then return candidate, info end
    end
  end
end

-- 判断 path 是否位于某个 ROS 工作空间（colcon 布局）内。
-- 依据: 祖先目录存在 src/，且 src/ 下能找到带有效 package.xml 的包。
-- 返回: workspace_root, 当前文件所属的包根, 包信息；不匹配时返回 nil。
-- 副作用: 读取若干 package.xml 文件内容。
local function workspace_info(path)
  for _, candidate in ipairs(ancestors(path)) do
    local source_dir = candidate .. '/src'
    if is_dir(source_dir) then
      -- 最多扫描 50 个 package.xml，避免超大工作空间遍历过慢
      local packages = vim.fs.find('package.xml', { path = source_dir, type = 'file', limit = 50 })
      for _, package_xml in ipairs(packages) do
        -- 只要有一个真包就确认这是工作空间，随后再回头定位当前文件属于哪个包
        if ros_package_info(package_xml) then
          local package_root, info = nearest_ros_package(path)
          return candidate, package_root, info
        end
      end
    end
  end
end

-- 在祖先目录中寻找普通 C/C++ 工程的标志物，决定 cmake 还是 cpp。
-- 依据: 该层有 CMakeLists.txt 或 compile_commands.json → cmake；
-- 否则该层有 .git（文件或目录都算，覆盖 worktree）→ cpp。
-- 同层中 cmake 优先于 cpp；逐层向上，最近的标记胜出。
-- 返回: 工程根目录, 'cmake' 或 'cpp'；都没有时返回 nil。
local function nearest_project_marker(path)
  for _, candidate in ipairs(ancestors(path)) do
    if is_file(candidate .. '/CMakeLists.txt') or is_file(candidate .. '/compile_commands.json') then
      return candidate, 'cmake'
    end
    if vim.uv.fs_stat(candidate .. '/.git') then return candidate, 'cpp' end
  end
end

-- 组装并规范化 context 表。
-- kind: 项目类型（valid_kinds 之一）。
-- root: 项目根目录。
-- fields: 可选的额外字段表，会被直接复用为 context 本体。
-- 返回: context 表，root 已规范化（去掉 ./、重复分隔符等）。
local function make_context(kind, root, fields)
  local context = fields or {}
  context.kind = kind
  context.root = vim.fs.normalize(root)
  return context
end

-- 核心入口：识别 start_path 所属的项目上下文。
-- start_path: 文件或目录路径；省略时以 vim.uv.cwd() 为起点。
-- 返回: context 的深拷贝。必有 kind 与 root；ros_workspace 额外带
--       workspace_root/package_root/package_name，ros_package 额外带
--       package_root/package_name。
-- 副作用: 读写模块级 cache；override 生效时不读缓存也不写缓存。
function M.detect(start_path)
  if override_context then return vim.deepcopy(override_context) end
  -- 先统一成绝对规范路径再查缓存，使同一目录的不同写法命中同一条记录
  start_path = start_path and vim.fs.normalize(vim.fn.fnamemodify(start_path, ':p')) or vim.uv.cwd()
  if cache[start_path] then return vim.deepcopy(cache[start_path]) end

  -- 判定顺序第 1、2 步：先看是否处于 ROS 工作空间，再看是否处于单个 ROS 包
  local workspace_root, package_root, package_info = workspace_info(start_path)
  local context
  if workspace_root then
    context = make_context('ros_workspace', workspace_root, {
      workspace_root = vim.fs.normalize(workspace_root), -- 工作空间根，colcon build 的输出基准
      package_root = package_root and vim.fs.normalize(package_root) or nil, -- 当前文件所属包，可能为空
      package_name = package_info and package_info.name or nil, -- 包名，用于拼 build/<name>/compile_commands.json
    })
  else
    package_root, package_info = nearest_ros_package(start_path)
    if package_root then
      context = make_context('ros_package', package_root, {
        package_root = vim.fs.normalize(package_root),
        package_name = package_info.name, -- package.xml 没有 <name> 时为 nil
      })
    else
      -- 判定顺序第 3、4 步：普通 CMake/C++ 工程，最后退化为 standalone
      local root, kind = nearest_project_marker(start_path)
      if root then
        context = make_context(kind, root)
      else
        -- 找不到任何工程标志物：以起始目录为 root，类型记为 standalone
        context = make_context('standalone', start_directory(start_path))
      end
    end
  end

  cache[start_path] = context
  return vim.deepcopy(context) -- 返回副本，防止调用方改动污染缓存
end

-- 取某个 buffer 对应的项目上下文。
-- bufnr: buffer 号；省略或 0 表示当前 buffer。
-- 返回: M.detect 的结果；buffer 无名字（如 scratch buffer）时以 cwd 为起点。
function M.current(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then path = vim.uv.cwd() end
  return M.detect(path)
end

-- 手动覆盖项目类型与根目录；覆盖生效期间 M.detect 不再做任何文件系统探测。
-- kind: valid_kinds 中的键，非法值直接 assert 失败。
-- root: 非空路径字符串（相对路径按 cwd 解析）。
-- 返回: 新 override_context 的深拷贝。
-- 副作用: 设置模块级 override_context；已有 cache 保留，但 detect 不再读取。
function M.override(kind, root)
  assert(valid_kinds[kind], 'invalid project kind: ' .. tostring(kind))
  assert(type(root) == 'string' and root ~= '', 'project root is required')
  override_context = make_context(kind, root, {
    -- 只有对应类型才填相应字段，其他类型留 nil，避免下游误用
    workspace_root = kind == 'ros_workspace' and vim.fs.normalize(root) or nil,
    package_root = kind == 'ros_package' and vim.fs.normalize(root) or nil,
  })
  return vim.deepcopy(override_context)
end

-- 取消覆盖并清空缓存，让后续探测重新从文件系统读取（切换项目后可调用刷新）。
-- 副作用: 清空模块级 override_context 与 cache。
function M.clear_override()
  override_context = nil
  cache = {}
end

-- 返回 paths 中第一个真实存在的文件（已规范化）。
-- 返回: 规范化后的路径；都不存在时返回 nil。
local function first_existing(paths)
  for _, path in ipairs(paths) do
    if path and is_file(path) then return vim.fs.normalize(path) end
  end
end

-- 为 clangd 定位 compile_commands.json（编译数据库）。
-- context: M.detect 的返回值；为 nil 时直接放弃。
-- source_path: 当前源文件路径，可为 nil。
-- 返回: 数据库文件的规范化绝对路径；找不到时返回 nil。
-- 查找优先级：
--   1) 从源文件所在目录逐级向上找 compile_commands.json，走到 context.root
--      即停止，避免越界到无关的父工程；
--   2) ros_workspace：build/<package_name>/compile_commands.json，再退回 build/compile_commands.json；
--   3) 其他类型：<root>/compile_commands.json，再退回 <root>/build/compile_commands.json。
function M.find_compile_commands(context, source_path)
  if not context then return nil end
  source_path = source_path and vim.fs.normalize(source_path) or nil

  -- 优先级 1：就近搜索，通常对应源码树内直接生成的编译库
  if source_path then
    for _, candidate in ipairs(ancestors(source_path)) do
      local database = candidate .. '/compile_commands.json'
      if is_file(database) then return vim.fs.normalize(database) end
      if candidate == context.root then break end -- 已到项目根仍无命中，转用下面的约定路径
    end
  end

  if context.kind == 'ros_workspace' then
    -- 优先级 2：colcon 把编译库生成在 build/ 下，先找当前包，再退回整体
    local package_database = context.package_name
      and (context.workspace_root .. '/build/' .. context.package_name .. '/compile_commands.json')
      or nil
    return first_existing({
      package_database,
      context.workspace_root .. '/build/compile_commands.json',
    })
  end

  -- 优先级 3：一般 CMake/C++ 工程常见的两种布局：源码根或 build/ 子目录
  return first_existing({
    context.root .. '/compile_commands.json',
    context.root .. '/build/compile_commands.json',
  })
end

-- 注册本模块提供的用户命令；由 init.lua 在启动阶段调用。
-- 返回: 无。
-- 副作用: 创建 :ProjectInfo / :ProjectOverride / :ProjectOverrideClear；
--         借助 commands_created 保证只注册一次（重复注册同名命令会报错）。
function M.setup()
  if commands_created then return end
  commands_created = true

  -- :ProjectInfo —— 弹出当前 buffer 识别到的完整上下文，用于排查误判
  vim.api.nvim_create_user_command('ProjectInfo', function()
    vim.notify(vim.inspect(M.current()), vim.log.levels.INFO, { title = 'Project' })
  end, { desc = 'Show detected project context' })

  -- :ProjectOverride <kind> [root] —— 临时强制项目类型，root 省略时取 cwd
  vim.api.nvim_create_user_command('ProjectOverride', function(args)
    M.override(args.fargs[1], args.fargs[2] or vim.uv.cwd())
    vim.notify('Project override: ' .. args.fargs[1])
  end, {
    nargs = '+', -- 至少一个参数（kind）；第二个参数 root 可选
    desc = 'Override project kind and optional root',
    -- 补全：尚未填类型时列出全部合法 kind，填到第二个参数时补全目录
    complete = function(_, line)
      if #vim.split(line, '%s+') <= 2 then return vim.tbl_keys(valid_kinds) end
      return 'dir'
    end,
  })

  -- :ProjectOverrideClear —— 取消覆盖并清空缓存，恢复自动探测
  vim.api.nvim_create_user_command('ProjectOverrideClear', function()
    M.clear_override()
    vim.notify('Project override cleared')
  end, { desc = 'Clear project override' })
end

return M
