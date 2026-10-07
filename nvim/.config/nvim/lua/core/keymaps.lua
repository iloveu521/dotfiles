local M = {}

function M.setup()
  local map = vim.keymap.set
  local silent = { silent = true }

  map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Move down by display line' })
  map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Move up by display line' })
  map('n', '<Esc>', '<Cmd>nohlsearch<CR>', { silent = true, desc = 'Clear search highlight' })
  map('n', '<C-s>', '<Cmd>write<CR>', { silent = true, desc = 'Save file' })

  -- VS Code-style Alt navigation. Keep native Vim motions available while
  -- providing the same spatial layer in every interactive mode.
  map('n', '<M-i>', 'gk', { silent = true, desc = 'Move up' })
  map('n', '<M-k>', 'gj', { silent = true, desc = 'Move down' })
  map('n', '<M-j>', 'h', { silent = true, desc = 'Move left' })
  map('n', '<M-l>', 'l', { silent = true, desc = 'Move right' })
  map('i', '<M-i>', '<Up>', { desc = 'Move up' })
  map('i', '<M-k>', '<Down>', { desc = 'Move down' })
  map('i', '<M-j>', '<Left>', { desc = 'Move left' })
  map('i', '<M-l>', '<Right>', { desc = 'Move right' })
  map('v', '<M-i>', 'gk', { silent = true, desc = 'Extend selection up' })
  map('v', '<M-k>', 'gj', { silent = true, desc = 'Extend selection down' })
  map('v', '<M-j>', 'h', { silent = true, desc = 'Extend selection left' })
  map('v', '<M-l>', 'l', { silent = true, desc = 'Extend selection right' })
  map('t', '<M-i>', '<Up>', { desc = 'Terminal history up' })
  map('t', '<M-k>', '<Down>', { desc = 'Terminal history down' })
  map('t', '<M-j>', '<Left>', { desc = 'Terminal cursor left' })
  map('t', '<M-l>', '<Right>', { desc = 'Terminal cursor right' })

  map({ 'n', 'v' }, '<M-u>', '^', { silent = true, desc = 'Move to line start' })
  map({ 'n', 'v' }, '<M-o>', '$', { silent = true, desc = 'Move to line end' })
  map('i', '<M-u>', '<Home>', { desc = 'Move to line start' })
  map('i', '<M-o>', '<End>', { desc = 'Move to line end' })
  map('t', '<M-u>', '<Home>', { desc = 'Terminal line start' })
  map('t', '<M-o>', '<End>', { desc = 'Terminal line end' })
  map({ 'n', 'v' }, '<M-J>', 'b', { silent = true, desc = 'Move one word left' })
  map({ 'n', 'v' }, '<M-L>', 'w', { silent = true, desc = 'Move one word right' })
  map('i', '<M-J>', '<C-Left>', { desc = 'Move one word left' })
  map('i', '<M-L>', '<C-Right>', { desc = 'Move one word right' })
  map('n', '<M-b>', '<C-o>', { silent = true, desc = 'Navigate back' })
  map('n', '<M-a>', 'dd', { silent = true, desc = 'Delete line' })
  map('i', '<M-a>', '<Esc>ddi', { silent = true, desc = 'Delete line' })

  -- Split navigation also applies to Neo-tree and to terminal-backed panes.
  for lhs, direction in pairs({ ['<C-h>'] = 'h', ['<C-j>'] = 'j', ['<C-k>'] = 'k', ['<C-l>'] = 'l' }) do
    map('n', lhs, '<C-w>' .. direction, { silent = true, desc = 'Focus window ' .. direction })
    map('t', lhs, '<C-\\><C-n><C-w>' .. direction, { silent = true, desc = 'Focus window ' .. direction })
  end

  map('n', '<C-d>', '<C-d>zz', silent)
  map('n', '<C-u>', '<C-u>zz', silent)
  map('n', 'n', 'nzzzv', silent)
  map('n', 'N', 'Nzzzv', silent)

  map('n', '<Up>', '<Cmd>resize -2<CR>', { silent = true, desc = 'Decrease window height' })
  map('n', '<Down>', '<Cmd>resize +2<CR>', { silent = true, desc = 'Increase window height' })
  map('n', '<Left>', '<Cmd>vertical resize -2<CR>', { silent = true, desc = 'Decrease window width' })
  map('n', '<Right>', '<Cmd>vertical resize +2<CR>', { silent = true, desc = 'Increase window width' })

  map('i', 'jk', '<Esc>', { silent = true, desc = 'Leave insert mode' })
  map('v', '<', '<gv', { silent = true, desc = 'Indent left and retain selection' })
  map('v', '>', '>gv', { silent = true, desc = 'Indent right and retain selection' })
  map('v', 'p', '"_dP', { silent = true, desc = 'Paste without replacing yank register' })

  map({ 'n', 'v' }, '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
  map('n', '<leader>Y', '"+Y', { desc = 'Yank line to system clipboard' })
  map('n', '<leader>uw', '<Cmd>set wrap!<CR>', { silent = true, desc = 'Toggle line wrap' })

  map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = 'Previous diagnostic' })
  map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = 'Next diagnostic' })
  map('n', 'gl', vim.diagnostic.open_float, { desc = 'Line diagnostics' })

  -- Buffers
  map('n', '<C-n>', '<Cmd>enew<CR>', { silent = true, desc = 'New buffer' })
  map('n', '[b', '<Cmd>bprevious<CR>', { silent = true, desc = 'Previous buffer' })
  map('n', ']b', '<Cmd>bnext<CR>', { silent = true, desc = 'Next buffer' })

  -- Increment/decrement numbers
  map('n', '<leader>+', '<C-a>', { desc = 'Increment number' })
  map('n', '<leader>-', '<C-x>', { desc = 'Decrement number' })

  -- Window management
  map('n', '<leader>v', '<C-w>v', { desc = 'Split window vertically' })
  map('n', '<leader>h', '<C-w>s', { desc = 'Split window horizontally' })
  map('n', '<leader>se', '<C-w>=', { desc = 'Equalize split sizes' })
  map('n', '<leader>xs', '<Cmd>close<CR>', { desc = 'Close split' })

  -- Tabs
  map('n', '<leader>to', '<Cmd>tabnew<CR>', { desc = 'New tab' })
  map('n', '<leader>tx', '<Cmd>tabclose<CR>', { desc = 'Close tab' })
  map('n', '<leader>tn', '<Cmd>tabnext<CR>', { desc = 'Next tab' })
  map('n', '<leader>tp', '<Cmd>tabprevious<CR>', { desc = 'Previous tab' })
end

return M
