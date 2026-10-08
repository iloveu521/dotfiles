--[[
  plugins/treesitter.lua — 语法解析、高亮与缩进（nvim-treesitter，main 分支）

  作用：
    1) 安装并维护 treesitter 语法解析器（parser）；
    2) 打开受支持的文件类型时启用 treesitter 语法高亮；
    3) 用 treesitter 的缩进表达式替换 Vim 原生缩进（C++ 除外，见文件末尾说明）。

  加载时机：lazy = false，Neovim 启动时立即加载（高亮属于基础体验，不能等事件触发）。
  解析器需要用 C 编译器构建，构建与更新由 build 字段里的 :TSUpdate 触发。
]]

-- 启动时要确保安装的解析器列表，覆盖本仓库常用的语言：
--   c / cpp                     —— C 与 C++（ROS、CMake 工程主体）
--   cmake                       —— CMakeLists.txt
--   lua                         —— 本配置自身
--   bash                        —— shell 脚本
--   json / yaml                 —— 配置与参数文件
--   markdown / markdown_inline  —— 文档及其行内代码
--   vim / vimdoc                —— vimscript 与 :help 文档
local parsers = { 'c', 'cpp', 'cmake', 'lua', 'bash', 'json', 'yaml', 'markdown', 'markdown_inline', 'vim', 'vimdoc' }

return {
  {
    'nvim-treesitter/nvim-treesitter',
    -- main 是重写后的新分支：不再有旧版的 ensure_installed/highlight 一体化接口，
    -- 改为 setup() + install() 初始化，再逐个缓冲区手动 vim.treesitter.start()（见 config）。
    branch = 'main',
    -- 语法高亮是编辑的基础能力，设为 false 让它随启动立即加载。
    lazy = false,
    -- 插件更新（:Lazy update）后自动重新编译解析器，避免版本不匹配导致高亮失效。
    build = ':TSUpdate',
    opts = {
      -- 解析器统一装到 stdpath('data')/site，与 lazy.nvim 的插件目录分开，便于清理重建。
      install_dir = vim.fn.stdpath('data') .. '/site',
      -- 供下面 config 中的 treesitter.install() 使用（缺失的才会真正下载/编译）。
      ensure_installed = parsers,
    },
    config = function(_, opts)
      local treesitter = require('nvim-treesitter')
      -- 新分支的 setup 只做「目录与解析器管理」的初始化，不会自动开启高亮。
      treesitter.setup({ install_dir = opts.install_dir })
      -- 安装缺失的解析器；已安装的会直接跳过，因此每次启动调用是幂等的。
      treesitter.install(opts.ensure_installed)

      -- 按文件类型启用 treesitter：启动解析、高亮，并接管缩进。
      vim.api.nvim_create_autocmd('FileType', {
        -- 注意这里是 filetype 名而不是解析器名：shell 脚本的 filetype 是 sh，对应上面的 bash 解析器。
        pattern = { 'c', 'cpp', 'cmake', 'lua', 'sh', 'json', 'yaml', 'markdown', 'vim', 'vimdoc' },
        callback = function(event)
          -- 解析器缺失或启动失败时静默跳过，自动回退到正则高亮，不影响正常编辑。
          if not pcall(vim.treesitter.start, event.buf) then return end
          -- C++ 例外：保留 Vim/文件类型自带（含 Google 风格 4 空格，见 core/autocmds.lua）的缩进表达式；
          -- 其余文件类型改用 treesitter 缩进，对 CMake、Lua 等嵌套结构更准确。
          if vim.bo[event.buf].filetype ~= 'cpp' then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
