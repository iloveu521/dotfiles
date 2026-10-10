local config_root = assert(os.getenv('NVIM_CONFIG_UNDER_TEST'), 'NVIM_CONFIG_UNDER_TEST is required')
package.path = table.concat({
  config_root .. '/lua/?.lua',
  config_root .. '/lua/?/init.lua',
  package.path,
}, ';')

local function find_spec(specs, name)
  for _, spec in ipairs(specs) do
    if spec[1] == name then return spec end
  end
  error('missing plugin spec: ' .. name)
end

local function contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then return true end
  end
  return false
end

-- Core options expose the requested editing behavior to a real Neovim instance.
require('core.options').setup()
assert(vim.o.breakindent, 'breakindent must be enabled')
assert(vim.o.timeoutlen == 300, 'multi-key timeout must be 300ms')
assert(not vim.o.backup, 'backup files must be disabled')
assert(not vim.o.writebackup, 'write backup files must be disabled')
assert(not vim.o.swapfile, 'swap files must be disabled')

-- Terminal windows should open as an equal-width vertical split by default.
local terminal_specs = require('plugins.terminal')
local toggleterm = find_spec(terminal_specs, 'akinsho/toggleterm.nvim')
assert(toggleterm.opts.direction == 'vertical', 'terminals must open in vertical splits')
assert(type(toggleterm.opts.size) == 'function', 'terminal width must be calculated dynamically')
assert(toggleterm.opts.size() == math.floor(vim.o.columns / 2), 'terminal width must default to half the editor width')

-- Deleting one character with x must leave the unnamed register untouched.
require('core.keymaps').setup()
local x_mapping = vim.fn.maparg('x', 'n', false, true)
assert(x_mapping.rhs == '"_x', 'normal-mode x must delete into the black-hole register')
local alt_backspace_mapping = vim.fn.maparg('<M-BS>', 'i', false, true)
assert(alt_backspace_mapping.rhs == '<Del>', 'Alt+Backspace must act as Delete in insert mode')

-- ROS setup discovery must follow the installed Ubuntu/ROS pair instead of a hard-coded distro.
local repo_root = vim.fn.fnamemodify(config_root, ':h:h:h')
local old_ros_root = vim.env.ROS_ROOT
local old_ros_distro = vim.env.ROS_DISTRO
vim.env.ROS_ROOT = repo_root .. '/tests/fixtures/ros/ros'
vim.env.ROS_DISTRO = 'jazzy'
local ros_scripts = require('core.ros').environment_scripts({ kind = 'ros_workspace', root = '/tmp/no-overlay' })
assert(ros_scripts[1] == vim.env.ROS_ROOT .. '/humble/setup.zsh', 'ROS setup must discover the installed Humble distro')
vim.env.ROS_ROOT = old_ros_root
vim.env.ROS_DISTRO = old_ros_distro

-- Diagnostic setup keeps underlines while adding the requested presentation.
vim.diagnostic.config({ underline = true })
require('core.snippets').setup()
local diagnostics = vim.diagnostic.config()
assert(diagnostics.underline == true, 'diagnostic underlines must remain enabled')
assert(diagnostics.update_in_insert == true, 'diagnostics must update in insert mode')
assert(diagnostics.float.source == true, 'diagnostic floats must show their source')
assert(diagnostics.virtual_text.prefix == '●', 'virtual diagnostics must use a dot prefix')
assert(
  diagnostics.virtual_text.format({ code = 'E42', message = 'failure' }) == '[E42] failure',
  'virtual diagnostics must include diagnostic codes'
)
assert(vim.hl.priorities.semantic_tokens == 95, 'semantic tokens must stay below treesitter priority')
assert(diagnostics.signs.text[vim.diagnostic.severity.ERROR] == ' ', 'error sign must be configured')
assert(diagnostics.signs.text[vim.diagnostic.severity.WARN] == ' ', 'warning sign must be configured')
assert(diagnostics.signs.text[vim.diagnostic.severity.INFO] == ' ', 'info sign must be configured')
assert(diagnostics.signs.text[vim.diagnostic.severity.HINT] == '󰌵 ', 'hint sign must be configured')

-- The statusline remains useful on wide screens and collapses noisy components on narrow ones.
local ui_specs = require('plugins.ui')
local lualine = find_spec(ui_specs, 'nvim-lualine/lualine.nvim')
assert(lualine.opts.options.section_separators.left == '', 'lualine left section separator must be styled')
assert(lualine.opts.options.component_separators.left == '', 'lualine component separator must be styled')
assert(contains(lualine.opts.options.disabled_filetypes, 'neo-tree'), 'lualine must stay hidden in neo-tree')
local mode = lualine.opts.sections.lualine_a[1]
assert(type(mode) == 'table' and type(mode.fmt) == 'function', 'mode component must be responsive')
local expected_mode = vim.fn.winwidth(0) > 100 and ' NORMAL' or ' N'
assert(mode.fmt('NORMAL') == expected_mode, 'statusline mode must respond to the current window width')

-- Telescope's UI selector and Neo-tree's visual hierarchy are represented in their real lazy specs.
local navigation_specs = require('plugins.navigation')
local telescope = find_spec(navigation_specs, 'nvim-telescope/telescope.nvim')
assert(
  contains(telescope.dependencies, 'nvim-telescope/telescope-ui-select.nvim'),
  'telescope-ui-select must be installed as a dependency'
)
assert(telescope.opts.extensions['ui-select'] ~= nil, 'the Telescope UI selector must be configured')
local neo_tree = find_spec(navigation_specs, 'nvim-neo-tree/neo-tree.nvim')
local components = neo_tree.opts.default_component_configs
assert(components.indent.with_markers == true, 'Neo-tree must render indent markers')
assert(components.indent.indent_marker == '│', 'Neo-tree indent marker must be a vertical guide')
assert(components.indent.last_indent_marker == '└', 'Neo-tree last indent marker must be a corner')
assert(components.git_status.symbols.conflict == '', 'Neo-tree must render Git conflict icons')
local filtered = neo_tree.opts.filesystem.filtered_items
assert(filtered.hide_dotfiles == false, 'Neo-tree must show dotfiles and dot-directories')
assert(filtered.hide_gitignored == false, 'Neo-tree must show Git-ignored files')
assert(filtered.hide_hidden == false, 'Neo-tree must show OS-hidden files')
local tree_mappings = neo_tree.opts.window.mappings
assert(tree_mappings['<cr>'] == 'open', 'Enter must open files from Neo-tree')
assert(tree_mappings.a[1] == 'add', 'a must create files from Neo-tree')
assert(tree_mappings.A == 'add_directory', 'A must create directories from Neo-tree')
assert(tree_mappings.r == 'rename', 'r must rename items from Neo-tree')
assert(tree_mappings.d == 'delete', 'd must delete items from Neo-tree')

print('nvim config tests passed')
