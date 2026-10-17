--[[
plugins/xml.lua — URDF / Xacro 的 XML 编辑支持

用途：
  * 把 .urdf 与 .xacro 文件识别为 XML；
  * 自动闭合 XML 标签，并在修改标签名时同步另一端。

XML 高亮与 LSP 分别复用 plugins/treesitter.lua 和 plugins/lsp.lua，避免重复配置。
]]

local function register_filetypes()
  vim.filetype.add({
    extension = {
      urdf = 'xml',
      xacro = 'xml',
    },
  })
end

return {
  {
    'windwp/nvim-ts-autotag',
    ft = { 'xml' },
    init = register_filetypes,
    opts = {},
  },
}
