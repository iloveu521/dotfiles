local specs = {}

for _, module in ipairs({
  'plugins.ui',
  'plugins.navigation',
  'plugins.editing',
  'plugins.treesitter',
  'plugins.guides',
  'plugins.completion',
  'plugins.lsp',
  'plugins.format',
  'plugins.terminal',
  'plugins.cmake',
  'plugins.ros',
  'plugins.debug',
}) do
  vim.list_extend(specs, require(module))
end

return specs
