# Neovim 快捷键速查表

本文件按功能分类列出 `nvim/.config/nvim` 中定义的全部快捷键，并标注每条绑定的**定义位置**与**生效条件**。
快捷键以配置文件为准；插件自身的默认按键（如 neo-tree、telescope 的插入模式按键）在文末单独说明。

- 配置根目录：`nvim/.config/nvim`（在 `~/.config/nvim` 作为符号链接生效）
- Leader 键：**空格**（`<Space>`，`vim.g.mapleader = ' '`）；LocalLeader 同为空格
- 查看当前生效的全部映射：`:map`（或 `:nmap <leader>` 只看 leader 相关）；也可用 `:Telescope keymaps` 交互式浏览
- 按 `<leader>` 后停顿约 400ms（`timeoutlen`），which-key 会弹出该前缀下所有可用按键

## 阅读约定

| 记号 | 含义 |
| --- | --- |
| `<leader>` | 空格键 |
| `n` / `i` / `v` / `t` | 普通模式 / 插入模式 / 可视模式 / 终端模式 |
| `n,v` | 普通模式与可视模式都生效 |
| `M-` | Alt（Meta）修饰键，如 `<M-j>` = Alt+J |
| `C-` | Ctrl 修饰键，如 `<C-h>` = Ctrl+H |
| 条件 | 只有在满足条件的项目/缓冲区中才存在该映射 |

## 前缀分组速览

| 前缀 | 主题 | 代表按键 |
| --- | --- | --- |
| `<leader>f` | 查找（find） | `<leader>ff` 找文件、`<leader>fg` 全文搜索 |
| `<leader>b` | 缓冲区（buffer） | `<leader>bb` 切换缓冲区、`<leader>bd` 删除缓冲区 |
| `<leader>c` | 代码（code） | `<leader>ca` 代码操作、`<leader>cf` 格式化、`<leader>cs` 符号大纲 |
| `<leader>g` | Git | `<leader>gp` 预览改动块 |
| `<leader>t` | 终端与标签页（terminal / tab） | `<leader>tt` 终端、`<leader>tn` 下个标签页 |
| `<leader>m` | CMake | `<leader>mb` 构建 |
| `<leader>r` | ROS 2 | `<leader>rb` 构建包 |
| `<leader>d` | 调试（debug） | `<leader>db` 断点 |
| `<leader>q` | 会话（session） | `<leader>qs` 恢复会话 |
| `<leader>a` | AI 助手（agent） | `<leader>aa` 选择助手 |
| `<leader>u` | 界面/开关（UI） | `<leader>uw` 折行、`<leader>uf` 保存时格式化 |
| `<leader>s` | 分屏尺寸（split） | `<leader>se` 均分窗口 |
| `<leader>x` | 关闭（close） | `<leader>xs` 关闭分屏 |

> 注意：`<leader>t` 同时用于「终端」和「标签页」，`<leader>s*` 中 `se` 是窗口均分、而 `<M-s>` 是预览定义。使用时以 which-key 弹出的提示为准。

---

## 1. 基础移动与保存（core/keymaps.lua）

| 按键 | 模式 | 功能 | 说明 |
| --- | --- | --- | --- |
| `j` / `k` | n | 按**显示行**上下移动 | 无计数时走 `gj`/`gk`，长折行文本移动更自然；带计数（如 `5j`）时仍按真实行移动 |
| `<Esc>` | n | 清除搜索高亮 | 等价 `:nohlsearch`，不动光标 |
| `<C-s>` | n | 保存文件 | 等价 `:write`；部分终端需关闭流控（`stty -ixon`）才能收到 `C-s` |

## 2. VS Code 风格 Alt 键位（core/keymaps.lua）

