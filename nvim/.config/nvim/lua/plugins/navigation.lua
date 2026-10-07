local function project_picker(name, extra)
  return function()
    local opts = vim.tbl_extend('force', { cwd = require('core.project').current().root }, extra or {})
    require('telescope.builtin')[name](opts)
  end
end

return {
  { 'nvim-lua/plenary.nvim', lazy = true },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
    cond = function() return vim.fn.executable('make') == 1 end,
  },
  {
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-fzf-native.nvim' },
    keys = {
      { '<leader>ff', project_picker('find_files', { hidden = true }), desc = 'Find project files' },
      { '<leader>fg', project_picker('live_grep'), desc = 'Grep project' },
      { '<leader>fr', project_picker('oldfiles', { only_cwd = true }), desc = 'Recent project files' },
      { '<leader>fb', '<Cmd>Telescope buffers sort_mru=true ignore_current_buffer=true<CR>', desc = 'Find buffers' },
      { '<leader>fh', '<Cmd>Telescope help_tags<CR>', desc = 'Help tags' },
      { '<leader>fc', '<Cmd>Telescope commands<CR>', desc = 'Commands' },
      { '<leader>bb', '<Cmd>Telescope buffers sort_mru=true ignore_current_buffer=true<CR>', desc = 'Switch buffer' },
    },
    opts = {
      defaults = {
        border = true,
        layout_strategy = 'horizontal',
        sorting_strategy = 'ascending',
        layout_config = { prompt_position = 'top', width = 0.9, height = 0.85 },
      },
      extensions = { fzf = { fuzzy = true, override_generic_sorter = true, override_file_sorter = true } },
    },
    config = function(_, opts)
      local telescope = require('telescope')
      telescope.setup(opts)
      pcall(telescope.load_extension, 'fzf')
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'nvim-tree/nvim-web-devicons' },
    keys = { { '<leader>e', '<Cmd>Neotree toggle reveal left<CR>', desc = 'File explorer' } },
    opts = {
      close_if_last_window = true,
      popup_border_style = 'rounded',
      filesystem = { follow_current_file = { enabled = true }, use_libuv_file_watcher = true },
      window = { width = 34 },
    },
  },
  {
    'stevearc/aerial.nvim',
    cmd = { 'AerialToggle', 'AerialNavToggle' },
    keys = { { '<leader>cs', '<Cmd>AerialToggle! right<CR>', desc = 'Symbol outline' } },
    opts = { backends = { 'lsp', 'treesitter', 'markdown', 'man' }, layout = { min_width = 28 } },
  },
}
