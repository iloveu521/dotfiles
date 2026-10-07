local excluded = {
  ['neo-tree'] = true,
  TelescopePrompt = true,
  toggleterm = true,
  terminal = true,
  help = true,
  dashboard = true,
  aerial = true,
  lazy = true,
  mason = true,
  notify = true,
  noice = true,
}

return {
  {
    'shellRaining/hlchunk.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      chunk = {
        enable = true,
        use_treesitter = true,
        delay = 0,
        duration = 0,
        straight = true,
        max_file_size = 1024 * 1024,
        chars = {
          horizontal_line = '─',
          vertical_line = '│',
          left_top = '┌',
          left_bottom = '└',
          right_arrow = '─',
        },
        style = {
          { fg = '#b4a0ff' },
          { fg = '#f38ba8' },
        },
        exclude_filetypes = excluded,
      },
      indent = {
        enable = true,
        use_treesitter = false,
        chars = { '│' },
        style = { '#313244' },
        delay = 80,
        exclude_filetypes = excluded,
      },
    },
  },
  {
    'HiPhish/rainbow-delimiters.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    main = 'rainbow-delimiters.setup',
    opts = {
      highlight = {
        'RainbowDelimiterBlue',
        'RainbowDelimiterViolet',
        'RainbowDelimiterCyan',
        'RainbowDelimiterGreen',
      },
    },
    config = function(_, opts)
      local colors = {
        RainbowDelimiterBlue = '#89b4fa',
        RainbowDelimiterViolet = '#b4a0ff',
        RainbowDelimiterCyan = '#74c7ec',
        RainbowDelimiterGreen = '#5de4c7',
      }
      for group, color in pairs(colors) do
        vim.api.nvim_set_hl(0, group, { fg = color })
      end
      require('rainbow-delimiters.setup').setup(opts)
    end,
  },
}
