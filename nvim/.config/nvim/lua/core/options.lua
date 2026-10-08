--[[
lua/core/options.lua — 全局编辑器选项

用途：集中设置 Neovim 的内置选项（相当于传统 vimrc 里的 set 系列），完全不涉及插件。
加载时机：由 init.lua 的 require('core.options').setup() 调用，是最先执行的用户模块。
地位：属于 core 基础层；keymaps、autocmds 以及所有插件都假定这里的选项已经生效。
]]

local M = {}

-- 注册本模块的设置入口；无参数、无返回值，副作用是修改一批全局选项。
function M.setup()
  -- 空格键作为全局 <leader>，后续所有 <leader> 开头的映射都以它为准。
  vim.g.mapleader = ' '
  -- 缓冲区局部 <leader> 也用空格，避免 filetype 插件里出现两套前缀。
  vim.g.maplocalleader = ' '

  -- 起别名，之后每行都用 opt.xxx = yyy 的写法，比 vim.o / vim.bo 更直观。
  local opt = vim.opt
  -- 外观与显示：行号、鼠标、剪贴板、撤销持久化。
  opt.number = true          -- 左侧显示当前行的绝对行号
  opt.relativenumber = true  -- 其余行显示相对当前行的距离，便于 5j / d3k 这类带计数跳转
  opt.mouse = 'a'            -- 所有模式都启用鼠标：点击定位、拖拽选择、滚轮滚动
  opt.clipboard = 'unnamedplus' -- 默认寄存器接管系统剪贴板，y/p 与外部程序直接互通
  opt.undofile = true        -- 撤销历史写到磁盘，重新打开文件后仍可用 u 回退
  -- 搜索行为：默认忽略大小写，但输入大写字母时改为精确匹配。
  opt.ignorecase = true      -- 搜索不加区分大小写
  opt.smartcase = true       -- 一旦出现大写字符就区分大小写，覆盖上一条
  -- 界面响应与布局：符号列、刷新频率、映射等待、分屏方向、颜色与光标行。
  opt.signcolumn = 'yes'     -- 始终预留符号列，诊断/断点图标出现时整屏不会左右抖动
  opt.updatetime = 250       -- 空闲 250ms 就触发 CursorHold，诊断浮窗和 git 标记更及时
  opt.timeoutlen = 400       -- 多键映射的等待上限，400ms 兼顾手感与 which-key 弹窗
  opt.splitright = true      -- :vsplit 新窗口开在右侧，符合从左到右的阅读顺序
  opt.splitbelow = true      -- :split 新窗口开在下方
  opt.termguicolors = true   -- 启用 24 位真彩色，主题才能按 hex 值精确渲染
  opt.cursorline = true      -- 高亮光标所在的整行，方便快速定位
  opt.scrolloff = 8          -- 光标距上下边缘不足 8 行就开始滚动，始终能看到上下文
  opt.sidescrolloff = 8      -- 水平方向同样保留 8 列，nowrap 长行左右移动时不贴边
  -- 缩进与制表符：全局默认给 Lua/JS 这类两空格语言，C/C++ 由 autocmds 单独覆盖。
  opt.expandtab = true       -- 按 Tab 插入空格而不是真正的制表符
  opt.shiftwidth = 2         -- 自动缩进以及 >> << 每级为 2 个空格
  opt.tabstop = 2            -- 屏幕上把一个制表符按 2 列宽度显示
  opt.softtabstop = 2        -- 插入模式下按 Tab 等价于 2 个空格
  opt.smartindent = true     -- 新行按语法自动增加缩进，删掉行首缩进时也会退回
  -- 折行与补全：长行不折行，补全菜单始终显示且不预选。
  opt.wrap = false           -- 不折行显示，超出窗口宽度的部分靠水平滚动查看
  opt.completeopt = { 'menu', 'menuone', 'noselect' } -- 补全菜单：总弹出、单个候选也弹出、不预选以免回车误插入
end

return M
