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
-- 直接读 matugen 的 colors.json,跟壁纸联动。读不到再退回到 Tokyo Night。
-- 这样无论 wezterm 是从 shell 起还是被 fuzzel/.desktop 直接拉起来,色板都一致。
local matugen_colors_path = os.getenv('HOME') .. '/.local/state/quickshell/user/generated/colors.json'

local function load_matugen_colors(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local content = f:read('*a'); f:close()
    local ok, parsed = pcall(wezterm.json_parse, content)
    if not ok or not parsed then return nil end
    -- 映射跟 ~/.dotfiles/scripts/setwall.sh / .zshrc 里那套保持一致
    return {
        background = parsed.background,
        foreground = parsed.on_background,
        cursor_bg  = parsed.primary,
        cursor_fg  = parsed.on_primary,
        cursor_border = parsed.primary,
        selection_bg = parsed.secondary_container,
        selection_fg = parsed.on_secondary_container,
        ansi = {
            parsed.surface_container_lowest or parsed.background, -- black
            parsed.error,                                          -- red
            parsed.tertiary,                                       -- green
            parsed.secondary,                                      -- yellow
            parsed.primary,                                        -- blue
            parsed.tertiary_container,                             -- magenta
            parsed.primary_container,                              -- cyan
            parsed.on_surface,                                     -- white
        },
        brights = {
            parsed.surface_container_low or parsed.surface,        -- bright black
            parsed.error_container,                                -- bright red
            parsed.on_tertiary_container or parsed.tertiary,       -- bright green
            parsed.on_secondary_container or parsed.secondary,     -- bright yellow
            parsed.on_primary_container or parsed.primary,         -- bright blue
            parsed.tertiary_fixed or parsed.tertiary,              -- bright magenta
            parsed.primary_fixed or parsed.primary,                -- bright cyan
            parsed.inverse_surface or parsed.on_background,        -- bright white
        },
    }
end

local matugen = load_matugen_colors(matugen_colors_path)
if matugen then
    config.colors = matugen
else
    config.color_scheme = 'Tokyo Night (Gogh)'
end

-- 让 wezterm 监听 colors.json 变化,setwall 换壁纸后自动重载
wezterm.add_to_config_reload_watch_list(matugen_colors_path)

-- 2. 字体设置
-- 必须先安装 Nerd Fonts (sudo pacman -S ttf-jetbrains-mono-nerd)
config.font = wezterm.font('Maple Mono NF CN', { weight = 'Bold' })
config.font_size = 12.5
config.cell_width = 1.1

-- 3. 窗口背景透明
config.window_background_opacity = 0.85 -- 0.0 到 1.0,越小越透

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
-- WebGpu 在 niri/wlroots 系合成器上有黑屏+无输入问题,固定用 OpenGL
config.front_end = "OpenGL"

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
    { key = 'LeftArrow',  mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = 'UpArrow',    mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'DownArrow',  mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },

    { key = 'c',          mods = 'ALT', action = wezterm.action.CopyTo 'Clipboard' },
    { key = 'v',          mods = 'ALT', action = wezterm.action.PasteFrom 'Clipboard' },
}

-- =========================================================
-- 🔧 其他实用设置
-- =========================================================
-- 启动时不检查更新 (Arch 包管理器会管)
config.check_for_updates = false
-- 禁用烦人的响铃声
config.audible_bell = "Disabled"

return config
