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

## 杂项收尾(非 shell 相关)

- [x] 进 niri 后用 `niri msg outputs` 校准 `outputs.kdl` 里显示器的 `mode` 刷新率
- [x] 写 `~/.config/xdg-desktop-portal/niri-portals.conf`(轻量方案:全部走 gtk,Secret 走 gnome-keyring)
- [ ] 用 `niri msg windows` 核对 `rules.kdl` 里文件对话框 / pavucontrol 等的 app-id / title
- [ ] matugen:删 `[templates.hyprland]`/`[templates.hyprlock]`,改为渲染 niri 的 `colors.kdl` 片段(focus-ring 等想跟壁纸取色时用)
- [ ] ii 的 Python venv(`ILLOGICAL_IMPULSE_VIRTUAL_ENV`):自建 shell 后大概率不再需要
- [ ] 迁移跑通后清理 `hypr/` 目录(只 `hypridle.conf` / `hyprlock.conf` 还有用)

---

# 主线:从零搭自己的 Quickshell shell

## 心智模型先建好

读这一节再动手 —— 不然容易陷进 ii 的细节里出不来。

- **Quickshell ≠ DE,它只是一个跑 QML 的 wayland layer-shell 宿主**。所有可视元素(bar/overview/launcher 等)都是你画的 QML 窗口,挂在合成器的 layer-shell 上。
- **ii 是一份"参考实现",不是基类**。它的 ~30 个模块 + ~25 个 services 都耦合 hyprctl/`Quickshell.Hyprland`。你的目标是**抄思路、自己重写**,不是 fork 改。
- **ii 大致可以拆成三层**,只有最底层需要重做:
    - 顶层:UI 模块(bar/overview/dock/...)→ **可借鉴**,贴回去稍改即可
    - 中层:services(MprisController/Audio/Notifications/...)→ **大部分跟合成器无关,可直接抄**
    - 底层:`HyprlandData.qml` + `Quickshell.Hyprland` 调用 → **必须替换成 niri 版本**
- **niri IPC 的形态完全不同**:
    - hyprland:socket(`hyprctl ...` + `socat $HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`)
    - niri:JSON over `niri msg --json <cmd>` + 长连接事件流 `niri msg event-stream --json`
    - 事件流是行分隔的 JSON,每行一个事件(`WorkspacesChanged` / `WindowsChanged` / `WindowFocusChanged` 等)。这是兼容层的核心数据源。

## 工具链 / 开发循环

- [ ] 项目放在 `~/.dotfiles/quickshell/mine/`(随便起个名),软链到 `~/.config/quickshell/mine/`
- [ ] `shell.qml` 作为入口,跟 ii 的 `shell.qml` 同形(`ShellRoot { PanelLoader { ... } }`)
- [ ] 开发态运行:`qs -p ~/.config/quickshell/mine`(改文件即热重载,~1s)
- [ ] 早开 logging:`qs -p ... 2>&1 | tee /tmp/qs.log`,QML 报错才找得到
- [ ] 一开始就把 git 历史接上,出现"昨天还好今天瞎了"时能 `git diff`

## 阶段 0 —— 骨架(目标:屏幕上能看到一个矩形)

- [ ] 写最小 `shell.qml`:`ShellRoot { PanelWindow { anchors.top: true; height: 32; color: "#80000000" } }`
- [ ] 跑起来,看到屏幕顶端一条半透明黑条 → 你已经在 niri 上跑通 qs 了
- [ ] niri 给你的 namespace 加 layer-rule:
    ```kdl
    layer-rule {
        match namespace="^mine-.*$"
        background-effect { blur true }
    }
    ```
    在 PanelWindow 里 `WlrLayershell.namespace: "mine-bar"` 之类设定 namespace,让 blur 能 match 到。
- [ ] 第一个能跑的 IPC:`IpcHandler { target: "test"; function ping(): void { console.log("hi") } }`
      → 在外部跑 `qs ipc call test ping`,日志里看到 "hi"。打通了你后面替换 niri 快捷键就靠这个。

## 阶段 1 —— 兼容层(最硬的活,先难后易)

写 `services/Niri.qml`,定位等同于 ii 的 `HyprlandData.qml`,**对外接口**尽量贴近(后面抄 ii 模块时改动小)。

- [ ] 暴露响应式属性:
    - `windows: list<var>`(每项至少含 id/title/app_id/workspace_id/is_focused)
    - `workspaces: list<var>`(id/idx/name/output/is_active/is_focused)
    - `focusedWindowId: int`
    - `activeWorkspaceId: int`
    - `outputs: list<var>`
- [ ] 数据来源(冷启动用):
    - `niri msg --json windows`
    - `niri msg --json workspaces`
    - `niri msg --json focused-output`
