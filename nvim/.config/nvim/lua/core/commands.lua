--[[
lua/core/commands.lua — 命令参数转义与命令行拼装
纯函数工具模块：自身没有副作用，也不注册任何命令或自动命令，
只被需要把参数列表交给 shell 的模块 require（目前是 core/terminal.lua）。
作用是把 argv 形式的参数还原成一条能被 shell 正确切分的命令字符串，
避免空格、引号、$ 等字符在拼串时改变参数边界与语义。
]]
local M = {} -- 模块表，require 后直接使用 M.shell_join

-- 把参数数组拼成一条可直接交给 shell 的命令行。
-- argv: 数组，元素为字符串或可被 tostring 转换的值，每个元素视为一个独立参数。
-- 返回: 字符串，元素逐个转义后用单个空格连接。
-- 副作用: 无（不启动进程、不改动 buffer）。
function M.shell_join(argv)
  -- 参数必须是数组；否则 ipairs/table.concat 的行为不可预期，宁可立刻失败便于定位调用点
  assert(type(argv) == 'table', 'argv must be a table')
  local escaped = {} -- 与 argv 等长的转义结果，下标与 argv 对齐
  for index, argument in ipairs(argv) do
    -- tostring 兼容数字等非字符串参数；shellescape 按当前 shell 规则加引号并转义特殊字符
    escaped[index] = vim.fn.shellescape(tostring(argument))
  end
  -- 用单空格连接：每个元素已各自成词，空格不会再被 shell 当作参数分隔切错
  return table.concat(escaped, ' ')
end

return M
