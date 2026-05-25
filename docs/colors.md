# Color Theme System Guide

壁纸 + Material You 取色 + 各组件配色的端到端管线。

## Installation

```bash
# 取色器(官方仓库 extra) + 命令行 JSON 工具
sudo pacman -S matugen jq

# 壁纸守护进程(AUR,awww 是 swww 改名延续,Provides: swww)
yay -S awww
```

## Linking the dotfile

```bash
# matugen 整目录链(config.toml + templates/ 全在这)
ln -sf ~/.dotfiles/matugen ~/.config/matugen

# setwall 脚本进 PATH
ln -sf ~/.dotfiles/scripts/setwall.sh ~/.local/bin/setwall
chmod +x ~/.dotfiles/scripts/setwall.sh
```

## Pipeline Overview

```
壁纸图片 (~/Pictures/Wallpapers/*.jpg)
    │ setwall <path>
    │
    ├─ awww img <path>                          → 屏幕显示壁纸,带 fade 过渡
    │
    └─ matugen image <path> --source-color-index 0
        │
        ├─→ ~/.local/state/quickshell/user/generated/colors.json
        │   (单一颜色源 —— Material You 全套 token)
        │
        └─→ 各模板的渲染产物:
            ├─ ~/.config/gtk-3.0/gtk.css      ← GTK3 应用消费
            ├─ ~/.config/gtk-4.0/gtk.css      ← GTK4 应用消费
            ├─ ~/.config/fuzzel/fuzzel_theme.ini  ← fuzzel 启动时读
            ├─ ~/.config/hyprlock/colors.conf ← hyprlock 锁屏读
            └─ (其它见 matugen/config.toml)

紧接着 setwall 自己再做一步:
    读 colors.json → 拼 ANSI 16 + bg/fg/cursor 的 OSC 序列
        │
        └─→ printf 到所有 /dev/pts/* → 活终端实时刷色
```

## Usage

```bash
setwall ~/Pictures/Wallpapers/1.jpg          # 切到指定图,默认 fade 过渡
setwall ~/Pictures/Wallpapers/1.jpg wipe     # wipe 过渡(还可:grow center wave)
setwall random                                # 从 ~/Pictures/Wallpaper 随机抽
```

## Consumers

读 `colors.json` 或 matugen 渲染产物的各组件:

