local M = {}

local base_command = {
  'clangd',
  '--background-index',
  '--clang-tidy',
  '--completion-style=detailed',
  '--header-insertion=iwyu',
  '--function-arg-placeholders',
}

function M.command(context, source_path)
  local command = vim.deepcopy(base_command)
  local database = require('core.project').find_compile_commands(context, source_path)
  if database then
    table.insert(command, '--compile-commands-dir=' .. vim.fs.dirname(database))
  end
  return command
end

return M
