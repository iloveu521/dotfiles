--[[
lua/core/clangd.lua — clangd 启动参数的唯一出处
由 lua/plugins/lsp.lua 调用两次：注册 clangd 时给出初始 cmd，
以及在 before_init 里按 LSP 实际解析出的 root_dir 重算 cmd。
除 --compile-commands-dir 外参数固定；该参数随项目切换而变化，
保证换到不同工程时 clangd 能找到对应的编译数据库，而不是沿用旧目录。
]]
local M = {} -- 模块表

-- 所有项目通用的 clangd 参数；数组顺序即传给进程的命令行顺序
local base_command = {
  'clangd', -- 可执行程序名，由 PATH 或 mason 提供
  '--background-index', -- 后台为整个工程建索引：首次启动较慢，换来更准的跨文件跳转与补全
  '--clang-tidy', -- 启用 clang-tidy 检查，读取工程 .clang-tidy 并把结果作为诊断显示
  '--completion-style=detailed', -- 补全列表直接展开函数签名，减少一次确认
  '--header-insertion=iwyu', -- 自动补 include 时按 include-what-you-use 就近插入，不写进汇总头
  '--function-arg-placeholders', -- 补全函数调用时插入参数占位符，便于按位置填写实参
}

-- 组装某个项目上下文下的完整 clangd 启动参数。
-- context: core.project 的项目上下文，用于定位编译数据库。
-- source_path: 当前源文件路径，可为 nil；为 nil 时只按 context 的约定路径查找。
-- 返回: 新的参数数组（base_command 的深拷贝，调用方可安全增删）。
-- 副作用: 无，仅通过文件系统探测 compile_commands.json 是否存在。
function M.command(context, source_path)
  local command = vim.deepcopy(base_command) -- 深拷贝，避免下面的 insert 污染共享的 base_command
  local database = require('core.project').find_compile_commands(context, source_path)
  if database then
    -- clangd 只接受目录，故取数据库所在目录；找不到时不传该参数，
    -- 让 clangd 从 root_dir 起自行向上搜索
    table.insert(command, '--compile-commands-dir=' .. vim.fs.dirname(database))
  end
  return command
end

return M
