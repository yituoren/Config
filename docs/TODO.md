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

- [x] 项目放在 `~/.dotfiles/quickshell/mine/`,软链到 `~/.config/quickshell/mine/`
- [x] `shell.qml` 作为入口
- [x] 开发态运行:`qs -p ~/.config/quickshell/mine`(改文件即热重载,~1s)
  - **坑**:Claude Edit 工具走原子替换会让 inotify 失效,改完要 `touch <file>` 触发 reload。用户自己用编辑器保存正常 reload。
- [ ] 早开 logging:`qs -p ... 2>&1 | tee /tmp/qs.log`,QML 报错才找得到
- [x] git 历史接上(niri 分支)

## ✅ 阶段 0 —— 骨架(完成)

- [x] `shell.qml`:32px 顶部条,namespace `mine-bar`,显示一行调试文字
- [x] niri `rules.kdl` 加了 `layer-rule { match namespace="^mine-.*$"; background-effect { blur true } }`
- [x] IPC 通了:`qs -c mine ipc call test ping` → 日志 `hi from mine`
- [x] 热重载链路通(用户编辑器保存即生效;Claude Edit 后跟 `touch`)

## ✅ 阶段 1 —— Niri 兼容层(最小可用版完成)

`services/Niri.qml` 已写,长连接 `niri msg --json event-stream`,事件按行 JSON parse。

- [x] 响应式属性:`workspaces` / `windows` / `focusedWindowId` / `activeWorkspaceId` / `overviewOpen` / `configOk` / `ready`
- [x] 快照事件:`WorkspacesChanged` / `WindowsChanged` 一上线就有全量状态
- [x] 增量事件:`WorkspaceActivated` / `WindowFocusChanged` / `WindowOpenedOrChanged` / `WindowClosed` / `OverviewOpenedOrClosed` / `ConfigLoaded`
- [x] 高频静默事件:`WindowFocusTimestampChanged` 等放 case fall-through 不打日志
- [x] 调试 IPC:`qs -c mine ipc call niri dump` 打当前状态
- [x] 验证通过:bar 显示的 `ws X · N wins · title` 切工作区/聚焦/开关窗口都实时变

剩余(本阶段后期补,不阻塞 Phase 3):
- [ ] dispatch 方法封装(`focusWorkspace` / `closeWindow` / `moveWindowToWorkspace` / `spawn`)—— 写 Bar 模块时按需补
- [ ] `outputs` 数组(目前没暴露,需要时从 `niri msg --json focused-output` 拉)
- [ ] `WindowLayoutsChanged` / `WindowUrgencyChanged` 等 Overview 模块要用的事件

## ✅ 阶段 2 —— Theme 管线(完成)

`services/Theme.qml` 已写,接 matugen → setwall → IPC 的链。

- [x] 沿用现有 `[templates.m3colors]` 输出的 `~/.local/state/quickshell/user/generated/colors.json`,不再加新模板
- [x] Theme 暴露完整的 49 个 Material You token,**用 `Theme.colors.<key>` map 形式访问**(避开 QML `on<Cap>` 命名禁忌)
- [x] 触发机制:**不用 `FileView.watchChanges`**(matugen 原子写让 inotify 失效),改用 `setwall.sh` 显式调 `qs -c mine ipc call theme reload`
- [x] 启动 / 重载链:`Component.onCompleted` 或 IPC → `Process { cat }` 读文件 → `StdioCollector.onStreamFinished` → `JSON.parse` → `root.colors = c`(整体替换触发 colorsChanged)→ 所有 binding 重算
- [x] shell.qml 已切换到 `Theme.colors.surface_container` / `on_surface` / `primary`,setwall 换壁纸时实时刷新

约定:其它模块**不许写死 hex**,fallback 也都集中在 Theme.qml 的初值里。

## ✅ 阶段 3 —— Bar + Popup 系统(完成)

### Bar widgets ✅
- ArchLogo / WorkspaceIndicator(类别图标 + 焦点反相舱位 + 动画) / FocusedWindowTitle / Clock
- SystemTrayIndicator(StatusNotifierItem,左键 activate / 右键 secondaryActivate / 滚轮 scroll)
- WifiIndicator / BluetoothIndicator / VolumeIndicator / BatteryIndicator / PowerButton

