return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    keys = {
      { '<leader>gp', '<Cmd>Gitsigns preview_hunk<CR>', desc = 'Preview Git hunk' },
      { '<leader>gs', '<Cmd>Gitsigns stage_hunk<CR>', desc = 'Stage Git hunk', mode = { 'n', 'v' } },
      { '<leader>gr', '<Cmd>Gitsigns reset_hunk<CR>', desc = 'Reset Git hunk', mode = { 'n', 'v' } },
      { '<leader>gb', '<Cmd>Gitsigns blame_line<CR>', desc = 'Blame line' },
    },
    opts = { signs = { add = { text = '▎' }, change = { text = '▎' }, delete = { text = '' } } },
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = { check_ts = true, fast_wrap = {} },
  },
  {
    'folke/todo-comments.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-lua/plenary.nvim' },
    keys = { { '<leader>ft', '<Cmd>TodoTelescope<CR>', desc = 'Find TODO comments' } },
    opts = { signs = true },
  },
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = { dir = vim.fn.stdpath('state') .. '/sessions/' },
    keys = {
      { '<leader>qs', function() require('persistence').load() end, desc = 'Restore session' },
      { '<leader>ql', function() require('persistence').load({ last = true }) end, desc = 'Restore last session' },
      { '<leader>qd', function() require('persistence').stop() end, desc = 'Do not save session' },
      { '<leader>bd', '<Cmd>bdelete<CR>', desc = 'Delete buffer' },
    },
  },
}
