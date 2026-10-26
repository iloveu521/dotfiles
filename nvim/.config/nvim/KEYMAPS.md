# Neovim 快捷键索引

空格是 `<leader>`。按键定义仍保留在对应插件配置中，方便 lazy.nvim 按需加载；本页提供统一索引。

## Leader 分组

| 前缀 | 功能 | 常用映射 |
| --- | --- | --- |
| `<leader>a` | 编码助手 | `aa` 选择，`al` 恢复上次会话，`ak` 结束会话 |
| `<leader>b` | 缓冲区 | `bb` 切换，`bd` 关闭当前，`bo` 关闭其他，`bp` 选择关闭，`bv` 选择跳转 |
| `<leader>c` | 代码 | `ca` 代码操作，`cr` 重命名，`cs` 符号大纲 |
| `<leader>d` | 调试 | `db` 断点，`da` 附加进程，`dl` 启动，`du` 关闭面板 |
| `<leader>f` | 查找 | `ff` 文件，`fg` 全文，`fr` 最近文件，`fh` 帮助，`fc` 命令，`ft` TODO |
| `<leader>g` | Git | `gp` 预览，`gs` 暂存，`gr` 撤销，`gb` blame |
| `<leader>m` | CMake 工程 | `mc` 配置，`mb` 构建，`mr` 运行，`mt` 选择目标 |
| `<leader>q` | 会话 | `qs` 恢复当前工程，`ql` 恢复上次会话，`qd` 停止保存 |
| `<leader>r` | ROS 工程 | `rb` 构建，`rt` 测试，`rs` 环境 shell，`rc` 刷新编译数据库，`rr` 运行 |
| `<leader>t` | 终端和标签页 | `tt`/`t2`/`t3` 终端，`th`/`tv` 分屏终端，`to`/`tx`/`tn`/`tp` 标签页 |
| `<leader>u` | 显示切换 | `uf` 自动格式化，`uw` 折行 |

其他全局操作：`yy` 复制当前行到系统剪贴板，`dd` 删除当前行；`<leader>y` 复制动作结果或选区到系统剪贴板；`<leader>+`/`-` 增减数字；`<leader>v`/`h` 分屏，`<leader>se` 平均窗口，`<leader>xs` 关闭当前分屏。

## Neovim 与 VSCode Vim 共用的编辑键

| 按键 | 功能 | 模式/范围 |
| --- | --- | --- |
| `Alt+U`/`Alt+O` | 行首/行尾 | 编辑器中 |
| `Alt+Shift+J`/`Alt+Shift+L` | 按单词向左/向右移动 | 编辑器中 |
| `yy`/`dd` | 复制/删除当前行 | 普通模式；`yy` 使用系统剪贴板 |
| `Alt+F` | 格式化当前文件 | 编辑器中 |
| `Alt+R` | 将光标下的完整单词替换为新词，逐处确认 | 当前文件；区分大小写且要求单词边界 |
| `gd`/`gD`/`gr` | 跳到定义/声明/引用 | LSP 缓冲区/VSCode Vim 普通模式 |
| `Alt+S` | 预览定义 | 编辑器中 |
| `Alt+B`/`Alt+A` | 跳转历史后退/前进 | 普通模式 |
| `Alt+P` | 为当前单词的匹配项添加多光标 | 两边选择当前文件中的全部匹配 |
| `<S-CR>`/`<C-S-CR>` | 在下方/上方新开一行 | 插入模式 |
| `<C-d>`/`<C-u>` | 下/上翻半屏（Neovim 另将光标居中） | 普通模式 |

## 常用非 Leader 映射

| 按键 | 功能 |
| --- | --- |
| `j`/`k` | 按屏幕显示行移动；带计数时按真实行移动 |
| `<C-h>`/`<C-j>`/`<C-k>`/`<C-l>` | 切换分屏焦点 |
| `gg` | 跳到第一行第 1 列 |
| `<C-d>`/`<C-u>` | 下/上翻半屏并居中 |
| `n`/`N` | 下/上一个搜索结果并居中 |
| `K` | LSP 悬浮文档 |
| `[d`/`]d`/`gl` | 上一条/下一条诊断、当前行诊断 |
| `jk`（插入模式） | 退出插入模式 |
| `<S-CR>`/`<C-S-CR>`（插入模式） | 在下方/上方新开一行并继续输入 |
| `<Esc>`（普通模式） | 清除搜索高亮 |
| `<Esc><Esc>`（终端模式） | 返回普通模式 |

## 弹出菜单中的 Alt 映射

- Telescope 搜索框：`Alt+I/K` 选择上一项/下一项，`Alt+J/L` 滚动预览。
- Blink 补全菜单：`Alt+I/K` 选择上一项/下一项；菜单不处理时回退到 Neovim 的其它映射。
- 多光标：`Alt+[`/`Alt+]` 添加前一处/后一处光标，`Alt+P` 选择全部匹配。

## 映射定义位置

- 通用编辑、窗口、缓冲区、诊断：`lua/core/keymaps.lua`
- 查找、Telescope、多光标：`lua/plugins/navigation.lua`、`lua/plugins/editing.lua`
- LSP、补全与格式化：`lua/plugins/lsp.lua`、`lua/plugins/completion.lua`、`lua/plugins/format.lua`
- 调试、终端、CMake、ROS：`lua/plugins/debug.lua`、`lua/plugins/terminal.lua`、`lua/plugins/cmake.lua`、`lua/plugins/ros.lua`、`lua/core/ros.lua`

