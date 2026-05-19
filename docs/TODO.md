# TODO —— Hyprland / illogical-impulse → niri 迁移

## 第一步:审计当前实际安装了什么

权威的安装清单在 pacman 里,不在本仓库。在 Arch 机器上跑:

```bash
# 所有「手动安装」的包(不含被依赖带进来的)
pacman -Qqe

# illogical-impulse 安装器在 Arch 上把依赖打包成了 illogical-impulse-* 元包,
# 这条能一眼看出 ii 给你装了哪些组(最有用)
pacman -Qqe | grep -i illogical

# 跟本次迁移相关的包
pacman -Qqe | grep -iE 'hypr|quickshell|matugen|fcitx|portal|pipewire|wlogout|fuzzel|cliphist'

# 查某个包为什么被装、被谁依赖
pacman -Qi <包名>
```

> 把 `grep illogical` 的结果贴回来,我可以帮你逐个判断该留该删。

---

## 包清单(按迁移处理方式分类)

> ⚠️ 以下是根据本仓库配置文件 + ii 已知依赖**推断**的,不是精确安装记录。
> 以上面 pacman 审计结果为准。

### A. 保留 —— 与合成器无关,niri 下照用

| 包 | 用途 |
|---|---|
| `quickshell` | 你要在它上面做自己的 shell |
| `matugen` | Material You 取色 |
| `pipewire` `wireplumber` `pavucontrol` | 音频 |
| `easyeffects` | 音频效果 |
| `cliphist` `wl-clipboard` | 剪贴板历史 |
| `fuzzel` | 应用启动器 / dmenu |
| `wlogout` | 会话菜单 |
| `hypridle` `hyprlock` `hyprpicker` | 空闲管理 / 锁屏 / 取色(都基于通用协议,niri 可用) |
| `fcitx5` + 输入法插件(`fcitx5-chinese-addons` 等) | 输入法 |
| `networkmanager` `nm-connection-editor` | 网络 |
| `bluez` `blueberry` | 蓝牙 |
| `brightnessctl` `playerctl` | 亮度 / 媒体控制 |
| `grim` `slurp` `tesseract` `tesseract-data-*` | OCR 用(niri 截图虽内置,OCR 仍走 grim+slurp) |
| `gnome-keyring` | 密钥环 |
| `polkit-kde-agent` | 提权弹窗(也可换别的 polkit agent) |
| `geoclue` | 天气定位 |
| `xdg-desktop-portal` `xdg-desktop-portal-kde` `xdg-desktop-portal-gtk` | portal + 文件选择器(ii 用的是 kde 后端) |
| Bibata 光标主题(`bibata-cursor-theme`,AUR) | 鼠标指针 |
| Material / Google 字体包 | hyprbars/shell 用的字体 |

### B. niri 专属 —— 需新装

| 包 | 用途 |
|---|---|
| `niri` | 合成器本体 |
| `xwayland-satellite` | niri 不自带 Xwayland,靠它跑 X11 程序 |
| `xdg-desktop-portal-gnome` | niri 推荐的截图/录屏 portal 后端(替代 hyprland 后端) |
| `wlsunset`(或 `sunsetr`,AUR) | 蓝光滤镜,替代 hyprsunset |

### C. 需替换

| 原(Hyprland) | 换成 |
|---|---|
| `xdg-desktop-portal-hyprland` | → `xdg-desktop-portal-gnome` |
| `hyprsunset` | → `wlsunset` / `sunsetr` |
| `hyprshot` | → niri 内置截图(可直接卸 hyprshot) |

### D. 可卸载 —— Hyprland 专属

| 包 | 说明 |
|---|---|
| `hyprland` | 合成器本体,被 niri 取代 |
| `xdg-desktop-portal-hyprland` | 见 C |
| `hyprshot` `hyprsunset` | 见 C |
| Hyprland 插件(hyprbars / hyprscrolling) | 经 hyprpm 安装,niri 无插件系统;niri 原生就是滚动平铺 |
| `nwg-displays` | Hyprland/sway 的显示器配置工具,niri 用 `niri msg outputs` |

> 建议:迁移完全跑通、确认不回退 Hyprland 之前,**先别急着卸 D 类**,留着双保险。

---

## 其他待办(非包相关,串一下之前讨论的)

- [ ] 进 niri 后用 `niri msg outputs` 校准 `outputs.kdl` 里显示器的 `mode` 刷新率
- [ ] 写 `~/.config/xdg-desktop-portal/portals.conf`,把 `FileChooser` 指向 kde 后端
- [ ] 用 `niri msg windows` 核对 `rules.kdl` 里文件对话框 / pavucontrol 等的 app-id / title
- [ ] 第 2 步:写 `Niri.qml`(读 niri IPC 的服务,替代 `HyprlandData.qml`)
- [ ] 搭自己的 Quickshell shell,建好后:
  - [ ] `startup.kdl` 加 `spawn-at-startup` 启动它
  - [ ] `binds.kdl` 里 `Mod+Slash`/`Mod+V`/`Mod+Period` 等改成 `qs ipc call ...`
  - [ ] `rules.kdl` 末尾的 `layer-rule` 模板填上 shell 的 namespace
- [ ] matugen:删 `[templates.hyprland]`/`[templates.hyprlock]`,改为渲染 niri 的 `colors.kdl` 片段
- [ ] ii 的 Python venv(`ILLOGICAL_IMPULSE_VIRTUAL_ENV`):自建 shell 后大概率不再需要
- [ ] 迁移跑通后清理 `hypr/` 目录(只 `hypridle.conf` / `hyprlock.conf` 还有用)
