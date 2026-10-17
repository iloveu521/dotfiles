--[[
lua/core/autocmds.lua — 核心自动命令

用途：集中定义与插件无关的自动命令（autocmd），即“某事件发生时自动执行的动作”。
加载时机：由 init.lua 调用 require('core.autocmds').setup()，排在 options 之后、keymaps 之前。
地位：属于 core 基础层；这里只放跨项目通用的行为，语言或插件专属的规则交给对应插件配置。
]]

local M = {}

local function save_current_file()
	local buffer = vim.api.nvim_get_current_buf()
	local options = vim.bo[buffer]
	if not options.modified or not options.modifiable or options.readonly or options.buftype ~= "" then
		return
	end
	if vim.api.nvim_buf_get_name(buffer) == "" then
		return
	end

	local saved, error_message = pcall(vim.cmd, "silent update")
	if not saved then
		vim.notify_once("自动保存失败: " .. error_message, vim.log.levels.WARN)
	end
end

-- 注册自动命令；无参数、无返回值，副作用是在命名分组里创建若干 autocmd。
function M.setup()
	-- 创建（并清空重建）命名分组：clear = true 保证重载配置时旧规则被移除，不会重复叠加。
	local group = vim.api.nvim_create_augroup("nvim-workspace-core", { clear = true })

	-- C 系语言统一采用 Google 风格的 4 空格缩进，其余语言沿用 options.lua 的 2 空格。
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		-- 仅在识别出这些文件类型后触发；objc/objcpp/cuda 遵循同一套缩进规范。
		pattern = { "c", "cpp", "objc", "objcpp", "cuda" },
		-- :autocmd 列表里显示的说明文字，保留英文原文以便检索。
		desc = "Use Google-style four-space indentation for C and C++",
		-- 回调只改缓冲区局部选项（bo），不会污染其他文件类型的默认值。
		callback = function()
			vim.bo.expandtab = true -- C 系也用空格缩进，不写入真实制表符
			vim.bo.shiftwidth = 2 -- 每级缩进 4 个空格，符合 Google 风格
			vim.bo.tabstop = 2 -- 文件里已有的制表符按 4 列显示
			vim.bo.softtabstop = 2 -- 插入模式下按 Tab 相当于 4 个空格
		end,
	})

	-- 复制（yank）之后短暂高亮被复制的区域，给操作一个视觉确认。
	vim.api.nvim_create_autocmd("TextYankPost", {
		group = group,
		desc = "Highlight text after yanking",
		-- 180ms 的短闪烁：足够看见，又不会干扰连续编辑。
		callback = function()
			vim.highlight.on_yank({ timeout = 180 })
		end,
	})

	-- 回到 Neovim 或重新进入缓冲区时检查磁盘变化；autoread 只会重载本地未修改的缓冲区。
	vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
		group = group,
		desc = "Reload files changed outside Neovim",
		callback = function()
			vim.schedule(function()
				vim.cmd("silent! checktime")
			end)
		end,
	})

	-- 从插入、可视等模式回到普通模式时立即保存当前文件。
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		pattern = "*:n",
		desc = "Save the current file when returning to normal mode",
		callback = save_current_file,
	})

	-- 普通模式下每两秒检查外部修改，并保存当前已修改的普通文件缓冲区。
	local previous_timer = vim.g.nvim_workspace_autosave_timer
	if type(previous_timer) == "number" then
		pcall(vim.fn.timer_stop, previous_timer)
	end
	vim.g.nvim_workspace_autosave_timer = vim.fn.timer_start(2000, function()
		if vim.api.nvim_get_mode().mode ~= "n" then
			return
		end
		vim.cmd("silent! checktime")
		save_current_file()
	end, { ["repeat"] = -1 })
end

return M
