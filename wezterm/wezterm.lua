-- 引入 wezterm 模块
local wezterm = require 'wezterm'
-- 创建配置对象 (新版 WezTerm 推荐写法)
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.enable_wayland = true

-- =========================================================
-- 🎨 颜值与外观 (Appearance)
-- =========================================================

-- 1. 配色方案
-- WezTerm 内置了 700+ 种配色，你可以在 https://wezfurlong.org/wezterm/colorschemes/index.html 查
-- 推荐：Catppuccin Mocha, Dracula, Tokyo Night, Nord, Gruvbox Dark Hard
config.color_scheme = 'Tokyo Night (Gogh)'
-- config.color_scheme = 'Sequoia Moonlight'

-- 2. 字体设置
-- 必须先安装 Nerd Fonts (sudo pacman -S ttf-jetbrains-mono-nerd)
config.font = wezterm.font('JetBrains Mono', { weight = 'Bold'})
config.font_size = 12.5
config.cell_width = 1.1

-- 3. 窗口背景透明与模糊
config.window_background_opacity = 0.85 -- 0.0 到 1.0，越小越透
-- 注意：Arch Linux 下需要你的合成器 (如 Picom 或 Hyprland) 支持背景模糊
-- macOS 用户自带模糊，Linux 用户通常只需设置透明度
-- config.background = {
--   {
--     source = {
--         File = "/usr/share/wallpapers/Altai/contents/images/5120x2880.png"
--     },
--     hsb = {
--         hue = 1.0,
--         saturation = 1.0,
--         brightness = 0.05,
--     },
--     opacity = 0.9,
--   },
-- }

-- 4. 去掉丑陋的顶部标题栏
-- "RESIZE" 允许你拖动边缘调整大小，但没有标题栏
-- config.window_decorations = "RESIZE"

-- 5. 标签栏样式
-- config.use_fancy_tab_bar = false -- 设为 false 使用更紧凑的传统样式
-- config.hide_tab_bar_if_only_one_tab = true -- 只有一个标签时隐藏标签栏，极致极简
config.enable_tab_bar = false

config.default_cursor_style = 'SteadyBar'

-- =========================================================
-- 🚀 性能与硬件 (Performance)
-- =========================================================
-- 显卡加速前端，通常选 WebGpu 或 OpenGL
config.front_end = "WebGpu"

-- =========================================================
-- ⌨️ 键位映射 (Keybindings) - 像 Tmux 一样使用
-- =========================================================
-- 定义 Leader Key (类似 Tmux 的前缀键)，这里设为 Ctrl+a
-- config.leader = { key = 'd', mods = 'ALT', timeout_milliseconds = 2000}

config.keys = {
  -- 1. 垂直分屏
  {
    key = ',',
    mods = 'ALT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- 2. 水平分屏
  {
    key = '.',
    mods = 'ALT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  -- 3. 关闭当前分屏
  {
    key = 'd',
    mods = 'ALT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- 4. 在分屏之间跳转
  { key = 'LeftArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },

  { key = 'c', mods = 'CTRL', action = wezterm.action.CopyTo 'Clipboard'},
  { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard'},
}

-- =========================================================
-- 🔧 其他实用设置
-- =========================================================
-- 启动时不检查更新 (Arch 包管理器会管)
config.check_for_updates = false
-- 禁用烦人的响铃声
config.audible_bell = "Disabled"

return config