| 组件 | 读什么 | 何时刷新 |
|---|---|---|
| `wezterm` | `colors.json`(在 wezterm.lua 里 `wezterm.json_parse`) | 自动监听文件变化,setwall 跑完自动重载 |
| `kitty` | OSC 4/10/11/12 序列 | 新 zsh 起手 + setwall 广播到 /dev/pts/* |
| `zsh`(交互终端) | `colors.json`(在 .zshrc 里 `jq` 解析后发 OSC) | 每次新 zsh 启动 |
| GTK3 应用 | `~/.config/gtk-3.0/gtk.css` | 应用重启才生效 |
| GTK4 应用 | `~/.config/gtk-4.0/gtk.css` | 应用重启才生效 |
| `fuzzel` | `~/.config/fuzzel/fuzzel_theme.ini`(`include` 进 `fuzzel.ini`) | 下次 fuzzel 启动 |
| `hyprlock` | `~/.config/hyprlock/colors.conf` | 下次锁屏 |
| 未来 qs shell | `colors.json` | 待建 |

## ANSI 16 Mapping

Material You 没有"绿/黄/紫"概念,所以 ANSI 16 色是按视觉协调度映射的(不严格语义):

| ANSI | 映射 | 备注 |
|---|---|---|
| 0 black | `surface_container_lowest` | 比 bg 略深 |
| 1 red | `error` | 严格,红=错误 |
| 2 green | `tertiary` | 实际可能是紫/橙 |
| 3 yellow | `secondary` | |
| 4 blue | `primary` | 多数主图通过 |
| 5 magenta | `tertiary_container` | |
| 6 cyan | `primary_container` | |
| 7 white | `on_surface` | |
| 8-15 bright | container / on_xxx / fixed 变体 | 见下方"三处同步" |

### 映射在三处定义,改一处要同步改另两处

```
~/.dotfiles/scripts/setwall.sh    bash 版本,setwall 广播用
~/.dotfiles/zsh-config/.zshrc      zsh 版本,启动时 emit
~/.dotfiles/wezterm/wezterm.lua    lua 版本,wezterm 自读
```

## Files

### matugen 配置 / 模板

```
~/.dotfiles/matugen/
├── config.toml                    # 模板注册表
└── templates/
    ├── colors.json                # → 渲染成 colors.json(消费者主入口)
    ├── gtk-3.0/gtk.css            # → ~/.config/gtk-3.0/gtk.css
    ├── gtk-4.0/gtk.css            # → ~/.config/gtk-4.0/gtk.css
    ├── fuzzel/fuzzel_theme.ini    # → ~/.config/fuzzel/fuzzel_theme.ini
    ├── hyprland/                  # legacy,留着无害
    ├── kde/                       # → ~/.local/state/quickshell/.../color.txt
    └── wallpaper.txt              # → ~/.local/state/.../wallpaper/path.txt
```

模板用 [Tera](https://keats.github.io/tera/docs/) 语法,变量是 `{{colors.<name>.default.hex}}`,完整 token 列表参见 matugen 源码或生成的 `colors.json`。

### 运行时产物(不进仓库)

```
~/.local/state/quickshell/user/generated/
├── colors.json               # 颜色 JSON(主消费入口)
├── color.txt                 # KDE 风格的 hex 列表
└── wallpaper/path.txt        # 当前壁纸路径
```

## Adding a New Consumer

需要让 X 应用跟着壁纸换色的两种做法:

### 方式 A:X 直接读 `colors.json`

如果 X 的配置语言支持读 JSON(像 wezterm.lua),首选这条 —— 一份事实来源,变化即刷新。

```lua
-- wezterm.lua 例
local colors = wezterm.json_parse(io.open(home..'/.local/state/.../colors.json'):read('*a'))
config.colors = { background = colors.background, ... }
wezterm.add_to_config_reload_watch_list(path_to_colors_json)
```

### 方式 B:给 matugen 加模板

如果 X 只能读特定格式的配置文件:

1. 在 `~/.dotfiles/matugen/templates/` 下新建 `xname/xfile.ext`,内容用 `{{colors.x.default.hex}}` 占位
2. 在 `~/.dotfiles/matugen/config.toml` 加段:
   ```toml
   [templates.x]
   input_path  = '~/.config/matugen/templates/xname/xfile.ext'
   output_path = '~/.config/xname/xfile.ext'
   ```
3. 跑一次 `setwall <current-wall>` 触发渲染验证

## Troubleshooting

| 症状 | 原因 / 修法 |
|---|---|
| kitty 起手颜色不对,setwall 后才对 | `.zshrc` 的 OSC 块必须在 p10k instant prompt **之前**;另:OSC 终止符要用 BEL,zsh 拼接吞 `\` |
| matugen 报 `Failed to get the input and output paths from hashmap` | 某个 `[templates.X]` 的 `input_path` 文件不存在,matugen 4.x 会整体 abort —— 注释掉那段或建出输入文件 |
| matugen 弹交互选色菜单 | matugen 4.x 行为,setwall 已加 `--source-color-index 0` 跳过;手动调时记得带这个 flag |
| 换壁纸后 wezterm 没刷新 | wezterm.lua 里 `wezterm.add_to_config_reload_watch_list(path)` 路径要对 |
| 换壁纸后 fuzzel 颜色没变 | fuzzel 启动时读一次 theme,关掉重开即可 |
| GTK 应用没变 | 重启应用,GTK 不监听配置文件 |
