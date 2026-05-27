# CLAUDE.md

Agent-facing 简报。打开这个仓库新 session 时**先读这份再动手**。

人面向的入门见 `README.md`(目前还写着 Hyprland,**已过时**,等迁移收尾后再翻新)。

---

## 项目是什么

`yituoren` 的 Arch Linux 桌面 dotfiles。**正在从 Hyprland + illogical-impulse(ii)迁移到 niri + 自建 quickshell shell**。当前进度:

- niri 合成器已替代 Hyprland 作日常使用
- 壁纸 / Material You 取色 / 终端调色板的核心管线已自建,**不依赖 ii**
- ii 的 quickshell shell 仍在 `quickshell/ii/`,作为**参考实现**留着;不再启动它
- 自建 quickshell shell 在 `quickshell/mine/`:Caelestia 风格 ContentWindow + 自编 `Caelestia.Blobs` C++ plugin(SDF metaball cubic smin)。当前完成度:
    - **Bar**(全套 widget):ArchLogo / WorkspaceIndicator(类别图标 + 焦点反相舱位) / FocusedWindowTitle / Clock / SystemTray / Wifi / Bluetooth / Volume / Battery / Power
    - **Popup 系统**:power(2×2 grid)/ wifi(switch + 飞行模式 + 当前连接 + 网络列表)/ bluetooth(switch + 连接 + 设备列表)/ volume(slider + sink 下拉)/ battery(电量 + 当前屏亮度 slider,brightnessctl/ddcutil 双后端)/ tray / dashboard。SDF metaball 把 bar 跟 popup 缝合成"挖凹槽"视觉,scrim 守门
    - **Dashboard 中央 popup**(hover bar 中部触发,半屏宽 880,带顶 4-tab + 滑动下划线):Media tab 完工(MPRIS + 圆形旋转封面 + cava 环形 halo + 音量/sink/player 下拉);其它 3 tab(dashboard/weather/control)目前占位
    - **Cava 律动条**:bar 底部从中央倒挂,matugen primary 色三段式渐变(顶黑 → 中浓 → 尾透),静音整层淡出
    - **BlurPanel**:dashboard 专用独立 layer-shell,niri `background-effect blur` 糊壁纸(window 不参与,niri 限制),popup 全开后**慢一拍**生成,从 popup 几何中心 scale grow 600ms;关闭反过来 BlurPanel 先 scale 0 再放 popup 收
    - **SDF 着色器扩展**:`BlobGroup` 加了 `colorBottom` / `gradientTop` / `gradientBottom`,popup 顶 → 底纵向颜色渐变(uniform 缓冲 1472 字节)
    - 剩余:Dashboard 另 3 tab 内容 / 歌词服务 / Launcher / Overview(`docs/TODO.md`)

---

## 仓库布局

