local M = {}
local variable = 'format_on_save_disabled'

local function buffer(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then return vim.api.nvim_get_current_buf() end
  return bufnr
end

function M.is_enabled(bufnr)
  return vim.b[buffer(bufnr)][variable] ~= true
end

function M.disable(bufnr)
  vim.b[buffer(bufnr)][variable] = true
end

function M.enable(bufnr)
  vim.b[buffer(bufnr)][variable] = false
end

function M.toggle(bufnr)
  bufnr = buffer(bufnr)
  if M.is_enabled(bufnr) then M.disable(bufnr) else M.enable(bufnr) end
  return M.is_enabled(bufnr)
end

return M
