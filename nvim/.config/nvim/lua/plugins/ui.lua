local function project_label()
  local context = require('core.project').current()
  local icons = {
    standalone = '󰈙',
    cpp = '',
    cmake = '',
    ros_package = '󰏗',
    ros_workspace = '󰒍',
  }
  local name = context.package_name or vim.fs.basename(context.root)
  return string.format('%s %s', icons[context.kind] or '󰘬', name)
end

return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    lazy = false,
    opts = {
      flavour = 'mocha',
      transparent_background = true,
      float = { transparent = false, solid = false },
      color_overrides = {
        mocha = {
          base = '#11111b',
          mantle = '#0d0d16',
          crust = '#080811',
          mauve = '#b4a0ff',
          purple = '#c6a0f6',
          teal = '#5de4c7',
          green = '#5de4c7',
          blue = '#89b4fa',
          sapphire = '#74c7ec',
        },
      },
      custom_highlights = function(colors)
        return {
          Normal = { bg = 'NONE' },
          NormalNC = { bg = 'NONE' },
          SignColumn = { bg = 'NONE' },
          EndOfBuffer = { bg = 'NONE' },
          WinSeparator = { fg = colors.surface1, bg = 'NONE' },
          FloatBorder = { fg = colors.mauve, bg = colors.mantle },
          NormalFloat = { bg = colors.mantle },
          GitSignsAdd = { fg = colors.teal },
          DiagnosticOk = { fg = colors.teal },
          DapStopped = { fg = colors.teal, bold = true },
        }
      end,
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      vim.cmd.colorscheme('catppuccin-mocha')
    end,
  },
  { 'nvim-tree/nvim-web-devicons', lazy = true },
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = {
        theme = 'catppuccin-mocha',
        globalstatus = true,
        component_separators = { left = '│', right = '│' },
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { { project_label, _project_component = true }, 'encoding', 'filetype' },
        lualine_y = { 'progress' },
        lualine_z = { 'location' },
      },
    },
  },
  {
    'akinsho/bufferline.nvim',
    version = '*',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = { options = { diagnostics = 'nvim_lsp', separator_style = 'slant' } },
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = { preset = 'modern', win = { border = 'rounded' } },
  },
  { 'MunifTanjim/nui.nvim', lazy = true },
  {
    'rcarriga/nvim-notify',
    lazy = true,
    opts = { background_colour = '#11111b', render = 'compact', stages = 'fade_in_slide_out' },
  },
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = { 'MunifTanjim/nui.nvim', 'rcarriga/nvim-notify' },
    opts = {
      presets = { command_palette = true, long_message_to_split = true, lsp_doc_border = true },
      views = { hover = { border = { style = 'rounded' } }, popupmenu = { border = { style = 'rounded' } } },
    },
  },
}
