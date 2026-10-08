--[[
lua/plugins/ros.lua — 用 init 把 ROS 2 的缓冲区级快捷键尽早挂上

用途：这是一个「借壳」spec —— 唯一的动作是在插件加载前调用 core.ros.setup()，
让 ROS 相关的缓冲区局部键位（<leader>rb 构建、<leader>rt 测试、<leader>rs 已 source 环境的 shell、
<leader>rc 刷新编译数据库、<leader>rr 运行可执行文件）能在打开文件的瞬间就可用。
加载时机：为什么只用 init 而不用 config？lazy.nvim 在启动处理 spec 时就会执行 init，
而 config 要等插件本体真正加载后才跑。ROS 映射必须依附 BufReadPost / BufNewFile 自动命令，
且要在用户打开任意文件时就已注册，不能拖延到 toggleterm 被加载的那一刻，所以 init 是唯一正确的钩子。
在配置中的地位：ROS 支持的最小粘合层，本身不含插件配置；与 lua/plugins/terminal.lua 声明同一个插件名，
lazy.nvim 会按插件名把两条 spec 合并，于是这里只需补充 init，opts / config / keys 全部沿用那一份。
]]

return {
  {
    'akinsho/toggleterm.nvim',
    -- core.ros.setup() 注册 BufReadPost / BufNewFile 自动命令，回调里用 core.project.current(buf)
    -- 判断该缓冲区是否属于 ROS 工作区或包，只在是的时候挂上缓冲区级映射；
    -- ROS 的构建 / 测试 / 运行最终都落到 toggleterm 终端上（见 core.ros.build / shell / run），
    -- 但映射的可用性与插件是否已加载无关，因此放在 init 里最合适。
    init = function() require('core.ros').setup() end,
  },
}
