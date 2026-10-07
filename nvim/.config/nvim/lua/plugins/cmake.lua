return {
  {
    'Civitasv/cmake-tools.nvim',
    cmd = {
      'CMakeGenerate',
      'CMakeBuild',
      'CMakeRun',
      'CMakeSelectBuildTarget',
      'CMakeSelectLaunchTarget',
    },
    cond = function() return require('core.project').current().kind == 'cmake' end,
    keys = {
      { '<leader>mc', '<Cmd>CMakeGenerate<CR>', desc = 'CMake configure' },
      { '<leader>mb', '<Cmd>CMakeBuild<CR>', desc = 'CMake build' },
      { '<leader>mr', '<Cmd>CMakeRun<CR>', desc = 'CMake run' },
      { '<leader>mt', '<Cmd>CMakeSelectBuildTarget<CR>', desc = 'CMake target' },
    },
    opts = {
      cmake_command = 'cmake',
      ctest_command = 'ctest',
      cmake_generator = vim.fn.executable('ninja') == 1 and 'Ninja' or nil,
      cmake_build_directory = 'build',
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' },
      cmake_regenerate_on_save = false,
      cmake_executor = { name = 'toggleterm', opts = {} },
      cmake_runner = { name = 'toggleterm', opts = {} },
    },
  },
}