统一用 I / K / J / L 表示上 / 下 / 左 / 右，普通、插入、可视、终端四种模式一致，原生 `h/j/k/l` 仍然可用。

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<M-i>` | n / v | 上移（`gk`）；可视模式下扩展选区 |
| `<M-k>` | n / v | 下移（`gj`）；可视模式下扩展选区 |
| `<M-j>` | n / v | 左移（`h`）；可视模式下扩展选区 |
| `<M-l>` | n / v | 右移（`l`）；可视模式下扩展选区 |
| `<M-i>` / `<M-k>` / `<M-j>` / `<M-l>` | i | 光标上 / 下 / 左 / 右（映射为方向键） |
| `<M-i>` / `<M-k>` / `<M-j>` / `<M-l>` | t | 终端历史上下翻、终端光标左右移动 |
| `<M-u>` / `<M-o>` | n / v | 跳到行首（`^`）/ 行尾（`$`） |
| `<M-u>` / `<M-o>` | i | 跳到行首 / 行尾（Home / End） |
| `<M-u>` / `<M-o>` | t | 终端行首 / 行尾（Home / End） |
| `<M-J>` / `<M-L>` | n / v | 向左 / 向右移动一个单词（`b` / `w`） |
| `<M-J>` / `<M-L>` | i | 向左 / 向右移动一个单词（`C-Left` / `C-Right`） |
| `<M-b>` | n | 跳回上一次跳转前的位置（`C-o`） |
| `<M-a>` | n | 删除当前整行（`dd`） |
| `<M-a>` | i | 删除当前整行并回到插入模式（`<Esc>ddi`） |
| `<M-BS>` | i | 等同 Delete，删除光标下字符 |

> 插入模式下 `<M-i>` / `<M-k>` 与补全菜单的选择键重叠：菜单打开时由 blink.cmp 接管（选择上一项/下一项），菜单未打开时回退为光标移动。

## 3. 窗口与分屏（core/keymaps.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | n | 焦点移到左 / 下 / 上 / 右的分屏 |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | t | 从终端窗口把焦点移到左 / 下 / 上 / 右的分屏（自动先退出终端输入模式） |
| `<Up>` / `<Down>` | n | 当前窗口高度减 2 / 加 2 行 |
| `<Left>` / `<Right>` | n | 当前窗口宽度减 2 / 加 2 列 |
| `<leader>v` | n | 垂直分屏（`:vsplit` 效果） |
| `<leader>h` | n | 水平分屏 |
| `<leader>se` | n | 所有分屏尺寸均分 |
| `<leader>xs` | n | 关闭当前分屏 |

## 4. 缓冲区（core/keymaps.lua、plugins/editing.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<C-n>` | n | 新建空缓冲区（`:enew`） |
| `[b` / `]b` | n | 上一个 / 下一个缓冲区 |
| `<leader>bb` | n | 列出并切换缓冲区（telescope，按最近使用排序） |
| `<leader>fb` | n | 同上（查找缓冲区） |
| `<leader>bd` | n | 删除当前缓冲区（`:bdelete`，不关闭窗口） |

## 5. 标签页（core/keymaps.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>to` | n | 新建标签页 |
| `<leader>tx` | n | 关闭当前标签页 |
| `<leader>tn` | n | 下一个标签页 |
| `<leader>tp` | n | 上一个标签页 |

## 6. 剪贴板、折行与编辑辅助（core/keymaps.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>y` | n, v | 复制到系统剪贴板（`"+y`） |
| `<leader>Y` | n | 复制整行到系统剪贴板（`"+Y`） |
| `<leader>uw` | n | 切换自动折行（wrap） |
| `p` | v | 粘贴且**不覆盖**剪贴板寄存器（`"_dP`），可反复粘贴同一内容 |
| `<` / `>` | v | 左缩进 / 右缩进后保持选区 |
| `jk` | i | 退出插入模式（避免伸小指按 Esc） |

> 剪贴板本身已设为 `unnamedplus`（`core/options.lua`），普通 `y` 也会进系统剪贴板；`<leader>y` 用于需要显式指定寄存器的场合。

