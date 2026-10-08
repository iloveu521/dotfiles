--[[
lua/core/keymaps.lua — 全局快捷键

用途：集中注册与插件无关的按键映射，覆盖 normal / insert / visual / terminal 四种模式。
加载时机：由 init.lua 调用 require('core.keymaps').setup()，此时 options 已设好 <leader>。
地位：属于 core 基础层；插件自带的按键（文件树、模糊查找等）由各自插件 spec 的 keys 字段声明。
]]

local M = {}

-- 注册全部映射；无参数、无返回值，副作用是改写各模式的全局键位表。
function M.setup()
  -- 简化后续快捷键定义，并复用“静默执行”选项。
  local map = vim.keymap.set
  local silent = { silent = true }

  -- 基础操作：按屏幕显示行移动、清除搜索高亮，以及保存文件。
  -- j：normal 模式；无计数时走 gj（按显示行下移，长折行不会一次跨过整段），带计数时保持原生 j。
  map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Move down by display line' })
  -- k：normal 模式；与 j 对称，无计数按显示行上移，带计数时按真实行上移。
  map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Move up by display line' })
  -- <Esc>：normal 模式；清掉上一次搜索残留的高亮，免去手动输入 :nohlsearch。
  map('n', '<Esc>', '<Cmd>nohlsearch<CR>', { silent = true, desc = 'Clear search highlight' })
  -- <C-s>：normal 模式；保存当前文件（终端里 Ctrl+S 常被流控占用，需在 shell 中关掉 ixon）。
  map('n', '<C-s>', '<Cmd>write<CR>', { silent = true, desc = 'Save file' })

  -- 类似 VS Code 的 Alt 方向键：I/K/J/L 分别对应上/下/左/右。
  -- 普通、插入、可视和终端模式使用同一套空间方向，原生 Vim 移动键仍然可用。
  -- 下面按模式分成四组，每组四键同义：normal 走 Vim 动作，insert/terminal 发方向键，visual 扩展选区。
  -- <M-i>：normal 模式；光标上移一个显示行（gk）。
  map('n', '<M-i>', 'gk', { silent = true, desc = 'Move up' })
  -- <M-k>：normal 模式；光标下移一个显示行（gj）。
  map('n', '<M-k>', 'gj', { silent = true, desc = 'Move down' })
  -- <M-j>：normal 模式；光标左移一列。
  map('n', '<M-j>', 'h', { silent = true, desc = 'Move left' })
  -- <M-l>：normal 模式；光标右移一列。
  map('n', '<M-l>', 'l', { silent = true, desc = 'Move right' })
  -- <M-i>：insert 模式；发送 <Up>，补全菜单弹出时也可用来上下选候选。
  map('i', '<M-i>', '<Up>', { desc = 'Move up' })
  -- <M-k>：insert 模式；发送 <Down>。
  map('i', '<M-k>', '<Down>', { desc = 'Move down' })
  -- <M-j>：insert 模式；发送 <Left>，输入过程中左移。
  map('i', '<M-j>', '<Left>', { desc = 'Move left' })
  -- <M-l>：insert 模式；发送 <Right>，输入过程中右移。
  map('i', '<M-l>', '<Right>', { desc = 'Move right' })
  -- <M-i>：visual 模式；向上扩展选区一个显示行。
  map('v', '<M-i>', 'gk', { silent = true, desc = 'Extend selection up' })
  -- <M-k>：visual 模式；向下扩展选区一个显示行。
  map('v', '<M-k>', 'gj', { silent = true, desc = 'Extend selection down' })
  -- <M-j>：visual 模式；向左扩展选区一列。
  map('v', '<M-j>', 'h', { silent = true, desc = 'Extend selection left' })
  -- <M-l>：visual 模式；向右扩展选区一列。
  map('v', '<M-l>', 'l', { silent = true, desc = 'Extend selection right' })
  -- <M-i>：terminal 模式；翻出终端命令历史的上一条。
  map('t', '<M-i>', '<Up>', { desc = 'Terminal history up' })
  -- <M-k>：terminal 模式；翻出终端命令历史的下一条。
  map('t', '<M-k>', '<Down>', { desc = 'Terminal history down' })
  -- <M-j>：terminal 模式；终端命令行光标左移，便于修改已输入的命令。
  map('t', '<M-j>', '<Left>', { desc = 'Terminal cursor left' })
  -- <M-l>：terminal 模式；终端命令行光标右移。
  map('t', '<M-l>', '<Right>', { desc = 'Terminal cursor right' })

  -- Alt+U/O 跳到行首/行尾，Alt+Shift+J/L 按单词向左/向右移动。
  -- <M-u>：normal 与 visual 模式；跳到行首第一个非空白字符（^）。
  map({ 'n', 'v' }, '<M-u>', '^', { silent = true, desc = 'Move to line start' })
  -- <M-o>：normal 与 visual 模式；跳到行尾（$），便于直接追加内容。
  map({ 'n', 'v' }, '<M-o>', '$', { silent = true, desc = 'Move to line end' })
  -- <M-u>：insert 模式；发送 <Home> 回到行首。
  map('i', '<M-u>', '<Home>', { desc = 'Move to line start' })
  -- <M-o>：insert 模式；发送 <End> 到行尾。
  map('i', '<M-o>', '<End>', { desc = 'Move to line end' })
  -- <M-u>：terminal 模式；终端命令行光标到行首。
  map('t', '<M-u>', '<Home>', { desc = 'Terminal line start' })
  -- <M-o>：terminal 模式；终端命令行光标到行尾。
  map('t', '<M-o>', '<End>', { desc = 'Terminal line end' })
  -- <M-J>（Shift+j）：normal 与 visual 模式；向左退到上一个单词词首（b）。
  map({ 'n', 'v' }, '<M-J>', 'b', { silent = true, desc = 'Move one word left' })
  -- <M-L>（Shift+l）：normal 与 visual 模式；向右跳到下一个单词词首（w）。
  map({ 'n', 'v' }, '<M-L>', 'w', { silent = true, desc = 'Move one word right' })
  -- <M-J>：insert 模式；发送 <C-Left>，按单词左移。
  map('i', '<M-J>', '<C-Left>', { desc = 'Move one word left' })
  -- <M-L>：insert 模式；发送 <C-Right>，按单词右移。
  map('i', '<M-L>', '<C-Right>', { desc = 'Move one word right' })

  -- Alt+B 返回跳转前的位置；Alt+A 删除当前整行。
  -- <M-b>：normal 模式；等价 <C-o>，沿跳转列表退回上一个位置，跨文件跳转后特别有用。
  map('n', '<M-b>', '<C-o>', { silent = true, desc = 'Navigate back' })
  -- <M-a>：normal 模式；删除光标所在整行。
  map('n', '<M-a>', 'dd', { silent = true, desc = 'Delete line' })
  -- <M-a>：insert 模式；先退出插入模式再删整行，最后回到插入模式继续输入。
  map('i', '<M-a>', '<Esc>ddi', { silent = true, desc = 'Delete line' })

  -- 使用 Ctrl+H/J/K/L 在分屏间切换；同样适用于 Neo-tree 和终端窗口。
  -- 循环为四个方向各注册两条映射：normal 沿用 <C-w> 前缀，terminal 先退出终端输入态再切窗口。
  for lhs, direction in pairs({ ['<C-h>'] = 'h', ['<C-j>'] = 'j', ['<C-k>'] = 'k', ['<C-l>'] = 'l' }) do
    -- normal 模式：把 Ctrl+H/J/K/L 转发成原生的窗口切换命令。
    map('n', lhs, '<C-w>' .. direction, { silent = true, desc = 'Focus window ' .. direction })
    -- terminal 模式：先离开终端输入态，再执行同样的窗口切换，终端里也能自由跳窗。
    map('t', lhs, '<C-\\><C-n><C-w>' .. direction, { silent = true, desc = 'Focus window ' .. direction })
  end

  -- 翻页或查找下一个/上一个匹配项后，将光标重新居中。
  -- <C-d>：normal 模式；向下翻半屏并把光标行居中（zz），避免目标贴在屏幕边缘。
  map('n', '<C-d>', '<C-d>zz', silent)
  -- <C-u>：normal 模式；向上翻半屏后同样居中。
  map('n', '<C-u>', '<C-u>zz', silent)
  -- n：normal 模式；跳到下一个搜索匹配，居中并展开该处的折叠（zzzv）。
  map('n', 'n', 'nzzzv', silent)
  -- N：normal 模式；跳到上一个搜索匹配，同样居中并展开折叠。
  map('n', 'N', 'Nzzzv', silent)

  -- 使用方向键调整当前分屏尺寸，每次改变 2 行或 2 列。
  -- <Up>：normal 模式；高度减 2 行，把空间让给其他水平分屏。
  map('n', '<Up>', '<Cmd>resize -2<CR>', { silent = true, desc = 'Decrease window height' })
  -- <Down>：normal 模式；高度加 2 行。
  map('n', '<Down>', '<Cmd>resize +2<CR>', { silent = true, desc = 'Increase window height' })
  -- <Left>：normal 模式；宽度减 2 列。
  map('n', '<Left>', '<Cmd>vertical resize -2<CR>', { silent = true, desc = 'Decrease window width' })
  -- <Right>：normal 模式；宽度加 2 列。
  map('n', '<Right>', '<Cmd>vertical resize +2<CR>', { silent = true, desc = 'Increase window width' })

  -- 编辑辅助：快速退出插入模式；缩进后保留选择；粘贴时不覆盖复制寄存器。
  -- jk：insert 模式；连按两键退出插入，比伸手按 <Esc> 省力，正常打字节奏几乎不会误触。
  map('i', 'jk', '<Esc>', { silent = true, desc = 'Leave insert mode' })
  -- <：visual 模式；左缩进一级后用 gv 重新选中，可以连续按。
  map('v', '<', '<gv', { silent = true, desc = 'Indent left and retain selection' })
  -- >：visual 模式；右缩进一级后保留选择，同理可连续按。
  map('v', '>', '>gv', { silent = true, desc = 'Indent right and retain selection' })
  -- p：visual 模式；用黑洞寄存器删除选中内容再粘贴，不覆盖 y 寄存器，同一段内容可反复粘贴。
  map('v', 'p', '"_dP', { silent = true, desc = 'Paste without replacing yank register' })

  -- 系统剪贴板与显示设置。
  -- <leader>y：normal 与 visual 模式；把动作结果或选区复制到系统剪贴板（+ 寄存器）。
  map({ 'n', 'v' }, '<leader>y', '"+y', { desc = 'Yank to system clipboard' })
  -- <leader>Y：normal 模式；整行复制到系统剪贴板，方便贴到浏览器或聊天窗口。
  map('n', '<leader>Y', '"+Y', { desc = 'Yank line to system clipboard' })
  -- <leader>uw：normal 模式；反转折行开关，读长文档或日志时临时打开。
  map('n', '<leader>uw', '<Cmd>set wrap!<CR>', { silent = true, desc = 'Toggle line wrap' })

  -- 诊断信息：跳到前后诊断，或显示当前行的浮动诊断窗口。
  -- [d：normal 模式；跳到上一条诊断并把详情显示在浮窗中（float = true）。
  map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = 'Previous diagnostic' })
  -- ]d：normal 模式；跳到下一条诊断并弹出浮窗。
  map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = 'Next diagnostic' })
  -- gl：normal 模式；打开当前行的诊断浮窗，光标位置不变。
  map('n', 'gl', vim.diagnostic.open_float, { desc = 'Line diagnostics' })

  -- 缓冲区：新建缓冲区，以及切换到上一个/下一个缓冲区。
  -- <C-n>：normal 模式；开一个空缓冲区，用来临时记笔记后再决定是否保存。
  map('n', '<C-n>', '<Cmd>enew<CR>', { silent = true, desc = 'New buffer' })
  -- [b：normal 模式；切到缓冲区列表中的上一个。
  map('n', '[b', '<Cmd>bprevious<CR>', { silent = true, desc = 'Previous buffer' })
  -- ]b：normal 模式；切到缓冲区列表中的下一个。
  map('n', ']b', '<Cmd>bnext<CR>', { silent = true, desc = 'Next buffer' })

  -- 数值操作：增加或减少光标所在位置的数字。
  -- <leader>+：normal 模式；光标处数字加一（等价于 <C-a>）。
  map('n', '<leader>+', '<C-a>', { desc = 'Increment number' })
  -- <leader>-：normal 模式；光标处数字减一（等价于 <C-x>）。
  map('n', '<leader>-', '<C-x>', { desc = 'Decrement number' })

  -- 窗口管理：垂直/水平分屏、平均分配尺寸，以及关闭当前分屏。
  -- <leader>v：normal 模式；左右分屏，用于并排对照两份文件。
  map('n', '<leader>v', '<C-w>v', { desc = 'Split window vertically' })
  -- <leader>h：normal 模式；上下分屏。
  map('n', '<leader>h', '<C-w>s', { desc = 'Split window horizontally' })
  -- <leader>se：normal 模式；把所有分屏尺寸调成均等。
  map('n', '<leader>se', '<C-w>=', { desc = 'Equalize split sizes' })
  -- <leader>xs：normal 模式；关闭当前分屏，而不是退出整个 Neovim。
  map('n', '<leader>xs', '<Cmd>close<CR>', { desc = 'Close split' })

  -- 标签页：新建、关闭，以及切换到下一个/上一个标签页。
  -- <leader>to：normal 模式；新建标签页，适合把互不相关的任务彻底隔离开。
  map('n', '<leader>to', '<Cmd>tabnew<CR>', { desc = 'New tab' })
  -- <leader>tx：normal 模式；关闭当前标签页。
  map('n', '<leader>tx', '<Cmd>tabclose<CR>', { desc = 'Close tab' })
  -- <leader>tn：normal 模式；切到下一个标签页。
  map('n', '<leader>tn', '<Cmd>tabnext<CR>', { desc = 'Next tab' })
  -- <leader>tp：normal 模式；切到上一个标签页。
  map('n', '<leader>tp', '<Cmd>tabprevious<CR>', { desc = 'Previous tab' })
end

return M
