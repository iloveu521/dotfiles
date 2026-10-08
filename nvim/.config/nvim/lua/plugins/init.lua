--[[
lua/plugins/init.lua — 插件 spec 汇总入口

职责：把 lua/plugins/ 下按功能拆分的各个 spec 模块聚合成一个列表，整体交给
lazy.nvim 安装与调度；本文件自身不声明任何插件，只负责把清单凑齐。

加载时机：core/lazy.lua 里的 require('lazy').setup(require('plugins'), ...) 在
Neovim 启动阶段同步执行，所以这里的 require 属于启动路径——各模块必须保持轻量，
只在顶层构造并返回 spec 表，不做 setup 调用。

在整体配置中的地位：init.lua -> core.lazy -> plugins/init.lua -> 各 spec 模块。
每个插件究竟何时加载，由条目自己的 event / cmd / keys / lazy 决定。
]]

-- 汇总容器：所有模块返回的 spec 依次并入，最后整体交给 lazy.nvim。
local specs = {}

-- 遍历顺序不影响加载顺序（调度看各条目的 event/cmd/keys/lazy），
-- 这里按“界面 -> 检索与编辑 -> 语言相关 -> 工具”的阅读顺序排列，便于定位文件。
for _, module in ipairs({
  'plugins.ui',  -- 界面：主题、状态栏、标签栏、通知、which-key
  'plugins.navigation',  -- 检索与侧栏：Telescope、neo-tree、aerial
  'plugins.editing',  -- 编辑增强：gitsigns、自动配对、TODO 检索、会话管理
  'plugins.treesitter',  -- 语法解析：treesitter 解析器与高亮
  'plugins.guides',  -- 视觉引导：代码块框线、缩进线、彩虹括号
  'plugins.completion',  -- 补全引擎与代码片段
  'plugins.lsp',  -- 语言服务器接入与诊断
  'plugins.format',  -- 保存时格式化
  'plugins.terminal',  -- 内置终端封装
  'plugins.cmake',  -- CMake 工程配置与构建集成
  'plugins.ros',  -- ROS 功能包/工作空间集成
  'plugins.debug',  -- 调试器前端
}) do
  -- require 会执行该模块并取回它的 spec 列表，追加到 specs 末尾；
  -- 模块顶层只做表构造，因此这一步没有副作用。
  vim.list_extend(specs, require(module))
end

-- lazy.nvim 接收的最终 spec 列表。
return specs