### SDF Blob 渲染层 ✅
- `Caelestia.Blobs` C++ plugin 自编
- ContentWindow 单 PanelWindow per screen 装 bar + popup,SDF cubic smin 把它们融合
- popup 凹槽自动从 bar 形状里"挖"出来

### Popup 系统 ✅
- `PopupManager` Singleton:统一管几何 / 动画 / scrim / openInProgress
- 7 个 popup:power(2×2 grid)/ wifi / bluetooth / volume / battery / tray / dashboard
- 共用配置:`registry { width, heightFn, scaleFrom, duration, transparent }`
- 切换 popup 平滑过渡(displayWidth/Height + animatedAnchorX 都带 Behavior)
- popup 开时所有屏 mask=null,点别屏空白也关 popup

### 中央 popup 框架 + Media tab ✅
- Dashboard popup 880 wide,半屏高度,hover bar 中央 320 宽窄条触发(80ms 延迟)
- 顶 4 tab(media / dashboard / weather / control),tab 间滑动下划线,记忆上次选中
- BlurPanel 独立 layer 给 dashboard 做模糊底(只能糊壁纸,niri xray 限制)
- 两段式开合:popup 开 → 慢一拍 → BlurPanel scale 0→1 600ms;关反过来 BlurPanel 先收 → 慢一拍 → popup 才开始收
- SDF 顶 → 底渐变:`colorBottom` + `gradientTop/Bottom` uniforms 实现 popup 底部半透
- **Media tab 完工**:
    - 上排:vol pill / sink ▼ / player ▼(都是 dropdown 菜单)
    - 下半:左侧文字面板(title/artist/album/歌词占位/进度条/控件)+ 右侧 280px 旋转光碟
    - 光碟:`MultiEffect` 圆形 mask 把方形封面裁圆 + vinyl 黑底 + 中心钉 + 周围 32 根 cava 环形 halo(`Repeater + Rectangle` rotated 角度铺)
    - 控件:shuffle / prev / 大圆 play-pause(primary 色)/ next / loop,disabled 状态走 opacity
    - 进度条:`SliderBar` + `MediaPlayer.formatTime`,canSeek 时拖动改 position;Timer 60Hz 调 `positionChanged()` 强制重读 MPRIS

### Cava 律动条 ✅
- `Cava.qml` Singleton spawn cava 进程,raw ASCII 解析(framerate 60,32 bars)
- 多消费者:`needBarViz`(bar 底层)/ `needMediaTab`(media tab 内)同时跑,都没需求就停
- Bar 底律动条:popup 关时显示,跟 dashboard 同宽同居中,32 根均分填满,顶 `#000`(贴 bar)→ 中 primary → 尾 primary alpha 0
- 静音(所有 value < 0.04)整层 500ms 淡出

### 系统服务 ✅
- `SystemStatus.qml`:电池 / WiFi / 蓝牙 / 音量 / 音频 sinks / 屏幕亮度(brightnessctl 内屏 + ddcutil 外屏 + 缓存 + debounce + 启动 prefetch)
- `MediaPlayer.qml`:MPRIS 薄壳(list 过滤 / active 钉住 / artUrl YouTube 兜底 / formatTime)

---

## ⏳ 阶段 3.5 —— 中央 popup 剩余 3 个 tab

Dashboard popup 框架 + Media 完工。剩下:

### Dashboard tab(主信息汇总)
- [ ] 大日历(月视图,Material 3 风格)
- [ ] 系统资源面板(CPU / RAM / 磁盘 / 网络 / 温度;ii 的 `Resources.qml` 抄)
- [ ] 待办 / 提醒(可选,Toggl 或 Markdown TODO)

### Weather tab
- [ ] `services/Weather.qml`:geoclue 拿坐标 + 调天气 API(open-meteo 免费无 key 推荐)
- [ ] 大图标(Material Symbols Rounded 的 `clear_day` / `cloudy` / `rainy` 等)+ 当前温度
- [ ] 24h / 7d 预报横条(温度曲线 + 降水柱状)

