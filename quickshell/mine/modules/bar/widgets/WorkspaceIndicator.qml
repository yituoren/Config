pragma ComponentBehavior: Bound

// WorkspaceIndicator —— 跟 Niri.workspaces 实时联动
//
// 视觉规则:
//   - Active + 有窗口:长药丸,内部 N 个类别图标(Material Symbols Rounded);
//                     当前 focus 的窗口图标背后浮一个高亮"舱位",随 focus 切换滑动
//   - Active + 空:32×24 长药丸,空内容
//   - Inactive(无论是否有窗口):12×12 正圆点
//
// 动画:
//   - 工作区切换:pill 宽 / 高 / 颜色都有 Behavior;iconRow 整体 opacity 渐隐渐显
//   - 窗口切换(同 ws):高亮舱位 x 走 Emphasized easing,左右滑过去
//   - 高亮在 ws 切换时:opacity 渐淡,然后到新 ws 的对应位置渐显

import QtQuick
import qs.services

Row {
    id: root
    spacing: 10
    readonly property int slotHeight: 24

    // 图标尺寸 + 排版常量(高亮舱位计算要用)
    readonly property int iconSize: 18
    readonly property int iconSpacing: 6
    readonly property int iconStride: iconSize + iconSpacing  // 24

    readonly property var visibleWorkspaces: {
        const list = Niri.workspaces.slice()
        list.sort((a, b) => a.idx - b.idx)
        return list
    }

    function categoryIcon(appId) {
        if (!appId) return "apps"
        const s = appId.toLowerCase()
        if (/term|kitty|alacritty|foot|ghostty|wezterm|^st$|^st-|urxvt/.test(s)) return "terminal"
        if (/yazi|nautilus|dolphin|thunar|nemo|pcmanfm|files/.test(s)) return "folder"
        if (/chrom|firefox|brave|qutebrowser|opera|vivaldi|librewolf|zen/.test(s)) return "language"
        if (/clash|mihomo|v2ray|nekoray|qv2ray|sing-box|tun2socks/.test(s)) return "vpn_lock"
        if (/zed|code|vscode|sublime|atom|vim|emacs|jetbrain|idea|pycharm|goland/.test(s)) return "code"
        if (/discord|telegram|slack|signal|element|qq|wechat|whatsapp/.test(s)) return "chat"
        if (/spotify|youtube|netease/.test(s)) return "music_note"
        if (/vlc|mpv|celluloid|potplayer|smplayer/.test(s)) return "play_circle"
        if (/thunderbird|geary|evolution|mailspring/.test(s)) return "mail"
        if (/feh|swayimg|imv|gthumb|gpicview|loupe|qview|nomacs/.test(s)) return "image"
        if (/pavu|blueberry|nm-connection|gnome-control|systemsettings/.test(s)) return "tune"
        if (/zoom|jitsi|teams|skype|webex/.test(s)) return "videocam"
        if (/krita|gimp|inkscape|blender|figma|drawio/.test(s)) return "brush"
        if (/libreoffice|abiword|onlyoffice|wps/.test(s)) return "description"
        if (/htop|btop|bottom|nvtop|btm/.test(s)) return "monitor_heart"
        if (/steam|lutris|heroic|gamescope|prismlauncher/.test(s)) return "sports_esports"
        if (/obsidian|notion|joplin|logseq/.test(s)) return "edit_note"
        if (/keepass|bitwarden|1password/.test(s)) return "lock"
        if (/torrent|qbittorrent|transmission|deluge/.test(s)) return "download"
        return "apps"
    }

    Repeater {
        model: root.visibleWorkspaces

        Item {
            id: slot
            required property var modelData

            readonly property bool isActive: slot.modelData.id === Niri.activeWorkspaceId
            readonly property var windowsInWs: Niri.windows.filter(w => w.workspace_id === slot.modelData.id)
            readonly property bool hasWindows: slot.windowsInWs.length > 0
            readonly property int focusedIdx:
                slot.windowsInWs.findIndex(w => w.id === Niri.focusedWindowId)

            width: pillBg.width
            height: root.slotHeight

            Rectangle {
                id: pillBg
                anchors.centerIn: parent
                clip: true  // 收缩时图标不外露

                width: {
                    if (!slot.isActive) return 12
                    if (!slot.hasWindows) return 32
                    const n = slot.windowsInWs.length
                    return n * root.iconSize + (n - 1) * root.iconSpacing + 16
                }
                height: slot.isActive ? 24 : 12
                radius: height / 2
                color: slot.isActive ? Theme.colors.primary : Theme.colors.surface_container_high

                Behavior on width {
                    NumberAnimation {
                        duration: 420
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                    }
                }
                Behavior on height {
                    NumberAnimation { duration: 380 }
                }
                Behavior on color {
                    ColorAnimation { duration: 340 }
                }

                // ---- 焦点窗口高亮舱位(在 iconRow 之前声明,保证 z 序在下方) ----
                // 形状跟 workspace pill 一致:fully rounded(radius = height/2)。
                // 颜色反转:chip 用 on_primary(pill 的对比色)做底,焦点 icon 改用 primary
                // 做色 —— 视觉上是"陷进药丸里的反相小药丸",对比强烈。
                Rectangle {
                    id: focusHighlight
                    width: 26
                    height: 20
                    radius: height / 2
                    color: Theme.colors.on_primary
                    opacity: (slot.isActive && slot.focusedIdx >= 0) ? 1 : 0
                    visible: opacity > 0

                    // 居中到 focus 图标:chip 比 icon 宽 8px,所以左移 (26 - iconSize)/2 = 4
                    x: iconRow.x + slot.focusedIdx * root.iconStride - (width - root.iconSize) / 2
                    y: (pillBg.height - height) / 2

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }
                }

                Row {
                    id: iconRow
                    anchors.centerIn: parent
                    spacing: root.iconSpacing
                    opacity: (slot.isActive && slot.hasWindows) ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 280 }
                    }

                    Repeater {
                        model: slot.windowsInWs

                        Text {
                            id: iconText
                            required property var modelData
                            readonly property bool isFocused: iconText.modelData.id === Niri.focusedWindowId

                            width: root.iconSize
                            height: root.iconSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            text: root.categoryIcon(iconText.modelData.app_id ?? "")
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: root.iconSize
                            // 反转:焦点窗口取 primary(同 pill 底色)→ 看起来像被 chip 抠了个洞
                            color: iconText.isFocused ? Theme.colors.primary : Theme.colors.on_primary

                            Behavior on color {
                                ColorAnimation { duration: 220 }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(slot.modelData.id)
            }
        }
    }
}
