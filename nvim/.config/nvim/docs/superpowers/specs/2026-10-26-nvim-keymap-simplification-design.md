# Neovim 与 VSCode Vim 编辑按键对齐设计

## 目标

减少需要记忆的映射和重复入口，让 Neovim 与 VSCode Vim 的常用编辑键大体一致。每项功能保留一个容易联想、方便按的主入口。VSCode 当前的用户配置已软链接到 dotfiles；改动编辑这两个仓库源文件。

## 已选方案与取舍

考虑过只整理 Neovim 映射、仅提供差异清单、以及统一两边常用编辑键。用户选择按建议统一并加入搜索替换。已确认 VSCode Vim 1.32.4 已安装；`settings.json` 与 `keybindings.json` 软链接至 dotfiles。扩展默认关闭系统剪贴板，当前 VSCode 的 `Ctrl+D` 复制行、`Alt+A` 删行与 Neovim 的半屏滚动及用户选定的 `Alt+A` 前进冲突。

## 具体范围

- 两边保留一致的编辑动作：`Alt+U/O` 行首/行尾，`Alt+Shift+J/L` 按词移动，`yy` 复制当前行，`dd` 删除当前行，`Alt+F` 格式化，`gd/gD/gr` 跳定义/声明/引用，`Alt+B/A` 回退/前进，`Alt+S` 预览定义，`Alt+P` 选择当前单词的全部匹配项，`Alt+R` 完整单词替换。
- `Alt+R` 从光标所在单词开始，在当前文件内提示新词并逐处确认；替换模式使用 `\<` / `\>` 单词边界，避免修改较长标识符中的子串。VSCode Vim 通过命令行替换映射实现相同行为。
- VSCode Vim 开启系统剪贴板，使 `yy` 与 Neovim `clipboard=unnamedplus` 一致。
- 将 VSCode `Alt+A` 从删行改为前进跳转；删行统一用 Vim `dd`。移除 VSCode `Ctrl+D` 复制行覆盖，使 VSCode Vim 执行原生半屏下滚；复制行统一用 `yy`。Neovim 额外将光标行居中。
- 将 VSCode `Ctrl+Enter` 插入下一行统一为 `Shift+Enter`，并增加 `Ctrl+Shift+Enter` 在上一行插入；只在 Vim 插入模式生效，与 Neovim 一致。
- VSCode Vim 默认接管 `Ctrl+D` 并执行半屏下滚；移除复制行覆盖，依赖扩展默认值，不重复声明 `vim.handleKeys.<C-d>`。
- VSCode Vim 显式提供 `gd/gD/gr` 对应的定义、声明、引用命令。两边移除重复的 `Alt+D` 定义入口。
- 删除全局 `Alt+I/J/K/L` 方向移动映射，只保留 Telescope 搜索框和补全菜单里的 `Alt+I/K`；Neovim `Alt+P` 与 VSCode `editor.action.selectHighlights` 都选择全部匹配项，移除 VSCode 重复的 `Alt+Shift+I` 和可用 Vim 可视模式完成的 `Ctrl+Shift+I/J/K/L` 编辑映射。
- 保留独有的 `Alt+S` 定义预览、`jk` 退出插入模式、`<C-s>` 保存，以及终端、窗口、缓冲区、会话和项目功能。
- Neovim 里缓冲区切换保留 `<leader>bb` 并移除重复 `<leader>fb`；调试继续保留 `F5` 并移除重复 `<leader>dc`；格式化保留 `Alt+F` 并移除 `<leader>cf`。
- LSP 代码操作与重命名保留 `<leader>ca` / `<leader>cr`。Neovim 默认的 `gr*` LSP 映射会让 `gr` 引用跳转等待前缀超时，因此在 LSP 缓冲区屏蔽 `gra/grn/grr/gri/grt/grx`，并让 `gr` 立即执行；这些默认映射在非 LSP 缓冲区不受影响。
- VSCode 用户键位配置位于 dotfiles，并由 `~/.config/Code/User/` 软链接生效；不新建另一份全局配置。
- 同步更新 `KEYMAPS.md`，并在完成后检查运行时映射、VSCode Vim 设置格式和软链接目标。

## 不在范围内

不改文件/项目/终端/调试快捷键分组，不重排插件或改变 Leader 分组结构，不调整 which-key 提示与 timeoutlen。