### Control tab(类似 macOS Control Center)
- [ ] 快捷开关 grid:WiFi 切换 / 蓝牙切换 / 飞行模式 / 勿扰 / 暗色模式 / 蓝光滤镜(wlsunset)
- [ ] 亮度全局 slider(选不同屏分别调,或单 slider 调全部内屏)
- [ ] 音量主 slider + 输入设备选择(目前只有输出)

### 媒体增强(给 Media tab)
- [x] **歌词服务** `services/Lyrics.qml`:LRCLIB 单源,debounce + signature 去重 + LRC 解析 + 二分定位 currentLine。MediaTab 三行已接(prev/current/next + loading/miss/error 状态)
- [ ] **Apple Music PWA 修复** —— PWA 只调 `mediaSession.setMetadata()`,没调 `setPositionState()`,导致 plasma-browser-integration 给的 `mpris:length` 是占位 `9999999`(实际秒数没法读)+ position 永远是 0。修复路径:
    - 写一个 userscript(Violentmonkey/Tampermonkey 装到 Chrome)在 `music.apple.com` 上跑,每 500ms 把网页内部 `<audio>.currentTime/duration/playbackRate` 喂给 `navigator.mediaSession.setPositionState(...)`,让 Chrome MPRIS / plasma-browser-integration 拿到真实 position+length
    - 装完之后 LRCLIB 命中率 + 同步全活
    - 进阶:Apple Music 自己的歌词 API(`amp-api.music.apple.com/v1/catalog/.../songs/{id}/lyrics`)毫秒级时间戳准,但要 developer token + user token,工程量大,先不做
- [ ] LRCLIB miss 时加 `/api/search` fallback(去 album + 清洗 title 后端 fuzzy 匹配)
- [ ] 媒体源选择:除 MPRIS 之外加 PipeWire stream 选择(浏览器音频没 MPRIS metadata 时也能调音量)

---

## ⏳ 阶段 4 —— Launcher / Overview / 其它

### Launcher —— 替代 fuzzel
- [ ] `services/AppSearch.qml`:扫 `/usr/share/applications/**/*.desktop`,模糊匹配
- [ ] UI:`mine-shell` 内或独立 PanelWindow,TextField + ListView
- [ ] IpcHandler `launcher.toggle()`,niri `binds.kdl` `Mod+Space` 改 `qs ipc call launcher toggle`
- [ ] 拓展:emoji / 计算器 / 剪贴板历史(整合 cliphist)同样走这套
- 验收:能完全替代 fuzzel,看上去顺眼

### Overview —— 工作区总览
- [ ] 每个工作区一格,格子内画该工作区窗口缩略(用 `Niri.windows` 渲染矩形,不真截图)
- [ ] 点格子调 `Niri.focusWorkspace`;拖窗调 `Niri.moveWindowToWorkspace`
- [ ] 跟 Launcher 共用 PanelWindow,合成"一键弹出工作区+应用"统一面板
- 验收:Mod+Tab 弹出能用

### 其它周边
- [ ] OSD:音量 / 亮度调节时的弹出条(自动淡出 PanelWindow)
- [ ] 通知中心:`Quickshell.Services.Notifications`(qs 内置 freedesktop notification daemon)+ ii 的 popup UI 抄
- [ ] Polkit agent:`PolkitAgent {}`(qs 内置)+ 简单密码框,装完可以卸 `polkit-kde-agent`
- [ ] Cheatsheet:Mod+/ 弹快捷键列表(niri 自带但样式不一致)
- [ ] WallpaperSelector:thumbnail 网格 + 切换调 `setwall`

## 阶段 5 —— polish / 视觉细节

视觉冲击靠这些。已完成的部分打勾,剩下的随时补:

### 5.1 形与光

