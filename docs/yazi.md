# Yazi Configuration Guide

## Installation

```bash
yay -S yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide resvg imagemagick
```

| 依赖 | 用途 |
|---|---|
| `ffmpeg` | 视频/音频缩略图 |
| `7zip` | 解/压缩 7z/zip/rar |
| `jq` | JSON 预览 |
| `poppler` | PDF 预览 |
| `fd` | 文件名搜索后端(`s` 键) |
| `ripgrep` | 内容搜索后端(`S` 键) |
| `fzf` | 模糊跳转(`Z` 键) |
| `zoxide` | 智能跳转(`z` 键) |
| `resvg` | SVG 预览 |
| `imagemagick` | 其它图像格式预览 |

## Default File Manager

```bash
# 系统默认文件管理器(inode/directory 走 yazi.desktop)
xdg-mime default yazi.desktop inode/directory
```

niri `Mod+E` 键绑(`~/.dotfiles/niri/binds.kdl`):

```kdl
Mod+E { spawn "kitty" "--class" "yazi" "yazi"; }
```

## Key Bindings

### 移动

| 键 | 动作 |
|---|---|
| `h` / `j` / `k` / `l` 或方向键 | 上一级 / 下 / 上 / 进入 |
| `gg` / `G` | 顶部 / 底部 |
| `Ctrl+u` / `Ctrl+d` | 上 / 下翻半页 |
| `Ctrl+b` / `Ctrl+f` | 上 / 下翻整页 |
| `K` / `J` | 预览面板内滚动 |
| `Tab` | 切换 peek 大小 |

### 选择

| 键 | 动作 |
|---|---|
| `Space` | 切换当前项选中 |
| `v` / `V` | 可视选择 / 反选可见项 |
| `Ctrl+a` / `Ctrl+r` | 全选 / 反选所有 |
| `Esc` | 取消选择 / 退出模式 |

### 文件操作

| 键 | 动作 |
|---|---|
| `y` / `x` / `p` | 复制 / 剪切 / 粘贴 |
| `P` | 强制粘贴(覆盖) |
| `d` / `D` | 移入回收站 / **永久删除** |
| `a` | 新建(以 `/` 结尾即建目录) |
| `r` | 重命名 |
| `;` / `:` | 非阻塞 / 阻塞 shell |

### 打开 / 跳转

| 键 | 动作 |
|---|---|
| `Enter` / `o` | 用默认程序打开 |
| `O` | 弹"用什么打开"菜单 |
| `z` / `Z` | zoxide / fzf 跳转 |
| `:cd <path>` | 直接跳转 |

### 搜索

| 键 | 动作 |
|---|---|
| `f` / `F` | 当前目录文件名查找 / 上一个 |
| `s` / `S` | `fd` 文件名 / `rg` 内容全局搜索 |
| `/` / `n` / `N` | 输入框搜索 / 下个 / 上个 |

### 标签 / 书签

| 键 | 动作 |
|---|---|
| `t` / `T` | 新建 / 关闭标签 |
| `1`–`9` | 切到第 N 个 |
| `[` / `]` | 前 / 后标签 |
| `{` / `}` | 把当前标签往左 / 右挪 |
| `m` / `'`+字母 | 新建 / 跳到书签 |
| `b` / `B` | 列出 / 删除书签 |

### 排序 / 显示 / 其它

| 键 | 动作 |
|---|---|
| `,` | 排序菜单 |
| `.` / `-` | 切换显隐文件 |
| `w` | 任务管理器 |
| `Ctrl+n` / `Ctrl+d` / `Ctrl+c` | 拖出 / 跟软链 / 复制路径 |
| `q` / `Q` | 退出(保存 cwd / 不保存) |
| `?` | 当前键位帮助 |

## Shell Integration

退出后留在 yazi 最后所在目录,`.zshrc` 加:

```zsh
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
```

之后用 `y` 替代 `yazi` 启动。

## Configuration Files

| 文件 | 作用 |
|---|---|
| `~/.config/yazi/yazi.toml` | 主配置 |
| `~/.config/yazi/keymap.toml` | 键位重映射 |
| `~/.config/yazi/theme.toml` | 配色 |
| `~/.config/yazi/init.lua` | 启动脚本 / 插件 |