```
~/.dotfiles/
├── CLAUDE.md            # 你正在读的这份
├── README.md            # 人面向(暂过时)
├── .gitignore           # caelestia-blobs/build/ + .claude/
├── assets/              # 壁纸 / 截图
├── caelestia-blobs/     # ★ 自编 C++ plugin(从 caelestia-dots/shell 的 Blobs 子模块原样移植)
│   ├── CMakeLists.txt   #   独立工程,装到 ~/.local/share/qt6/qml/Caelestia/Blobs/
│   ├── src/             #   blob{group,shape,rect,invertedrect,material}.{cpp,hpp} + shaders/
│   └── build/           #   gitignored
├── clash-verge/         # 代理
├── docs/                # 工具文档 + TODO
│   ├── quickshell.md    # ★ shell 架构 + Caelestia.Blobs plugin 编译/安装/调试
│   ├── kitty.md  yazi.md  fuzzel.md  zsh.md
│   └── TODO.md          # 主线计划,重要
├── fuzzel/              # fuzzel.ini(单文件软链到 ~/.config/fuzzel/)
├── hypr/                # Hyprland 残留;hyprlock.conf / hypridle.conf 还在用
├── illogical-impulse/   # ii 安装器写下的清单,只读参考
├── kitty/               # kitty 配置(整目录链)
├── matugen/             # 取色器 + 模板
│   ├── config.toml
│   └── templates/       # gtk-3.0/gtk-4.0/fuzzel/hyprland/kde/...
├── niri/                # niri 全部配置(主要工作目录)
│   ├── binds.kdl  rules.kdl  layout.kdl  startup.kdl
│   ├── environment.kdl  input.kdl  outputs.kdl  config.kdl
├── quickshell/
│   ├── ii/              # ii 的 qs shell,参考用,不启动
│   └── mine/            # 自建 shell(进行中)
│       ├── shell.qml    # 入口:Variants { BlurPanel{} } + Variants { ContentWindow{} } per screen
│       ├── services/
│       │   ├── Niri.qml         # niri 事件流 + 响应式状态 + focusWorkspace dispatch
│       │   ├── Theme.qml        # matugen colors.json,IPC 触发 reload
│       │   ├── DateTime.qml     # 全局 1s tick 单例
│       │   ├── SystemStatus.qml # 电池 / WiFi / 蓝牙 / 音量 / 音频 sinks / 亮度(双后端)轮询
│       │   ├── PopupManager.qml # popup 全局状态:registry / openAmount / blurVisible / dashboardTab 等
│       │   ├── MediaPlayer.qml  # MPRIS 薄壳:active player / artUrl / 格式化时间
│       │   └── Cava.qml         # spawn cava 进程,raw ASCII 解析成 [0,1] bar 数组(多消费者 enabled)
│       └── modules/
│           ├── drawers/
│           │   ├── ContentWindow.qml  # ★ 全屏 PanelWindow per screen,
│           │   │                      #   内含 BlobGroup + bar/popup BlobRect +
│           │   │                      #   bar widgets + popup content Loader + cava viz 兄弟层 + scrim
│           │   ├── BlurPanel.qml      # dashboard 专用模糊层(layer mine-blur),scale 0↔1 grow 动画
│           │   └── MediaTab.qml       # dashboard 的 media tab 内容(MPRIS + 旋转光碟 + cava halo + 控件)
│           └── bar/widgets/
│               ├── ArchLogo.qml
│               ├── WorkspaceIndicator.qml  # 类别图标 + 焦点反相舱位 + 动画
│               ├── FocusedWindowTitle.qml
│               ├── Clock.qml
│               ├── PowerButton.qml
│               ├── WifiIndicator.qml
│               ├── BluetoothIndicator.qml
│               ├── VolumeIndicator.qml
│               ├── BatteryIndicator.qml
│               ├── SystemTrayIndicator.qml
│               ├── SliderBar.qml         # 通用进度条(hover 时尾端弹白色 thumb)
│               └── IosSwitch.qml         # 苹果风格开关(白 knob + primary 底)
├── scripts/             # 用户脚本(进 PATH 走 ~/.local/bin/<name> 软链)
│   └── setwall.sh       # 壁纸 + matugen + OSC 广播 一气呵成
├── wezterm/             # wezterm.lua(整目录链)
├── xdg-desktop-portal/  # portal 用户覆盖(轻量纯 gtk 方案)
└── zsh-config/          # .zshrc / .zshenv / .zimrc / .p10k.zsh(单文件链)
```

---

## 颜色管线(核心架构,改任何 UI 颜色前必看)