## 7. 光标居中与滚动（core/keymaps.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<C-d>` / `<C-u>` | n | 向下 / 向上翻半页并让光标居中（`zz`） |
| `n` / `N` | n | 下一个 / 上一个搜索结果并居中（`zzv`） |

## 8. 诊断（core/keymaps.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `[d` / `]d` | n | 跳到上一条 / 下一条诊断，并弹出浮动详情 |
| `gl` | n | 显示当前行的诊断浮窗 |

## 9. 数值增减（core/keymaps.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>+` | n | 光标所在数字 +1 |
| `<leader>-` | n | 光标所在数字 -1 |

## 10. 文件与内容检索（plugins/navigation.lua）

以下查找类命令都以**当前检测到的项目根目录**为工作目录（`core/project.lua` 决定项目根）。

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>ff` | n | 查找项目文件（含隐藏文件） |
| `<leader>fg` | n | 项目内实时全文搜索（live grep） |
| `<leader>fr` | n | 最近打开过的项目内文件 |
| `<leader>fb` / `<leader>bb` | n | 缓冲区列表 |
| `<leader>fh` | n | 帮助文档标签 |
| `<leader>fc` | n | 可用命令列表 |
| `<leader>ft` | n | 搜索 TODO / FIXME 等标记（todo-comments） |

## 11. 文件树与符号大纲（plugins/navigation.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>e` | n | 打开/关闭文件树（neo-tree，左侧，自动定位当前文件） |
| `<leader>cs` | n | 打开/关闭符号大纲（aerial，右侧） |

## 12. 代码补全（plugins/completion.lua，blink.cmp）

插入模式下的按键。预设为 blink.cmp 的 `enter`（回车接受补全）。

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<CR>` | i | 接受当前补全项；无补全时正常换行 |
| `<C-space>` | i | 显示补全菜单 / 显示文档 / 收起文档 |
| `<C-e>` | i | 取消并隐藏补全菜单 |
| `<M-i>` / `<M-k>` | i | 选择上一项 / 下一项补全（菜单未开时回退为光标移动） |
| `<C-n>` / `<C-p>` | i | 选择下一项 / 上一项（回退到映射） |
| `<Up>` / `<Down>` | i | 选择上一项 / 下一项 |
| `<Tab>` / `<S-Tab>` | i | 跳到下一个 / 上一个代码片段占位符 |
| `<C-b>` / `<C-f>` | i | 补全文档窗口向上 / 向下滚动 |
| `<C-k>` | i | 显示 / 隐藏函数签名帮助 |

## 13. LSP（plugins/lsp.lua）

**全局延迟加载键**（未打开文件也能按，会顺带加载插件）：

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<M-d>` | n | 跳到定义 |
| `<M-s>` | n | 在不跳转的情况下预览定义（telescope 列表） |

**缓冲区级按键**（`LspAttach` 后生效，即已挂载语言服务器的文件）：

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `gd` | n | 跳到定义 |
| `gD` | n | 跳到声明 |
| `gr` | n | 查找引用 |
| `K` | n | 悬浮显示文档/类型信息 |
| `<leader>ca` | n | 代码操作（重命名、导入、快速修复等） |
| `<leader>cr` | n | 重命名符号（跨文件） |

已启用的语言服务器：`clangd`（C/C++/CUDA）、`lua_ls`、`basedpyright`、`ruff`。

## 14. 格式化（plugins/format.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>cf` | n, v | 立即格式化（异步，允许回退到 LSP 格式化） |
| `<M-f>` | n, v, i | 同上（更快的触发方式） |
| `<leader>uf` | n | 切换「保存时自动格式化」开关，并提示当前状态 |

保存时格式化默认开启，并按文件类型选择格式化器：C/C++ → `clang-format`、Lua → `stylua`、CMake → `cmake_format`、Python → `ruff format`。
开关是**缓冲区级**的（`core/format.lua`）。

