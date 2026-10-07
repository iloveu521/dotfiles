local M = {}

function M.shell_join(argv)
  assert(type(argv) == 'table', 'argv must be a table')
  local escaped = {}
  for index, argument in ipairs(argv) do
    escaped[index] = vim.fn.shellescape(tostring(argument))
  end
  return table.concat(escaped, ' ')
end

return M
