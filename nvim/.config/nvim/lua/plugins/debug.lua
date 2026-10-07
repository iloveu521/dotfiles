local function context()
  return require('core.project').current()
end

local function choose_program()
  return vim.fn.input('Executable: ', require('core.project').current().root .. '/', 'file')
end

return {
  { 'nvim-neotest/nvim-nio', lazy = true },
  {
    'mfussenegger/nvim-dap',
    keys = {
      { '<leader>dc', function() require('dap').continue() end, desc = 'Debug continue' },
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint' },
      { '<leader>da', function()
        local dap = require('dap')
        dap.run(require('core.debug').attach_configuration(context(), require('dap.utils').pick_process()))
      end, desc = 'Attach process' },
      { '<leader>dl', function() require('dap').run(require('core.debug').launch_configuration(context(), choose_program())) end, desc = 'Launch executable' },
      { '<leader>du', function() require('dapui').close() end, desc = 'Close debug UI' },
      { '<F5>', function() require('dap').continue() end, desc = 'Debug continue' },
      { '<F10>', function() require('dap').step_over() end, desc = 'Debug step over' },
      { '<F11>', function() require('dap').step_into() end, desc = 'Debug step into' },
      { '<F12>', function() require('dap').step_out() end, desc = 'Debug step out' },
    },
    config = function()
      local dap = require('dap')
      local debug = require('core.debug')
      debug.register_adapters(dap)
      debug.setup_dynamic_context(dap)
      dap.configurations.cpp = {
        debug.launch_configuration(context(), choose_program, 'gdb'),
        debug.attach_configuration(context(), function() return require('dap.utils').pick_process() end, 'gdb'),
      }
      dap.configurations.c = dap.configurations.cpp
    end,
  },
  {
    'rcarriga/nvim-dap-ui',
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
    opts = { floating = { border = 'rounded' } },
    config = function(_, opts)
      local dapui = require('dapui')
      dapui.setup(opts)
      require('core.debug').setup_ui(require('dap'), dapui)
    end,
  },
  {
    'theHamsta/nvim-dap-virtual-text',
    dependencies = { 'mfussenegger/nvim-dap' },
    opts = { enabled = true, clear_on_continue = true, virt_text_pos = 'eol' },
  },
  {
    'jay-babu/mason-nvim-dap.nvim',
    cmd = { 'DapInstall', 'DapUninstall' },
    dependencies = { 'williamboman/mason.nvim', 'mfussenegger/nvim-dap' },
    opts = { ensure_installed = { 'codelldb' }, automatic_installation = false, handlers = {} },
  },
}
