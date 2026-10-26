# VS Code and Neovim Shortcut Reference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a searchable, offline single-page reference for the user's current VS Code Vim and Neovim editing shortcuts.

**Architecture:** Put the complete semantic HTML, CSS, shortcut dataset, search and filters in `docs/editor-shortcuts.html`. Build a temporary browser mockup first for visual feedback, then refine and deliver the same single-file design without adding runtime dependencies or changing editor configuration.

**Tech Stack:** HTML, CSS, vanilla JavaScript; browser preview for visual and interaction checks.

**Spec:** `docs/superpowers/specs/2026-10-26-editor-shortcuts-reference-design.md`

## Global Constraints

- Keep the delivered page as one local offline HTML file with no remote assets or dependencies.
- Use the current VS Code `settings.json` and `keybindings.json`, Neovim `KEYMAPS.md` and Lua mappings as shortcut sources.
- Include only current, confirmed shortcuts and clearly mark Vim-native commands.
- Keep the user's configured mappings separate from the Vim-native guide. Explicitly state Neovim uses Space as `<leader>` and current VS Code Vim has no Leader mapping.
- Document VS Code `Alt+P` as `editor.action.selectHighlights`; include the user's observed `a`/`i` behavior as an environment-specific note, and distinguish Neovim's own multi-cursor mapping.
- Include a practical Vim-native guide for modes, motions, operators/text objects, line editing, search and whole-word replacement.
- Search by key, action, Chinese aliases and notes; filter by editor and category.
- Use macaron lavender, pink and green accents with high-contrast text and keycaps, visible focus, narrow-screen reflow and reduced-motion support.
- Do not alter editor mappings, publish, deploy or add automated tests.

## Review Focus

- Search terms containing punctuation such as `Alt+R` still find the correct mapping.
- Editor and category filters combine correctly and can be reset.
- Empty results show a clear recovery action and the result count stays accurate.
- The reference distinguishes VS Code Vim modes from Neovim modes and labels native Vim commands.
- Keyboard-only focus, narrow viewports and reduced-motion settings remain usable.

---

### Task 1: Create and review the browser mockup

**Files:**
- Create temporarily: `/tmp/editor-shortcuts-mockup.html` (remove after mockup review)
- Read: `docs/nvim-keymaps.md`, Neovim Lua mappings, VS Code `settings.json` and `keybindings.json`

**Interfaces:**
- Produces a clickable browser preview of the approved page layout and representative shortcut rows.

- [x] **Step 1: Build a temporary mockup** with the single-file page structure, high-contrast pastel glass treatment, representative shared and editor-specific mappings, and working search/filter controls.
- [x] **Step 2: Open the mockup in a browser** and inspect its visual hierarchy and basic interaction at desktop and narrow widths.
- [x] **Step 3: Show the preview and incorporate the user's feedback** before finalizing the production page.

### Task 2: Deliver the offline shortcut reference

**Files:**
- Create: `docs/editor-shortcuts.html`
- Read: `docs/nvim-keymaps.md`, Neovim Lua mappings, VS Code `settings.json` and `keybindings.json`
- Remove: `/tmp/editor-shortcuts-mockup.html`

**Interfaces:**
- Consumes the approved mockup direction and verified current mappings.
- Produces a standalone HTML page with inline styles, data and vanilla JavaScript.

- [x] **Step 1: Extract and cross-check common mappings** from both editor configurations, grouping movement, editing, search/replace, code navigation, completion/multicursor and file finding.
- [x] **Step 2: Implement the page** in `docs/editor-shortcuts.html`, with Chinese action descriptions, keycaps, mode labels, `<leader>` explanation, separate configured-mapping and Vim-native-guide sections, search, editor/category filters, result count and empty state.
- [x] **Step 3: Open the delivered file directly in a browser** and manually verify shortcut lookup, combined/reset filters, empty state, keyboard focus, desktop/narrow layouts and reduced-motion behavior.
- [x] **Step 4: Review the final diff** to confirm only the planned documentation artifacts changed and remove the temporary mockup.