```
壁纸 (Pictures/Wallpaper*/*.jpg)
   │ setwall <img>
   ├─ awww img <img>                          → 屏幕显示壁纸(awww 是 swww 改名延续)
   └─ matugen image <img> --source-color-index 0
       └─ 产物(都在 ~/.local/state/quickshell/user/generated/):
           ├─ colors.json                     ← 单一颜色源,所有消费者读它
           ├─ wallpaper/path.txt              ← 当前壁纸路径
           └─ color.txt                       ← 备用(目前没消费者)
       └─ matugen 还会同时渲染:
           ├─ ~/.config/gtk-3.0/gtk.css       ← GTK3 应用
           ├─ ~/.config/gtk-4.0/gtk.css       ← GTK4 应用
           ├─ ~/.config/fuzzel/fuzzel_theme.ini  ← fuzzel 颜色
           └─ ~/.config/hypr/{hyprland,hyprlock}/*.conf  ← legacy,无害

   随后 setwall 自己:
   └─ 读 colors.json → 拼 ANSI 16 + bg/fg/cursor 的 OSC 序列 → printf 到所有 /dev/pts/*
       (替代 ii 原来的 applycolor.sh + sequences.txt 那一套)

终端侧:
   ├─ .zshrc 启动时:同样的逻辑(jq 读 colors.json → print OSC)→ 新 shell 起手就是新色
   ├─ wezterm.lua 启动时:wezterm.json_parse(colors.json) → 设置 config.colors
   │   (这一步保证 fuzzel 直接 spawn wezterm 跑 yazi 时也能拿到 matugen 色)
   └─ kitty:目前没接 matugen,靠终端响应 OSC 4/10/11 在 shell 启动后被 zshrc 改色

qs shell(quickshell/mine):
   └─ setwall 跑完后 `qs -c mine ipc call theme reload`
       → Theme.qml(Singleton)Process { cat colors.json } → StdioCollector → JSON.parse
       → root.colors 整体替换 → 所有 binding 重算
       注:**没用 FileView.watchChanges**(matugen 原子写,inotify 失效),走显式 IPC
```

**ANSI 16 色映射**(`scripts/setwall.sh`、`.zshrc`、`wezterm/wezterm.lua` 里**三份**,改一处要同步):
- 0 black ← surface_container_lowest
- 1 red ← error
- 2 green ← tertiary(MD3 无"绿",可能是紫/橙)
- 3 yellow ← secondary
- 4 blue ← primary
- 5 magenta ← tertiary_container
- 6 cyan ← primary_container
- 7 white ← on_surface
- 8-15 亮色对应 container / on_xxx / fixed 变体

---

## shell 架构(改 quickshell/mine 前必看)

