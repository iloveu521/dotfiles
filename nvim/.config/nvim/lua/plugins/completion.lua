return {
  { 'rafamadriz/friendly-snippets', lazy = true },
  {
    'saghen/blink.cmp',
    version = '1.*',
    event = 'InsertEnter',
    dependencies = { 'rafamadriz/friendly-snippets' },
    build = function() require('blink.cmp').build():pwait() end,
    opts = {
      keymap = {
        preset = 'enter',
        ['<M-i>'] = { 'select_prev', 'fallback_to_mappings' },
        ['<M-k>'] = { 'select_next', 'fallback_to_mappings' },
      },
      appearance = { nerd_font_variant = 'mono' },
      completion = {
        menu = { border = 'rounded' },
        documentation = { auto_show = true, auto_show_delay_ms = 250, window = { border = 'rounded' } },
      },
      signature = { enabled = true, window = { border = 'rounded' } },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      fuzzy = { implementation = 'rust' },
    },
    opts_extend = { 'sources.default' },
  },
}
