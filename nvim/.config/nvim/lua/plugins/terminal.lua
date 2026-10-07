return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    cmd = { 'ToggleTerm', 'TermExec' },
    keys = {
      { '<leader>tt', function() require('core.terminal').general(1) end, desc = 'Terminal 1' },
      { '<leader>t2', function() require('core.terminal').general(2) end, desc = 'Terminal 2' },
      { '<leader>t3', function() require('core.terminal').general(3) end, desc = 'Terminal 3' },
      { [[<C-\>]], function() require('core.terminal').general(1) end, desc = 'Toggle terminal' },
      { '<leader>aa', function() require('core.agents').select() end, desc = 'Select coding agent' },
      { '<leader>al', function() require('core.agents').last() end, desc = 'Reopen last agent' },
      { '<leader>ak', function() require('core.agents').kill() end, desc = 'Kill agent session' },
    },
    opts = {
      size = 14,
      open_mapping = false,
      shade_terminals = false,
      persist_size = true,
      persist_mode = true,
      direction = 'horizontal',
    },
    config = function(_, opts)
      require('toggleterm').setup(opts)
      vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], { desc = 'Leave terminal mode' })
    end,
  },
}
