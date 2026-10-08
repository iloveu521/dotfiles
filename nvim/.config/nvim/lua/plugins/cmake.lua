--[[
lua/plugins/cmake.lua — CMake 工程的配置 / 构建 / 运行入口

用途：接入 cmake-tools.nvim，把「configure → build → run」这条 CMake 主线做成 <leader>m 系列快捷键，
并把编译产物信息（compile_commands.json）与构建/运行终端接进本配置已有的 clangd 与 toggleterm 体系。
加载时机：本文件被 lua/plugins/init.lua 聚合进 lazy.nvim 的 spec 列表；插件本体靠 cmd 懒加载，
只有真正调用 :CMakeGenerate 等命令或按下 <leader>m* 时才载入，非 CMake 工程里几乎没有开销。
在配置中的地位：CMake 工程的功能开关。cond 决定了整条 spec 只在识别为 CMake 工程时存在，
因此 <leader>m* 这组键位不会被非 CMake 项目占用。
]]

return {
  {
    'Civitasv/cmake-tools.nvim',
    -- 只列出本配置实际用到的命令：lazy.nvim 据此建立「命令 -> 插件」的触发关系，
    -- 命令名与下面 keys 里 <Cmd>...</Cmd> 调用的命令一一对应，二者缺一都会变成 E492。
    cmd = {
      'CMakeGenerate',
      'CMakeBuild',
      'CMakeRun',
      'CMakeSelectBuildTarget',
      'CMakeSelectLaunchTarget',
    },
    -- cond 是懒加载条件：core.project.current() 从当前缓冲区向上查找 CMakeLists.txt 或
    -- compile_commands.json，命中才把工程类型判为 cmake。条件为假时 lazy.nvim 直接跳过整条 spec，
    -- 插件不加载、下面的 keys 也不会注册，于是纯 ROS / 单文件 C++ 工程里 <leader>m* 保持空闲。
    cond = function() return require('core.project').current().kind == 'cmake' end,
    keys = {
      -- <leader>mc 生成构建系统（等价于在工程根目录跑一次 cmake 配置）
      { '<leader>mc', '<Cmd>CMakeGenerate<CR>', desc = 'CMake configure' },
      -- <leader>mb 增量构建；构建输出走 toggleterm 终端，可直接翻看完整报错
      { '<leader>mb', '<Cmd>CMakeBuild<CR>', desc = 'CMake build' },
      -- <leader>mr 运行当前选中的启动目标，适合快速验证改动
      { '<leader>mr', '<Cmd>CMakeRun<CR>', desc = 'CMake run' },
      -- <leader>mt 在候选 target 列表里切换要构建的目标（多 target 工程必备）
      { '<leader>mt', '<Cmd>CMakeSelectBuildTarget<CR>', desc = 'CMake target' },
    },
    opts = {
      cmake_command = 'cmake',
      ctest_command = 'ctest',
      -- Ninja 探测：ninja 可执行时用 Ninja 生成器（增量构建明显快于 Makefiles），
      -- 不存在则给出 nil，让 cmake 回退到自己平台上可用的默认生成器，保证在裸环境也能配置。
      cmake_generator = vim.fn.executable('ninja') == 1 and 'Ninja' or nil,
      -- 构建目录固定为工程根下的 build/，位置可预期：compile_commands.json 会落在这里，
      -- clangd 与 core.project.find_compile_commands 都能按这个约定找到编译数据库。
      cmake_build_directory = 'build',
      -- 每次 configure 都导出 compile_commands.json：clangd 据此获得精确的编译参数，
      -- 补全、跳转、诊断才准确；缺了它 clangd 只能启发式推断，头文件路径常出错。
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' },
      -- 保存文件时不自动重新 configure：避免每次写盘都触发一次 cmake 而拖慢编辑手感；
      -- 代价是改动 CMakeLists.txt 后需要手动按 <leader>mc，这里选择把控制权交给用户。
      cmake_regenerate_on_save = false,
      -- 构建任务的执行器与运行程序都交给 toggleterm：与 core.terminal 的终端体系一致，
      -- 构建日志和交互式程序共用一个可复用、可输入的终端，不再弹独立窗口。
      cmake_executor = { name = 'toggleterm', opts = {} },
      cmake_runner = { name = 'toggleterm', opts = {} },
    },
  },
}