- [ ] 事件订阅(热更新用):后台跑 `niri msg event-stream --json`,用 `Quickshell.Io.Process` + `SplitParser{ splitMarker: "\n" }` 接收每行 JSON,按事件类型 patch 上面属性
    - 不要每次事件来都重新拉一遍全量,niri 已经把变化都打在事件里了
- [ ] 暴露 dispatch 方法封装:`function focusWorkspace(id) { Process { command: ["niri", "msg", "action", "focus-workspace", id.toString()] }.startDetached() }`
- [ ] 同样封装:`closeWindow / focusWindow / moveWindowToWorkspace / spawn`(几个 ii overview 一定要用的)
- [ ] **测试通过的标准**:写个临时小 panel,把 `Niri.workspaces` 渲染成一排小方块,active 高亮 —— 切工作区时实时变 → 兼容层就活了

> 这一步如果做扎实,后面所有 UI 模块的成本都会显著降低。

## 阶段 2 —— 主题管线(matugen → QML)

- [ ] 在 `~/.config/matugen/config.toml` 加一个模板,渲染 QML 友好的颜色文件(JSON 即可):
    ```toml
    [templates.qml_colors]
    input_path  = '~/.config/matugen/templates/qml/colors.json'
    output_path = '~/.local/state/quickshell/mine/colors.json'
    ```
- [ ] 写 `services/Theme.qml` 单例,`FileView { path: ".../colors.json"; onContentChanged: parse() }`,暴露 `primary` / `surface` / `onSurface` 等
- [ ] 所有模块**只**通过 `Theme.xxx` 拿颜色,**不允许写死 hex**(只有需要 fallback 时写)
- [ ] 换壁纸 → matugen 重新生成 → FileView 检测到变化 → 整个 shell 颜色滚动刷新。这是 ii 给你的"魔法感"的源头

## 阶段 3 —— 核心三件套(决定能否日用)

按这个顺序,**不要并行做**。每个模块做到"能用"就停,polish 留到阶段 5。

1. **Bar** —— 状态栏
    - [ ] 工作区指示器:从 `Niri.workspaces` 渲染,点击调 `Niri.focusWorkspace(id)`
    - [ ] 时钟:`services/DateTime.qml`(ii 原版可直接拿)
    - [ ] 系统托盘:`Quickshell.Services.SystemTray.SystemTrayItem`(qs 内置,跟合成器无关)
    - [ ] 音量/电量指示:ii 的 `services/Audio.qml` / `Battery.qml` 直接抄
    - 验收:能完全替代你脑中的"上面那一条"

2. **Launcher** —— 替代 fuzzel
    - [ ] `services/AppSearch.qml`:扫 `/usr/share/applications/**/*.desktop`,模糊匹配(ii 原版抄)
    - [ ] UI:一个 PanelWindow,中间一个 TextField + ListView 展示结果
    - [ ] IpcHandler 暴露 `launcher.toggle()`,niri `binds.kdl` 里 `Mod+Space { spawn-sh "qs ipc call launcher toggle"; }` 替换 fuzzel
    - 验收:能完全替代 fuzzel,且看上去顺眼

3. **Overview** —— 工作区总览
    - [ ] 每个工作区一格,格子内画该工作区的窗口缩略代理(用 `Niri.windows` 中该 ws 的窗口 list 渲染矩形即可,**不必真截图**)
    - [ ] 点格子调 `Niri.focusWorkspace`,拖窗调 `Niri.moveWindowToWorkspace`
    - [ ] 跟 launcher 共用一个 PanelWindow,合成 ii 那种"一键弹出工作区+应用"的统一面板
    - 验收:Mod+Tab(或你自定义键)弹出能用

> **到这里你的 shell 已经"能日用"。后面所有都是锦上添花。**

## 阶段 4 —— 周边模块(按用得多到少补)

- [ ] OSD:音量/亮度调节时的弹出条 —— `services/Audio.qml` + 一个会自动淡出的 PanelWindow
- [ ] 通知中心:`Quickshell.Services.Notifications`(qs 内置 freedesktop notification daemon)+ ii 的 popup UI
- [ ] SidebarRight:wifi/蓝牙/音频/媒体控制集合面板 —— ii 内容最多的模块,慢慢抄
- [ ] Polkit:`PolkitAgent {}`(qs 内置)+ 简单密码输入框,装完可以卸掉 `polkit-kde-agent`
- [ ] Cheatsheet:Mod+/ 弹出快捷键列表(niri 自带一个但样式跟 shell 不统一)
- [ ] WallpaperSelector:thumbnail 网格 + 切换时调 matugen
- [ ] Dock(可选,你之前在 hyprland 上没怎么用)

## 阶段 5 —— "好看且丝滑"的那一层(决定主观体验)

ii 给你的视觉冲击 80% 来自下面这些细节,**逐项打勾**:

### 5.1 形与光

