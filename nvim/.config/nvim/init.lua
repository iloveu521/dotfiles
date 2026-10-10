--[[
init.lua — Neovim 配置总入口

用途：这是 Neovim 启动时加载的第一个用户配置文件（位于 stdpath('config') 根目录）。
加载时机：内置初始化完成后、任何插件加载之前，按从上到下的顺序同步执行。
地位：文件本身不做任何设置，只按依赖顺序调用 lua/core/ 下的各模块；
      options 必须最先执行（leader、缩进等全局选项要在其他模块用到之前就位），
      lazy 放在最后（它是插件管理器的引导层，需要前序模块提供的基础设置已经生效）。
]]

-- 全局选项：行号、缩进、搜索、剪贴板等，最先执行，后续模块都假定它们已生效。
require('core.options').setup()
-- 自动命令：按文件类型覆盖缩进、复制后高亮等事件驱动行为。
require('core.autocmds').setup()
-- 诊断显示：语义高亮优先级、虚拟文本、符号与透明背景。
require('core.snippets').setup()
-- 快捷键：normal/insert/visual/terminal 全部映射集中注册，依赖 options 中设好的 leader。
require('core.keymaps').setup()
-- 项目管理：项目与会话相关的辅助命令和切换逻辑。
require('core.project').setup()
-- 内置终端：打开方式、窗口尺寸与模式切换的封装。
require('core.terminal').setup()
-- 插件管理器 lazy.nvim：自举安装并加载 lua/plugins 下的插件清单，故置于最后。
require('core.lazy').setup()
