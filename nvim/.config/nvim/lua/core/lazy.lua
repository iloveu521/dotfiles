--[[
lua/core/lazy.lua — lazy.nvim 引导与加载

用途：自举安装插件管理器 lazy.nvim，然后加载 lua/plugins/ 下汇总出的插件清单。
加载时机：由 init.lua 在最后调用，此时 options/autocmds/keymaps 都已就绪。
地位：core 层与插件层的交界；它是唯一在插件加载之前执行的“插件相关”代码。
]]

local M = {}

-- 引导并启动 lazy.nvim；无参数、无返回值，副作用是可能克隆插件管理器并加载全部插件。
function M.setup()
  -- 安装位置取 stdpath('data') 下的 lazy/lazy.nvim，不写死绝对路径，跨机器可用。
  local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
  -- 用文件系统探测代替直接 require：未安装时要主动克隆，而不是抛出难懂的加载错误。
  if not vim.uv.fs_stat(path) then
    -- 同步调用 git 完成首次安装；--filter=blob:none 是部分克隆，只取需要的对象，体积更小。
    vim.fn.system({
      'git',
      'clone',
      '--filter=blob:none',
      '--branch=stable',
      'https://github.com/folke/lazy.nvim.git',
      path,
    })
    -- 克隆失败（无网络或缺少 git）时立刻报错，避免后续 require 抛出更晦涩的堆栈。
    if vim.v.shell_error ~= 0 then error('Unable to install lazy.nvim') end
  end

  -- 把 lazy.nvim 目录插到 runtimepath 最前面，使 require('lazy') 能找到它。
  vim.opt.runtimepath:prepend(path)
  -- 加载插件清单（require('plugins') 即 lua/plugins/init.lua），第二参数是 lazy.nvim 的全局选项。
  require('lazy').setup(require('plugins'), {
    change_detection = { notify = false }, -- 配置文件被外部改动时不弹通知，避免启动打扰
    checker = { enabled = false },         -- 关闭每日自动检查更新，改为手动跑 :Lazy update
    rocks = { enabled = false },           -- 不安装 luarocks 依赖，减少构建依赖和网络请求
    ui = { border = 'rounded' },           -- :Lazy 面板使用圆角边框
  })
end

return M
