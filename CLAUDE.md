# CLAUDE.md

Agent-facing 简报。打开这个仓库新 session 时**先读这份再动手**。

人面向的入门见 `README.md`(目前还写着 Hyprland,**已过时**,等迁移收尾后再翻新)。

---

## 项目是什么

`yituoren` 的 Arch Linux 桌面 dotfiles。**正在从 Hyprland + illogical-impulse(ii)迁移到 niri + 自建 quickshell shell**。当前进度:

- niri 合成器已替代 Hyprland 作日常使用
- 壁纸 / Material You 取色 / 终端调色板的核心管线已自建,**不依赖 ii**
- ii 的 quickshell shell 仍在 `quickshell/ii/`,作为**参考实现**留着;不再启动它
- 自建 quickshell shell 在 `quickshell/mine/`:**Phase 0/1/2/3-Bar 主体完成**(骨架 + Niri 兼容层 + Theme + 整屏边框 bar + 工作区指示器/类别图标/焦点高亮舱位/动画)。剩余:系统托盘 / 音量 / 电量 → Launcher → Overview(详见 `docs/TODO.md`)

---

## 仓库布局

```
~/.dotfiles/
├── CLAUDE.md            # 你正在读的这份
├── README.md            # 人面向(暂过时)
├── assets/              # 壁纸 / 截图
├── clash-verge/         # 代理
├── docs/                # 工具文档 + TODO
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
│       ├── shell.qml    # 入口,Variants { Bar {} } + 显式 import 所有 qs.X 子模块(qmldir 引导)
│       ├── services/
│       │   ├── Niri.qml      # niri 事件流 + 响应式状态 + Niri.focusWorkspace 等 dispatch
│       │   ├── Theme.qml     # matugen colors.json,IPC 触发 reload
│       │   └── DateTime.qml  # 全局 1s tick 单例,Clock/Calendar 共用
│       └── modules/bar/
│           ├── Bar.qml       # 整屏边框 + 顶部 bar 内容容器
│           └── widgets/
│               ├── ArchLogo.qml
│               ├── WorkspaceIndicator.qml  # 类别图标 + 焦点反相舱位 + 动画
│               ├── FocusedWindowTitle.qml
│               └── Clock.qml
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
- **`rules.kdl` 全局 window-rule**:`geometry-corner-radius 18 + clip-to-geometry true + background-effect blur`
- **`rules.kdl` 的 layer-rule**:`namespace="^launcher$"` 已启用 fuzzel 模糊,**`geometry-corner-radius 17` 必须跟 `fuzzel.ini` 的 `[border] radius` 一致**,否则角外露彩色直角
- **`rules.kdl` `^mine-.*$` layer-rule + `^mine-bar$` 覆盖**:qs bar 是整屏 layer,bar 这条**必须**显式 `geometry-corner-radius 0` + `background-effect { blur false }` —— 否则 niri 把空洞(中间 transparent 区域)的桌面也卷进模糊,整桌面变糊
- **`layout.kdl` `struts { top 44; left 8; right 8; bottom 8 }`** —— 给 qs bar 整屏边框让位。**struts 跟 `Bar.qml` 里 `barHeight` / `sideFrame` 必须严格对应**,改 qs 那边的数同步改这里(qs 4-边 anchor 时 layer-shell exclusive-zone 失效,只能靠 struts)
- **`layout.kdl` `default-column-width { proportion 0.5; }`** —— 新窗口默认半宽
- **`binds.kdl` 终端类绑定** 默认 spawn 二进制名(不写绝对路径,靠 environment.kdl 的 PATH 解析)

---

## 已知坑(**别踩**)

- **eza alias 必须 `--icons=auto`**,不能裸 `--icons` —— `_eza` 补全会把后续路径当成 `--icons` 的取值,TAB 路径补全坏掉
- **`.zshrc` 的 OSC 调色板块必须在 p10k instant prompt 之前** —— 否则 instant prompt 吞掉 stdout,kitty 起手没色,要等 setwall 广播才对
- **zsh `out+="...${s}"` 拼接,若 `${s}` 以 `\` 结尾,`\` 会被吞** —— 所以 OSC 终止符必须用 BEL(`\a`)而不是 ST(`ESC \`)。bash 没这毛病,setwall.sh 仍用 ST 没事
- **QML property 名不能以 `on<Capital>` 开头** —— `on` + 大写字母被 QML 当成 signal handler。Material You 的 `on_background` 这种 token 在 QML 里用 `Theme.colors.on_background`(map 形式)而不是 `Theme.onBackground`(property 形式)
- **Claude Edit 工具改 `quickshell/mine/**` 下的 QML 后必须紧跟 `touch <file>`** —— Edit 走原子替换,quickshell 的 inotify 监听挂在老 inode 上接不到事件。`touch` 不换 inode,补一个 MODIFY 事件触发热重载。用户自己用编辑器保存能 reload,Edit 工具不行
- **wezterm `front_end = "WebGpu"`** 在 niri/wlroots 上会黑屏无输入,固定 `OpenGL`
- **matugen `[templates.zed]`** 已注释 —— 模板文件 `templates/zed/matugen.json` 不存在,留着会让 matugen 4.x 整次运行 abort
- **kitty `kitty <cmd>`** 直接接命令可以,但 wezterm 必须 `wezterm start -- <cmd>` 或 `wezterm -e <cmd>` —— fuzzel `terminal=` 写法要注意
- **`fuzzel` 的 layer-shell namespace 是 `launcher`,不是 `fuzzel`**(源码硬编码)
- **`awww` 是 `swww` 的改名延续**,`Provides: swww`,CLI 命令 `awww img / awww-daemon / awww restore`
- **qs 的 `qs.X` auto-qmldir 必须在 shell.qml 里显式 import** —— 子文件再 import 同一路径不会"自下而上"建索引,会报 `module "qs.modules.bar.widgets" is not installed`(伪装成上游 import 缺失,误导)。新建 services / widgets 子目录后,**第一时间在 shell.qml 末尾加一行 `import qs.X.Y`** 即可,即使 shell.qml 自己用不到
- **Quickshell `Region` 输入 mask 必须用 `item:` 引用 Item**,不能裸写 `Region { x: 0; y: 0; ... }` —— 即便 qmltypes 里有这些属性,实际解析会失败,错误冒泡成上游 `qs.X` 模块"不存在"
- **Maple Mono NF CN 走 `font.weight: Font.Bold/ExtraBold/Black`(整数 700/800/900)在 fontconfig 这里全被映射到 ExtraBold.ttf**,改 weight 数字看不出区别。要精确选 cut(尤其想看到真正的 Bold)必须用 **`font.styleName: "Bold"`**(或 "Medium" / "SemiBold" / "ExtraBold" / ...)绕开 weight 近似匹配
- **`MultiEffect`(`QtQuick.Effects`)给图标做单色重绘**:`colorization: 1.0 + colorizationColor: <c>` 把原图当 alpha mask 重染,比 Qt5Compat `ColorOverlay` 现代且便宜。用作 `source` 的原图要 `visible: false` 让 MultiEffect 接管渲染。当前 qs bar 已弃用,改走 Material Symbols Rounded 字体 ligature(更轻,字号无关)

---

## 已删除 / 不要复活

- `~/.dotfiles/zshrc.d/`(`auto-Hypr.sh` `dots-hyprland.zsh` `shortcuts.zsh`)—— 全过时,内容已并入或抛弃
- `~/.config/quickshell/ii/scripts/colors/terminal/sequences.txt` 这个中间文件 —— 颜色直接从 colors.json 读
- `[templates.zed]` matugen 模板 —— 没输入文件,disable 着
- `xdg-desktop-portal-hyprland`(已卸)、`xdg-desktop-portal-kde`(已卸)
- `~/.config/fuzzel/fuzzel.ini` 旧位置 —— 已迁到 `~/.dotfiles/fuzzel/fuzzel.ini` 软链回去

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