- [ ] 所有面板 PanelWindow 半透明(背景 alpha ~0.65),靠 niri layer-rule 模糊撑底色
- [ ] 圆角:`Rectangle.radius` + 子内容用 `clip: true` 或 `OpacityMask` 裁
- [ ] 阴影:`import Qt5Compat.GraphicalEffects` 的 `DropShadow`,**只对静态层加**(动的时候关掉,贵)
- [ ] 边框:1px `border.color: Qt.rgba(255,255,255,0.06)`,在亮背景下显出"玻璃感"
- [ ] 全局留白比你直觉的大一点 —— ii 看着不挤就因为它内边距 12~16px 起步

### 5.2 动效(最影响"丝滑感")

- [ ] 用 Material 3 标准 easing,不用 Qt 默认的 OutCubic:
    - 标准曲线:`cubicBezier(0.2, 0, 0, 1)`,时长 ~300ms
    - Emphasized(强调,Bar/Launcher 弹出用):`cubicBezier(0.05, 0.7, 0.1, 1)`,时长 ~400-500ms
- [ ] 所有"出现/消失"都过渡(opacity + scale 0.95→1 + translateY),不要直接 visible 切换
- [ ] 工作区指示器宽度变化用 `Behavior on width { NumberAnimation { duration: 200; easing.bezierCurve: ... } }`
- [ ] 启用器 ListView 项之间用 `add/displaced Transition`,不要硬切
- [ ] **关键禁忌**:不要全屏 `layer.enabled: true` + 实时滤镜,会卡。`MultiEffect` 比 `GraphicalEffects.*` 现代且便宜,优先用

### 5.3 字与图标

- [ ] 字体:`Google Sans` / `Inter` / `Geist`(ii 默认 Google Sans Flex)用作 UI 字体
- [ ] 图标字体:`Material Symbols Rounded`(可变字重),`Text { font.family: "Material Symbols Rounded"; text: "settings" }` 比 SVG 轻得多
- [ ] 行高:`lineHeight: 1.4` 起步,别让文字粘成一块

### 5.4 性能 / 别让它卡

- [ ] 所有 panel 用 `LazyLoader`(ii 的写法),按需创建,不要一启动就全实例化
- [ ] 大列表用 `ListView` 不要 `Repeater`(后者全量保留 item)
- [ ] 单例服务的 Process / 文件订阅**只在需要时启动**,Idle 时停掉
- [ ] niri event-stream 解析放 service 单例,不要每个模块各自启一个 Process

## 阶段 6 —— 与 niri 配置接合

shell 跑稳后再回头改 niri 配置:

- [ ] `startup.kdl`:`spawn-at-startup "qs" "-c" "mine"`(qs 自动从 `~/.config/quickshell/mine/` 加载)
- [ ] `rules.kdl` 启用 layer-rule 模板,namespace 填 `^mine-.*$`(或你 PanelWindow 里设定的)
- [ ] `binds.kdl` 替换三件:
    - `Mod+Space { spawn "fuzzel"; }` → `Mod+Space { spawn-sh "qs ipc call launcher toggle"; }`(可以保留 fuzzel 作 fallback)
    - `Mod+V { spawn-sh "cliphist list | fuzzel ..."; }` → 自己实现 cliphist UI 后改 qs ipc
    - `Ctrl+Alt+Delete { spawn "wlogout"; }` → 自己实现 sessionScreen 后改 qs ipc
- [ ] `Mod+Tab` 是否保留 niri 原生 `toggle-overview`:可保留作 fallback,也可改成 qs 的 overview

## 阶段 7 —— 卸 ii / 清场

shell 自托管之后:

- [ ] 卸 `illogical-impulse-*` 元包(留你想要的散件如 quickshell/matugen)
- [ ] 删 `~/.config/quickshell/ii/`(确认你自己的 shell 没在 import 它)
- [ ] 删 `~/.config/hypr/hyprland/scripts/fuzzel-emoji.sh` 这类已被 shell 内嵌的脚本
- [ ] 删 Python venv `ILLOGICAL_IMPULSE_VIRTUAL_ENV`

---

## 时间预期(诚实版)

- 阶段 0 + 1:**1~2 天**(兼容层是最难的,做对了后面顺)
- 阶段 2:**半天**
- 阶段 3:**3~5 天**(三件套,Bar 最快、Overview 最磨人)
- 阶段 4:**每个模块半天到 1 天,挑用得上的做**
- 阶段 5:**贯穿始终,持续 polish**

第一周目标:阶段 0 → 阶段 3 跑通,能脱离 ii 日用,即使丑也行。第二周开始堆细节。

## 关键参考(查文档时不要绕弯路)

- Quickshell 官方:<https://quickshell.outfoxxed.me/docs/>
- niri IPC:`man niri-ipc` 和源码 `wiki/IPC.md`
- Material 3 motion:<https://m3.material.io/styles/motion/>
- ii 源码作为蓝本:`~/.config/quickshell/ii/`(看 modules/services 各拷一份对照看)