## 15. Git（plugins/editing.lua，gitsigns）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>gp` | n | 预览光标所在的改动块 |
| `<leader>gs` | n, v | 暂存当前改动块（可视模式下暂存选中行） |
| `<leader>gr` | n, v | 撤销当前改动块 |
| `<leader>gb` | n | 显示光标所在行的 Git blame |

## 16. 调试（plugins/debug.lua + core/debug.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>dc` / `<F5>` | n | 开始/继续调试 |
| `<leader>db` | n | 切换断点 |
| `<leader>da` | n | 附加到正在运行的进程（交互式选择 PID） |
| `<leader>dl` | n | 启动可执行文件（提示输入路径） |
| `<leader>du` | n | 关闭调试界面（dap-ui） |
| `<F10>` | n | 单步跳过（step over） |
| `<F11>` | n | 单步进入（step into） |
| `<F12>` | n | 单步跳出（step out） |

调试适配器：系统 `gdb`（ROS 场景首选）与 mason 安装的 `codelldb`；
ROS 项目会自动注入 `source` 环境脚本后的环境变量，并在启动调试时按当前项目重新解析 `cwd`。

## 17. 终端与 AI 助手（plugins/terminal.lua + core/terminal.lua）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>tt` / `<C-\>` | n | 打开/隐藏 1 号终端 |
| `<leader>t2` | n | 打开/隐藏 2 号终端 |
| `<leader>t3` | n | 打开/隐藏 3 号终端 |
| `<Esc><Esc>` | t | 退出终端输入模式，回到普通模式 |
| `<leader>aa` | n | 从列表选择并打开编码助手（codex / claude / gemini / opencode） |
| `<leader>al` | n | 重新打开上一次使用的编码助手 |
| `<leader>ak` | n | 关闭当前编码助手会话 |

终端是**按角色持久化**的（`core/terminal.lua`）：同名终端会复用同一个实例，隐藏而不销毁；
构建/运行类终端在重复执行前会先关闭旧实例。

## 18. CMake 项目（plugins/cmake.lua）

仅当检测到 CMake 项目（存在 `CMakeLists.txt` 或 `compile_commands.json`）时该插件才加载，因此以下按键只在 CMake 项目中存在：

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>mc` | n | CMake 配置（generate） |
| `<leader>mb` | n | CMake 构建 |
| `<leader>mr` | n | 运行选定的启动目标 |
| `<leader>mt` | n | 选择构建目标 |

构建目录固定为 `build/`，生成时自动带 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`（供 clangd 使用）；
若存在 `ninja` 则优先使用 Ninja 生成器；构建/运行输出复用 toggleterm 终端。

## 19. ROS 2 项目（core/ros.lua）

