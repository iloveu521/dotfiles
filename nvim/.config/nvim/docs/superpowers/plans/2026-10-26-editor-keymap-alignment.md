# Neovim and VSCode Vim Editing Keymap Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the user's common editing shortcuts across Neovim and VSCode Vim while removing duplicate and conflicting mappings.

**Architecture:** Keep shared editor actions in the existing Neovim Lua maps and VSCode dotfiles settings/keybindings. Use VSCodeVim normal-mode mappings for LSP navigation and whole-word replacement; keep popup-only Alt+I/K bindings local to Telescope/Blink and VSCode suggestions.

**Tech Stack:** Neovim Lua keymaps, VSCode JSONC settings and keybindings, VSCodeVim 1.32.4.

**Spec:** `docs/superpowers/specs/2026-10-26-nvim-keymap-simplification-design.md`

## Global Constraints

- Preserve `Alt+I/K` in Telescope/Blink/suggestion menus; remove global Alt+IJKL cursor movement.
- Keep `Alt+U/O`, `Alt+Shift+J/L`, `Alt+F`, `Alt+S`, `Alt+P`, `Alt+B/A`, and the requested `gd/gD/gr` navigation behavior aligned.
- `yy` and `dd` are the shared line copy/delete actions; VSCode Vim must use the system clipboard.
- `Alt+R` replaces the word under the cursor across the current file, requires exact word boundaries, and confirms each match.
- The active VSCode settings and keybindings are already symlinked to `workspace/dotfiles/vscode`.
- Do not alter file, project, terminal, or debugging groups beyond removing the duplicate debug continue alias.

## Review Focus

- `roscontroler` must not match inside `roscontrolertopic`; both replace flows use word boundaries.
- `Alt+A` must not delete a line; it navigates forward in Normal mode in both editors.
- VSCode `Ctrl+D` uses VSCode Vim's default half-page-down; `yy` must copy to the system clipboard.
- VSCode `gd/gD/gr` must invoke definition/declaration/references in Normal mode.
- Popup `Alt+I/K` must remain available after removing global movement bindings.

---

### Task 1: Simplify Neovim editing and LSP mappings

**Files:**
- Modify: `lua/core/keymaps.lua`
- Modify: `lua/plugins/lsp.lua`
- Modify: `lua/plugins/format.lua`
- Modify: `lua/plugins/debug.lua`
- Modify: `lua/plugins/navigation.lua`

- [x] Remove global Alt+I/K line-moving maps and their helper functions; keep Alt+U/O and Alt+Shift+J/L for the user's frequent movement actions.
- [x] Map Alt+B to `<C-o>` and Alt+A to `<C-i>` in Normal mode; remove Alt+A line deletion mappings.
- [x] Remove duplicate line-copy `<leader>Y`; retain native `yy` through `clipboard=unnamedplus`; retain `dd` for line deletion.
- [x] Add Normal-mode Alt+R replacement using the cursor word, case-sensitive `\<...\>` boundaries, current-buffer scope, and per-match confirmation.
- [x] Keep `gd/gD/gr`, remove duplicate `Alt+D`; mask the default `gr*` LSP mappings in LSP buffers and make `gr` immediate to avoid prefix delay; keep Alt+S preview.
- [x] Keep Alt+F format and remove `<leader>cf`; keep F5 debug continue and remove `<leader>dc`; keep `<leader>bb` and remove `<leader>fb`.

### Task 2: Align VSCode Vim editing mappings

**Files:**
- Modify: `vscode/.config/Code/User/settings.json`
- Modify: `vscode/.config/Code/User/keybindings.json`

- [x] Set `vim.useSystemClipboard` to `true`; rely on VSCode Vim's default `<C-d>` handling for half-page scrolling.
- [x] Add Normal-mode VSCode Vim mappings for `gD` declaration, `gr` references, and Alt+R whole-word substitution; retain the extension's `gd` definition behavior.
- [x] Change Normal-mode Alt+A from line deletion to `workbench.action.navigateForward`; scope Alt+B back and Alt+A forward to Vim Normal mode.
- [x] Remove the Ctrl+D copy-line override, Alt+D definition duplicate, and global Alt+I/J/K/L cursor movement overrides; retain suggestion-menu Alt+I/K.
- [x] Change line insertion to Shift+Enter below and Ctrl+Shift+Enter above in Insert mode, matching Neovim.
- [x] Keep shared Alt+U/O, Alt+Shift+J/L, Alt+F, Alt+S, Alt+P behavior; remove duplicate selection bindings and preserve terminal-specific mappings.

### Task 3: Update the mapping index

**Files:**
- Modify: `KEYMAPS.md`

- [x] Document the shared editing keys, mode/context restrictions, exact-word replacement, and the remaining Neovim-only leader actions.

### Task 4: Verify effective mappings and paths

**Files:** None.

- [x] Confirm both VSCode user paths still resolve to the dotfiles sources.
- [x] Parse VSCode JSONC settings and keybindings.
- [x] Load Neovim headless with `-u NONE`, syntax-check edited Lua files, and inspect the core and LSP mappings directly.
- [x] Compare the shared-key table against the VSCode configs, checking popup-only Alt+I/K and exact replacement boundaries.