仿 [caelestia-dots/shell](https://github.com/caelestia-dots/shell) 的 ContentWindow 模式 + 自编 SDF blob 渲染。**每屏两个 PanelWindow**:`BlurPanel`(Top 层,只在 dashboard 开时存在)+ `ContentWindow`(Overlay 层,全屏 anchor)。BlurPanel 在下层 niri 给它开 blur 糊背景,ContentWindow 在上层画 SDF + widgets。

```
shell.qml
│
├─ Variants(BlurPanel{}) per screen    layer-shell Top   namespace mine-blur
│   └─ niri rule: background-effect blur + geometry-corner-radius 16
│      只在 popup transparent(目前只 dashboard)且完全展开后才出现,自身 600ms scale grow/shrink
│
└─ Variants(ContentWindow{}) per screen   layer-shell Overlay   anchors 4 边
    │
    ├─ Item (SDF 形状层)
    │   ├─ BlobGroup
    │   │   ├─ color: "#000000" (顶色)
    │   │   ├─ colorBottom: 看 entry.transparent → 半透 rgba(0,0,0,0.35) 或纯黑实色
    │   │   └─ gradientTop/Bottom: popup 区间 y 坐标
    │   ├─ BlobRect (bar 形状)
    │   └─ BlobRect (popup 形状,scale 跟 openAmount + scaleFrom 算)
    │
    ├─ Loader cavaVizLoader (popup 关时实例化)
    │   └─ Cava 律动条:32 根 Rectangle 走 QML Gradient,
    │      跟 dashboard 同宽同居中位置,顶 #000 → 中 primary → 底 primary alpha 0,
    │      无音乐整层 opacity 0
    │
    ├─ Scrim MouseArea (popup 开时全屏接管;openInProgress 期间吞 click 不关)
    │
    ├─ Item barContent (bar widgets)
    │   ├─ Archlogo / Workspaces / FocusedTitle
    │   ├─ rightCluster: Clock + Tray + Wifi + BT + Volume + Battery + Power
    │   └─ dashTriggerArea (320 宽,horizontalCenter,hover → 80ms 后开 dashboard)
    │
    └─ Item popupContentArea (popup 内容,跟 popup BlobRect 同步)
        └─ PopupItem(Loader)× 7
           (power / wifi / bluetooth / volume / battery / tray / dashboard)
           opacity transition 280ms 切 active
```

**Dashboard popup** 是当前唯一标 `transparent: true` 的 entry,触发条件:
- 用户偏好 `transparent: true` 的 popup → SDF 走渐变 + BlurPanel 启用
- 其它 popup → SDF 纯黑 + 无 BlurPanel

**两段式 blur 出入(在 PopupManager 调度):**
- 打开:popup 320ms 展开 → `onOpenAmountChanged` 检测 ≥ 0.999 → `blurAppearTimer` 120ms 后 `blurVisible = true` → BlurPanel scale 0 → 1 600ms grow
- 关闭:`close()` 检测 `entry.transparent && blurVisible` → 立刻 `blurVisible = false` → BlurPanel scale 1 → 0 → `blurCloseTimer` 600ms 后 `currentPopup = ""` → popup SDF 平滑收回 320ms

**为什么 ContentWindow 必须装一切:** Caelestia.Blobs 的 SDF metaball 融合(cubic smin)依赖所有 BlobRect 在**同一 scene graph**。bar 跟 popup 如果是两个独立 PanelWindow 就跨场景了,着色器看不到对方,融合不起作用。

**为什么 BlurPanel 必须分开:** niri 的 `background-effect blur` 在全屏 PanelWindow 上会糊整屏(因为透明像素那块也被糊)。把 blur 区域限制到只覆盖 popup 几何的小 PanelWindow,blur 范围就只在 popup 那块矩形内,不蔓延。

**Caelestia.Blobs plugin** 在 `~/.dotfiles/caelestia-blobs/`(C++ + GLSL,完全独立 Qt6/Quick,没拖 Caelestia 别的 config 依赖)。BlobMaterial 现在带 `colorBottom` + `gradientTop` + `gradientBottom` uniforms(buffer ≥ 1472 字节)。编译:`cd build && cmake .. && make && make install` 装到 `~/.local/share/qt6/qml/Caelestia/Blobs/`。Quickshell 通过 `QML_IMPORT_PATH=~/.local/share/qt6/qml`(在 `niri/environment.kdl` 里设)找到它。详细编译 + 调试见 `docs/quickshell.md`。

**`PopupManager`(Singleton)** 是 popup 状态的单一来源,所有几何/状态从它派生:
- `currentPopup` / `currentScreen` / `anchorX`(原始触发器中心)
- `entry` / `isOpen` / `lastEntry`(关闭动画期间保留尺寸 + scaleFrom + transparent 等用)
- `displayWidth/Height`(带 Behavior 切换 popup 时尺寸平滑过渡;支持 `heightFn(screen)` 动态算高)
- `extraHeight`(popup 内 dropdown 展开时撑高,如 volume sink 列表)
- `openAmount`(0→1 开合动画,带 Behavior;duration 跟 `activeDuration` 走)
- `triggerRelativeX`(0~1,trigger 在 popup 内的相对位置,边缘按钮自动 clamp 到 0/1)
- `animatedAnchorX`(Behavior'd anchorX,切换 popup 时横向滑动)
- `openInProgress`(开合动画期间 scrim 守门)
- `blurVisible`(BlurPanel 调度,只对 transparent popup 生效)
- `dashboardTab`(记忆 dashboard 上次选中的 tab,下次打开同一)

**`Cava`(Singleton)** spawn cava 进程,raw ASCII 解析成 [0,1] bar 数组。32 根 bar(脱离 SDF 限额)。多消费者:`needBarViz`(bar 底律动条)/ `needMediaTab`(media tab 内可视化)同时活跃就跑,都没需求就停。

**`MediaPlayer`(Singleton)** Mpris 薄壳:`list` 过滤 playerctld 镜像 / `active` 钉住 > 正在播 > 第一个 / `getArtUrl()` 带 YouTube 缩略图兜底 / `formatTime()` mm:ss 工具。MPRIS 的 `position` 不会自动 tick,要外部 Timer 每秒调一下 `positionChanged()` 强制 quickshell 重读 DBus(MediaTab 已经做了)。

**输入 mask:** popup 关时 mask=bar 区域(其它穿透);popup 开时**所有屏**(包括 popup 不在的屏)都 mask=null,scrim 在所有屏接管 → 点别屏空白也能关 popup。

**niri 配合:**
- `layout.kdl` `struts.top 52` —— ContentWindow `exclusionMode=Ignore` 不发 exclusive_zone,靠 struts 让窗口不挤到 bar 下面
- `rules.kdl` 两条 layer-rule:
    - `^mine-shell$` 空 body(SDF 自己渲染圆角/形状)
    - `^mine-blur$` `background-effect { blur true }` + `geometry-corner-radius 16`(跟 popup SDF radius 同步,blur 矩形切成圆角同形)

---

## 软链约定

- **优先单文件软链,而不是整目录** —— 除非这个目录里 100% 都是手写文件
- 原因:matugen / 应用本身常往配置目录里写自动生成的文件(`fuzzel_theme.ini` / `lockfile` / 缓存),整目录链会把这些拖进 git 制造噪声 diff
- 当前已确立的模式:
    - `fuzzel/fuzzel.ini` —— 单文件链,`fuzzel_theme.ini` 留 `~/.config/fuzzel/` 不进仓库
    - `kitty/` —— 整目录链(纯手写)
    - `wezterm/` —— 整目录链(纯手写)
    - `niri/` —— 整目录链(纯手写)
    - `zsh-config/*` —— 单文件链(`.zshrc` `.zshenv` `.zimrc` `.p10k.zsh`)

---

## 用户偏好(已确立,**别再回退**)

| 偏好 | 含义 |
|---|---|
| **轻量 + 定制化** | 凡选型出现"重 vs 轻 + 定制空间",选轻的;能去掉的进程/模板就去掉 |
| **GTK 风格 portal** | xdg-desktop-portal 全部走 gtk,Secret 走 gnome-keyring;**不装 kde / hyprland portal**,不需要 ScreenCast |
| **字体一致** | wezterm 和 fuzzel 统一 Maple Mono NF CN |
| **wezterm 主力终端** | fuzzel `terminal=wezterm start --`;niri Mod+T → wezterm;Mod+Return → kitty(并存) |
| **yazi 默认文件管理器** | `xdg-mime default yazi.desktop inode/directory`;niri Mod+E → `kitty --class yazi yazi` |
| **docs 风格** | 英文 H1/H2、code-block 优先、prose 压最少。**参 `docs/kitty.md`**。新加 doc 也按这个 |
| **Zed 保留 Catppuccin Mocha (Blur) [Heavy]** | 不要为了"颜色统一"让我换掉它 |
| **focus-ring 透明** | `layout.kdl` 里 active-color `#00000000`,**不要复活**鲜色 ring —— 会被 niri blur 卷进透明窗口 |

---

## niri 配置要点(改之前先看)

- **`environment.kdl` 必须显式设 PATH**:`/home/yituoren/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin`
    - niri 默认 PATH 不含 `~/.local/bin`,任何 spawn 用户脚本(`setwall` / `zed` / 自建 shell 等)会静默失败
    - 不展开 `$HOME` / `$VAR`,要写绝对路径
- **`environment.kdl` 必须设 `QML_IMPORT_PATH`(+ 兼容用 `QML2_IMPORT_PATH`)= `/home/yituoren/.local/share/qt6/qml`** —— 自编 Caelestia.Blobs plugin 装在用户级,Qt 默认只搜 `/usr/lib/qt6/qml`,不指这条 qs 找不到模块直接 fail
- **`startup.kdl` `spawn-at-startup "qs" "-p" "/home/yituoren/.config/quickshell/mine" "-d"`** —— 开机自动起自建 shell。改 spawn 之后要重启 niri 才生效(已运行的子进程不受新 startup.kdl 影响)
- **`rules.kdl` 全局 window-rule**:`geometry-corner-radius 18 + clip-to-geometry true + background-effect blur`
- **`rules.kdl` `^launcher$`** layer-rule(fuzzel):`geometry-corner-radius 17` 必须跟 `fuzzel.ini` 的 `[border] radius` 一致,否则角外露彩色直角
- **`rules.kdl` `^mine-shell$`** layer-rule:**空 body**(无 blur 无 corner-radius)。SDF blob 自己渲染形状,niri 不要插手。改 ContentWindow 形状只动 qs 那边
- **`layout.kdl` `struts { top 52; left/right/bottom 0 }` + `gaps 8`** —— ContentWindow 全屏 anchor + `exclusionMode: Ignore`(不发 exclusive_zone),只能靠 `struts.top = 52`(= bar 上 margin 8 + bar 高 44)让窗口不挤到 bar 下面。其它边 0,加 gaps 8 让窗口距屏边 8
- **niri 的 KDL parser 不接受内联块语法**:`background-effect { blur true }` 写在一行会报 `unexpected token }`,必须展开成多行。`niri validate` 命令可以在改完 niri/*.kdl 后跑一次本地检验
- **`layout.kdl` `default-column-width { proportion 0.5; }`** —— 新窗口默认半宽
- **`binds.kdl` 终端类绑定** 默认 spawn 二进制名(不写绝对路径,靠 environment.kdl 的 PATH 解析)

---

## 已知坑(**别踩**)

- **eza alias 必须 `--icons=auto`**,不能裸 `--icons` —— `_eza` 补全会把后续路径当成 `--icons` 的取值,TAB 路径补全坏掉
- **`.zshrc` 的 OSC 调色板块必须在 p10k instant prompt 之前** —— 否则 instant prompt 吞掉 stdout,kitty 起手没色,要等 setwall 广播才对
- **zsh `out+="...${s}"` 拼接,若 `${s}` 以 `\` 结尾,`\` 会被吞** —— 所以 OSC 终止符必须用 BEL(`\a`)而不是 ST(`ESC \`)。bash 没这毛病,setwall.sh 仍用 ST 没事
- **QML property 名不能以 `on<Capital>` 开头** —— `on` + 大写字母被 QML 当成 signal handler。Material You 的 `on_background` 这种 token 在 QML 里用 `Theme.colors.on_background`(map 形式)而不是 `Theme.onBackground`(property 形式)
- **Claude Edit 工具改 `quickshell/mine/**` 下的 QML 后必须紧跟 `touch <file>`** —— Edit 走原子替换,quickshell 的 inotify 监听挂在老 inode 上接不到事件。`touch` 不换 inode,补一个 MODIFY 事件触发热重载。用户自己用编辑器保存能 reload,Edit 工具不行
- **改 `caelestia-blobs/` C++ / GLSL 代码后必须重 build + install + 重启 qs** —— qs 启动时一次性加载 plugin .so,QML 热重载不会重载 native code。流程:`cd caelestia-blobs/build && make && make install; pkill -f 'qs.*mine'; qs -p ~/.config/quickshell/mine -d`(从带 `QML_IMPORT_PATH` 的 shell 起,或者重启 niri)
- **Quickshell ABI 必须跟系统 Qt 版本匹配** —— Arch 的 quickshell 包升级有延迟,系统 Qt 升级后 qs 没 rebuild 会有 ABI 不匹配 warning(可能 crash)。`pacman -S quickshell-git` 强制重装一下解决。看 qs log 开头"built against Qt X but system has Qt Y"这种警告就是
- **wezterm `front_end = "WebGpu"`** 在 niri/wlroots 上会黑屏无输入,固定 `OpenGL`
- **matugen `[templates.zed]`** 已注释 —— 模板文件 `templates/zed/matugen.json` 不存在,留着会让 matugen 4.x 整次运行 abort
- **kitty `kitty <cmd>`** 直接接命令可以,但 wezterm 必须 `wezterm start -- <cmd>` 或 `wezterm -e <cmd>` —— fuzzel `terminal=` 写法要注意
- **`fuzzel` 的 layer-shell namespace 是 `launcher`,不是 `fuzzel`**(源码硬编码)
- **`awww` 是 `swww` 的改名延续**,`Provides: swww`,CLI 命令 `awww img / awww-daemon / awww restore`
- **qs 的 `qs.X` auto-qmldir 必须在 shell.qml 里显式 import** —— 子文件再 import 同一路径不会"自下而上"建索引,会报 `module "qs.modules.bar.widgets" is not installed`(伪装成上游 import 缺失,误导)。新建 services / widgets 子目录后,**第一时间在 shell.qml 末尾加一行 `import qs.X.Y`** 即可,即使 shell.qml 自己用不到
- **Caelestia.Blobs 的 BlobRect / BlobInvertedRect 必须共享同一个 BlobGroup 且在同一 PanelWindow** —— SDF 着色器跨 PanelWindow 看不到对方的距离场,metaball 融合不工作。这就是为什么必须用 ContentWindow 模式装下 bar + popup,而不是分两个 layer
- **Caelestia.Blobs 的 GLSL shader path 必须是 `:/shaders/blob.frag.qsb`** —— plugin C++ 代码里写死了这个 resource 路径。`qt_add_shaders(BASE src FILES src/shaders/blob.frag)` 里 BASE 不能漏,不然 resource 路径会带 `src/` 前缀,plugin 找不到 shader 报 "Failed to find shader" + 渲染失败
- **Maple Mono NF CN 走 `font.weight: Font.Bold/ExtraBold/Black`(整数 700/800/900)在 fontconfig 这里全被映射到 ExtraBold.ttf**,改 weight 数字看不出区别。要精确选 cut(尤其想看到真正的 Bold)必须用 **`font.styleName: "Bold"`**(或 "Medium" / "SemiBold" / "ExtraBold" / ...)绕开 weight 近似匹配
- **`MultiEffect`(`QtQuick.Effects`)给图标做单色重绘**:`colorization: 1.0 + colorizationColor: <c>` 把原图当 alpha mask 重染,比 Qt5Compat `ColorOverlay` 现代且便宜。用作 `source` 的原图要 `visible: false` 让 MultiEffect 接管渲染。当前 qs bar 已弃用,改走 Material Symbols Rounded 字体 ligature(更轻,字号无关)
- **`MultiEffect.maskSource` 圆形裁切**:方形封面 → 圆形 disc 必须走 `maskEnabled: true` + 一个 `layer.enabled: true` 的圆形 Rectangle 作为 mask。`Rectangle { radius: w/2; clip: true }` **不会**把内部 Image 裁成圆形(Qt 的 clip 只切到 bounding rect,不切圆角)
- **niri 的 `background-effect blur` 在 layer-shell 上只采到 background 层**(壁纸 + niri backdrop-color),正常窗口看不到。`xray true` 也不能穿透普通窗口 —— 那个开关只对带 `place-within-backdrop true` window-rule 的窗口生效,普通工作区窗口默认不在 backdrop 里。**结论**:layer-shell 的 background-effect blur 永远只能糊壁纸,要糊真实窗口内容必须靠 client-side 抓屏(wlr-screencopy)+ 自写 shader,工程量大
- **niri 的 background-effect blur 在全屏 layer 上会糊整屏**:layer-shell 透明像素会被 niri 当成"要透出 backdrop blur",全屏 PanelWindow 99% 都是透明的 → 整屏壁纸都被糊一次。解决方案:把 blur 区域单独拆成只覆盖目标几何的小 PanelWindow(本仓库的 `BlurPanel.qml`)
- **Caelestia.Blobs 的 BlobRect 上限 16 个/group**:`BlobMaterial::m_rects[16]` + shader `rectData[80] = 16×5 vec4`。bar(1)+popup(1)= 2 占用,留 14 给其它形状(cava 律动条曾经试过走 SDF 但 32 根超限,改用 QML Gradient 绕开)
- **BlobMaterial uniform buffer 大小**:加了 `colorBottom` + `gradientTop/Bottom` 后,buffer assert 改成 `>= 1472`(从原来 1440 升上来)。再加新 uniform 时注意 std140 对齐 + 更新 assert
- **BlobGroup 的 color/colorBottom/gradient 是 group 全局**:同一 group 里所有 BlobRect 共享同一渐变。要给 popup + bar 不同色阶就不能塞同一个 group(但塞不同 group 就无法 metaball 融合)。当前选择:bar 跟 popup 共用 group + 全局渐变 + bar 在 gradientTop 之上自然走纯黑;cava 律动条因为要独立 primary 色 → 干脆不进 SDF,走 QML Rectangle + `gradient: Gradient {}` 各自独立着色
- **PanelWindow + niri 的 `geometry-corner-radius` layer-rule** 必须跟里面渲染的圆角一致,否则角外会露方块(blur / 颜色)。`^mine-blur$` 用 16 跟 ContentWindow.barRadius 同步;`^launcher$` 用 17 跟 fuzzel.ini 同步
- **QML 同名 signal handler 不能用 `onXxx_Custom:` 这种重名变体**:`onEntryChanged` 已经被一个 handler 占了,再写 `onEntryChanged_blurGate:` 是不合法语法,要么并入现有 handler,要么用 `Connections { target: ...; function onEntryChanged() {} }`

---

## 已删除 / 不要复活

- `~/.dotfiles/zshrc.d/`(`auto-Hypr.sh` `dots-hyprland.zsh` `shortcuts.zsh`)—— 全过时,内容已并入或抛弃
- `~/.config/quickshell/ii/scripts/colors/terminal/sequences.txt` 这个中间文件 —— 颜色直接从 colors.json 读
- `[templates.zed]` matugen 模板 —— 没输入文件,disable 着
- `xdg-desktop-portal-hyprland`(已卸)、`xdg-desktop-portal-kde`(已卸)
- `~/.config/fuzzel/fuzzel.ini` 旧位置 —— 已迁到 `~/.dotfiles/fuzzel/fuzzel.ini` 软链回去
- `quickshell/mine/modules/bar/Bar.qml` / `modules/popups/PopupPanel.qml` / `modules/popups/PopupScrim.qml` —— SDF 重构后由单个 `modules/drawers/ContentWindow.qml` 装下一切,不要复活独立 PanelWindow 的架构(跨 PanelWindow 没法 SDF 融合)
- `^mine-bar$` / `^mine-popup-.*$` / `^mine-scrim$` 等 niri layer-rule —— 现在只有 `^mine-shell$` 一条
- niri `struts { 0 0 0 0 }` —— 现在 `struts.top 52`,因为 ContentWindow 不发 exclusive_zone

---

## 工具入口速查(常用键 / 命令)

| 入口 | 触发 |
|---|---|
| 应用启动器 | `Mod+Space` → fuzzel |
| 剪贴板历史 | `Mod+V` → cliphist + fuzzel dmenu |
| 终端 | `Mod+Return` → kitty,`Mod+T` → wezterm |
| 文件管理器 | `Mod+E` → `kitty --class yazi yazi` |
| 编辑器 | `Mod+C` → zed |
| 浏览器 | `Mod+W` → google-chrome-stable |
| 工作区总览 | `Mod+Tab` |
| 截图区域 | `Mod+Shift+S` |
| 取色 | `Mod+Shift+C` → hyprpicker(在 niri 下可用) |
| OCR | `Mod+Shift+X` |
| 切换壁纸+全局换色 | shell: `setwall <path>` / `setwall random` |

---

## 主线路标

`docs/TODO.md` 是真正的"接下来要做什么"清单。今日 agent 接手时:

1. 读 `docs/TODO.md` 看主线进度(自建 quickshell shell 是最大未完工项)
2. 用户偶发请求按本文档的"用户偏好"对齐,不必反复确认风格
3. 改任何 UI 颜色 / 涉及 matugen 流程时,**回到上面"颜色管线"那一节**对照
4. 改 niri 任何 .kdl 后**不用重启**,文件保存即热重载(已 spawn 的子进程不变,新 spawn 用新 env)