这些映射是**缓冲区级**的，只会附加在属于 ROS 包或 ROS 工作空间的缓冲区上（打开文件时自动检测）。

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>rb` | n | 构建当前包（`colcon build --symlink-install`，自动带上包名） |
| `<leader>rt` | n | 测试当前包（`colcon test`） |
| `<leader>rs` | n | 打开已 source ROS 环境的 shell |
| `<leader>rc` | n | 手动刷新 `compile_commands.json` 并重启 clangd |
| `<leader>rr` | n | 运行包内可执行文件（`ros2 run <包名> <可执行文件>`，会提示输入名称） |

环境脚本按顺序 source：自动发现的 `/opt/ros/<distro>/setup.zsh` 与 `<工作空间>/install/setup.zsh`（存在才加载）。
构建成功后会自动刷新编译数据库并为该工作空间重启 clangd，使跳转与补全立即生效。

## 20. 会话管理（plugins/editing.lua，persistence）

| 按键 | 模式 | 功能 |
| --- | --- | --- |
| `<leader>qs` | n | 恢复当前目录对应的会话 |
| `<leader>ql` | n | 恢复上一次的会话 |
| `<leader>qd` | n | 本次不保存会话（退出时丢弃） |

## 21. 用户命令（`:` 命令）

| 命令 | 来源 | 功能 |
| --- | --- | --- |
| `:Terminal [n]` | core/terminal.lua | 打开编号为 n 的持久终端（默认 1） |
| `:ProjectInfo` | core/project.lua | 弹出当前识别到的项目上下文（类型、根目录、包名） |
| `:ProjectOverride <kind> [root]` | core/project.lua | 手动指定项目类型与根目录（kind 可补全） |
| `:ProjectOverrideClear` | core/project.lua | 清除手动覆盖并清空缓存 |
| `:Mason` | plugins/lsp.lua | 打开 mason 界面管理 LSP/格式化器/调试器 |
| `:Neotree` | plugins/navigation.lua | 文件树命令（toggle / reveal / left 等参数） |
| `:AerialToggle` | plugins/navigation.lua | 符号大纲开关 |
| `:Telescope` | plugins/navigation.lua | 打开任意 telescope 选择器（如 `:Telescope keymaps`） |
| `:ConformInfo` | plugins/format.lua | 查看当前缓冲区的格式化器信息 |
| `:CMakeGenerate` / `:CMakeBuild` / `:CMakeRun` / `:CMakeSelectBuildTarget` / `:CMakeSelectLaunchTarget` | plugins/cmake.lua | CMake 相关命令（仅在 CMake 项目可用） |
| `:DapInstall` / `:DapUninstall` | plugins/debug.lua | 通过 mason 安装/卸载调试适配器 |
| `:TSUpdate` | plugins/treesitter.lua | 更新已安装的语法解析器 |

`ProjectOverride` 支持的 kind：`standalone`、`cpp`、`cmake`、`ros_package`、`ros_workspace`。

## 22. 插件自带、未在配置中改写的常用按键

以下键来自插件默认值，本仓库未覆盖；列出来只是方便查阅。

**文件树 neo-tree**（`<leader>e` 打开后）：
`?` 查看全部内置按键；常用有 `a` 新建、`d` 删除、`r` 重命名、`y` 复制路径、`H` 切换隐藏文件、`R` 刷新、`<CR>`/`o` 打开、`s`/`S` 分屏打开、`t` 标签页打开、`q` 关闭。

**telescope 插入模式**：
`<C-n>`/`<C-p>`（或方向键）上下选择、`<CR>` 打开、`<C-x>` 水平分屏打开、`<C-v>` 垂直分屏打开、`<C-t>` 新标签页打开、`<Esc>` 关闭。

**which-key**：按下 `<leader>` 等前缀后停顿，弹出可用的后续按键提示。

**终端**：`open_mapping` 已关闭，因此 toggleterm 默认的 `<C-\>` 由本配置接管（只在普通模式生效）；终端模式用 `<Esc><Esc>` 退出。

## 23. 生效条件与冲突提示

- **项目类型相关**：`<leader>m*`（CMake）只在 CMake 项目存在；`<leader>r*`（ROS）只在 ROS 包/工作空间的缓冲区存在。其余键全局可用。
- **模式相关**：`<M-i>` / `<M-k>` 在插入模式同时被补全菜单使用；菜单打开时优先补全，关闭时移动光标。
- **`<leader>t` 前缀混用**：`to`/`tx`/`tn`/`tp` 是标签页，`tt`/`t2`/`t3` 是终端。
- **终端模拟器**：Alt 组合键需要终端正确发送 Meta（kitty 默认可行）；`<C-s>` 若被终端流控拦截，可在 shell 配置里执行 `stty -ixon`。
- **修改快捷键**：全局键改 `lua/core/keymaps.lua`；插件相关键改对应 `lua/plugins/*.lua` 的 `keys` 字段；LSP 缓冲区键改 `lua/plugins/lsp.lua` 的 `lsp_mappings`；ROS 缓冲区键改 `lua/core/ros.lua` 的 `M.attach`。改完保存后重启 Neovim 即生效。