- [x] 圆角:`BlobRect.radius` 让 SDF 自渲;popup 内部组件 `Rectangle.radius` + `clip: true`
- [x] 全局留白:popup 内 padding 至少 14~28px(MediaTab 已经按比例 padding)
- [x] 玻璃感:dashboard popup 顶 → 底渐变 + BlurPanel(虽然只糊壁纸)
- [ ] 阴影:popup 周围加柔和 `DropShadow`(`Qt5Compat.GraphicalEffects` 或 MultiEffect.shadow,只对静态加,动画时关)
- [ ] 边框:1px `border.color: Qt.rgba(255,255,255,0.06)` 在 popup 边沿,玻璃感更明显

### 5.2 动效

- [x] popup 开合走 cubic bezier(`[0.05, 0.7, 0.1, 1, 1, 1]` Emphasized)
- [x] popup 切换 width/height/anchorX 都带 Behavior 平滑过渡
- [x] popup scaleFrom 出场幅度小(big popup 不全幅展开,从 85% 起跳)
- [x] tab 切换滑动下划线 + 字色 Behavior
- [x] dropdown 菜单 opacity 渐入渐出
- [x] cava 60Hz tick + Behavior on height 80ms OutQuad
- [x] BlurPanel 两段式调度(慢一拍出现 + 关时反过来)
- [ ] popup 内出现/消失动画(目前只有整体 fade in/out,可以加每个组件分批 stagger)

### 5.3 字与图标

- [x] 图标字体走 `Material Symbols Rounded` ligature(`Text { font.family: ...; text: "settings" }`)
- [x] 文字字体统一 `Maple Mono NF CN`,精确 cut 用 `font.styleName: "ExtraBold"` 等绕开 weight 近似
- [ ] 标题 / 正文 / 数字字符间距(letterSpacing)调整,避免粘连

### 5.4 性能

- [x] cava 进程多消费者协调(`needBarViz` || `needMediaTab`),都不需要就停
- [x] ddcutil 启动 prefetch + 缓存,popup 打开不重复 I2C 调用
- [x] Loader 模式:popup 内容 / cava viz 都按需实例化
- [ ] 检查所有 Process / Timer,确认 idle 时是否真的停了
- [ ] 阻塞 GPU 的特效审查(如 niri blur 全屏问题已经避坑)

---

## 阶段 6 —— niri 配置接合(部分完成)

- [x] `startup.kdl` `spawn-at-startup "qs" "-p" "/home/yituoren/.config/quickshell/mine" "-d"`
- [x] `environment.kdl` 设 PATH + QML_IMPORT_PATH = `/home/yituoren/.local/share/qt6/qml`
- [x] `rules.kdl` 两条 layer-rule:`^mine-shell$`(空 body)+ `^mine-blur$`(blur + corner-radius 16)
- [x] `layout.kdl` `struts.top 52` 让窗口避开 bar
- [ ] `binds.kdl` 替换:
    - [ ] `Mod+Space` → 自建 Launcher(目前还是 fuzzel)
    - [ ] `Mod+V` → 自建剪贴板 UI(目前 fuzzel + cliphist)
    - [ ] `Ctrl+Alt+Delete` → 自建 session 面板(目前 wlogout / power popup)
- [x] `Mod+Tab` 走 niri 原生 `toggle-overview`(自建 Overview 出来后可换)

## 阶段 7 —— 卸 ii / 清场

shell 自托管之后:

- [ ] 卸 `illogical-impulse-*` 元包(留 quickshell/matugen 等散件)
- [ ] 删 `~/.config/quickshell/ii/`(确认自己 shell 没 import 它)
- [ ] 删 `~/.config/hypr/hyprland/scripts/` 已被 shell 内嵌的脚本
- [ ] 删 Python venv `ILLOGICAL_IMPULSE_VIRTUAL_ENV`

## 关键参考(查文档时不要绕弯路)

- Quickshell 官方:<https://quickshell.outfoxxed.me/docs/>
- niri IPC:`man niri-ipc` 和源码 `wiki/IPC.md`
- Material 3 motion:<https://m3.material.io/styles/motion/>
- ii 源码作为蓝本:`~/.config/quickshell/ii/`(看 modules/services 各拷一份对照看)
