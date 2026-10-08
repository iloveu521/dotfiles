--[[
lua/core/format.lua — 「保存时格式化」的 buffer 级开关
由 lua/plugins/format.lua 使用两处：conform.nvim 的 format_on_save 回调
判断是否跳过，以及 <leader>uf 快捷键切换开关。
定位：只维护状态、不做格式化，也不 require 任何插件，属于被插件层依赖的
core 工具；默认所有 buffer 都开启保存时格式化，只有被显式关闭的才跳过。
状态存在 buffer 局部变量 b:format_on_save_disabled 中，因此开关跟随 buffer，
某个文件关掉后不影响其他文件，buffer 被删除时状态也随之释放。
]]
local M = {} -- 模块表

-- 使用的 b: 变量名。名为 disabled 而非 enabled，是为了让「变量不存在」天然表示默认开启
local variable = 'format_on_save_disabled'

-- 把「0 表示当前 buffer」的调用约定统一成一个确定的 buffer 号。
-- bufnr: buffer 号；nil 或 0 都表示当前 buffer。
-- 返回: 具体的 buffer 号。
local function buffer(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then return vim.api.nvim_get_current_buf() end
  return bufnr
end

-- 查询某 buffer 是否启用保存时格式化。
-- bufnr: buffer 号，省略或 0 表示当前 buffer。
-- 返回: true 表示启用（默认），false 表示该 buffer 已被关闭。
-- 注意判据是 ~= true：变量为 nil 或 false 都算启用，只有显式 true 才算关闭。
function M.is_enabled(bufnr)
  return vim.b[buffer(bufnr)][variable] ~= true
end

-- 关闭指定 buffer 的保存时格式化。
-- bufnr: buffer 号，省略或 0 表示当前 buffer。
-- 副作用: 写入 b:format_on_save_disabled = true。
function M.disable(bufnr)
  vim.b[buffer(bufnr)][variable] = true
end

-- 重新开启指定 buffer 的保存时格式化。
-- bufnr: buffer 号，省略或 0 表示当前 buffer。
-- 副作用: 写入 b:format_on_save_disabled = false（写 false 而不是删除变量，语义同样为启用）。
function M.enable(bufnr)
  vim.b[buffer(bufnr)][variable] = false
end

-- 反转开关状态，供 <leader>uf 使用。
-- bufnr: buffer 号，省略或 0 表示当前 buffer。
-- 返回: 切换之后的启用状态（true 表示现在会保存时格式化），调用方据此提示用户。
-- 副作用: 视情况写入 b:format_on_save_disabled。
function M.toggle(bufnr)
  bufnr = buffer(bufnr)
  if M.is_enabled(bufnr) then M.disable(bufnr) else M.enable(bufnr) end
  return M.is_enabled(bufnr)
end

return M
