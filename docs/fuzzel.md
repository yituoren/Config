# Fuzzel Configuration Guide

## Linking the dotfile

```bash
ln -sf ~/.dotfiles/fuzzel/fuzzel.ini ~/.config/fuzzel/fuzzel.ini
```

`fuzzel_theme.ini` 是 matugen 渲染的产物,不进仓库,留在 `~/.config/fuzzel/`。

## Configuration

```ini
include="~/.config/fuzzel/fuzzel_theme.ini"   # matugen 颜色
font=Maple Mono NF CN:weight=medium
terminal=wezterm start --                     # 起 Terminal=true 的 .desktop
prompt=">>  "
layer=overlay

[border]
radius=17
width=1

[dmenu]
exit-immediately-if-empty=yes
```

### `terminal=` 字段

整段当成**前缀**,fuzzel 把 .desktop 的 Exec 命令直接拼在后面,不自动加 `-e`。

| 值 | 实际执行(以 `yazi` 为例) |
|---|---|
| `xterm -e`(默认) | `xterm -e yazi` |
| `kitty -1` | `kitty -1 yazi` |
| `wezterm start --` | `wezterm start -- yazi` |
| `wezterm -e` | `wezterm -e yazi` |

### `font=` 字段

格式 `家族:weight=...:size=...`。查可用家族:

```bash
fc-list | grep -i maple
```

### `layer=` 字段

`background < bottom < top < overlay`,fuzzel 默认 `overlay` 保证总能弹出。

## niri Integration

`~/.dotfiles/niri/rules.kdl` 给 fuzzel 加背景模糊:

```kdl
layer-rule {
    match namespace="^launcher$"
    background-effect { blur true }
}
```

fuzzel 的 layer-shell namespace 写死叫 `launcher`。验证 fuzzel 实际 namespace:

```bash
# 弹起 fuzzel 后另一个终端跑
niri msg layers
```

## Launch Modes

| 入口 | 模式 |
|---|---|
| niri `Mod+Space` → `spawn "fuzzel"` | 普通(扫 .desktop) |
| niri `Mod+V` → `cliphist list \| fuzzel --dmenu \| ...` | dmenu(从 stdin 读条目) |
