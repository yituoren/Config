# Quickshell

`quickshell/mine/` 是自建 shell;`quickshell/ii/` 是 illogical-impulse 的实现,留作参考不启动。

## Architecture

仿 [caelestia-dots/shell](https://github.com/caelestia-dots/shell) 的 ContentWindow 模式:每屏一个全屏 layer-shell `PanelWindow`(`modules/drawers/ContentWindow.qml`)装下 bar + popup + 全屏 scrim。bar 跟 popup 在同一 scene graph,自编 `Caelestia.Blobs` C++ plugin 用 SDF cubic smin 做 metaball 融合 —— 它俩靠近时平滑合并成一坨"挖凹槽"视觉。

`PopupManager`(Singleton)是 popup 状态唯一来源:`currentPopup` / `anchorX` / `openAmount` / `triggerRelativeX` / `animatedAnchorX` / `displayWidth` 等都在它身上,bar 跟 popup 都派生几何。

更深的细节见 `CLAUDE.md` 里的 "shell 架构" 那节。

## Caelestia.Blobs Plugin

源码在 `~/.dotfiles/caelestia-blobs/`,从 caelestia-dots/shell 的 Blobs 子模块原样移植(5 个 .cpp + 5 个 .hpp + 2 个 GLSL shader,只依赖 Qt6/Quick,不拖 Caelestia 别的 config)。

### Build & Install

```bash
yay -S cmake qt6-base qt6-shadertools qt6-declarative

cd ~/.dotfiles/caelestia-blobs
mkdir -p build && cd build
cmake ..
make -j
make install   # → ~/.local/share/qt6/qml/Caelestia/Blobs/(用户级,不需要 sudo)
```

验证:

```bash
ls ~/.local/share/qt6/qml/Caelestia/Blobs/
# libcaelestia-blobs.so  libcaelestia-blobsplugin.so  qmldir  caelestia-blobs.qmltypes
```

### Iterating

改 C++ 或 GLSL 后必须重 build + install + 重启 qs(plugin .so 是启动时一次性加载,QML 热重载不会重载 native code):

```bash
cd ~/.dotfiles/caelestia-blobs/build && make && make install
pkill -f "qs.*mine"
QML_IMPORT_PATH="$HOME/.local/share/qt6/qml" qs -p ~/.config/quickshell/mine -d
```

(从 niri 自动起的 qs 会从 niri 进程继承 `QML_IMPORT_PATH`,手动起的要自己带上)

## QML Module Path

Qt 默认只搜 `/usr/lib/qt6/qml`。装到用户级 `~/.local/share/qt6/qml/` 必须靠环境变量让 Qt / Quickshell 看到。`niri/environment.kdl` 里写死了:

```kdl
QML_IMPORT_PATH "/home/yituoren/.local/share/qt6/qml"
QML2_IMPORT_PATH "/home/yituoren/.local/share/qt6/qml"
```

值是字面字符串,**换机器换用户名时改成自己的家目录绝对路径**。niri 不展开 `$HOME`。

## Autostart

`niri/startup.kdl` 里:

```kdl
spawn-at-startup "qs" "-p" "/home/yituoren/.config/quickshell/mine" "-d"
```

niri 进程启动时 spawn,子进程继承 niri 的环境(包含上面的 `QML_IMPORT_PATH`)。改了 startup.kdl 要**重启 niri** 才让新的 spawn 生效 —— 已经运行的 qs 不会被替换。

`~/.config/quickshell/mine` 是符号链接指向 `~/.dotfiles/quickshell/mine/`。

## Verify

```bash
# qs 跑着吗
pgrep -fa "qs.*mine"

# layer surface 出现了吗(每屏一个 mine-shell)
niri msg layers | grep mine-shell

# 找最新的 qs log
LATEST_LOG=$(ls -t /run/user/1000/quickshell/by-id/*/log.log | head -1)
tail -20 "$LATEST_LOG"
# 看 "Configuration Loaded",别看到 "module Caelestia.Blobs is not installed"
```

## Quickshell ABI Compatibility

Arch 的 `quickshell-git` 包是预编译的;系统 Qt 升级后 quickshell 没跟着 rebuild 会有 ABI 不匹配。看 qs log 开头如果:

```
WARN: Quickshell was built against Qt 6.X but the system has updated to Qt 6.Y
```

就跑 `yay -S quickshell-git` 强制重装。我自编的 `caelestia-blobs` plugin 是用系统当前 Qt 编的,跟 qs 要 ABI 一致才稳。

## Hot-Reload Gotchas

- 编辑器(neovim / zed / 等)直接保存 QML 文件 → qs 通过 inotify 热重载
- **Claude Edit 工具 / 其它原子写工具 → 必须紧跟 `touch <file>`**。Edit 走原子替换换 inode,inotify 监听挂在老 inode 上接不到 MODIFY 事件。`touch` 不换 inode,补一个事件触发 reload
- C++ plugin 改了不能热重载,见上面 "Iterating"
