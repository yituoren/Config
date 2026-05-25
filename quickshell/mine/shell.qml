//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// Phase 1 验证版:Bar 显示从 niri 事件流取到的实时状态
//   - 当前活动工作区 idx
//   - 窗口总数
//   - 焦点窗口的 title(超长截断)
// 切工作区 / 切窗口 / 开关窗口都应该立刻在 bar 上看到变化。

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.services

ShellRoot {
    // 每块屏幕一个 bar 实例
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "mine-bar"
            WlrLayershell.layer: WlrLayer.Top

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32

            // 0.65 alpha 的 surface_container —— niri 的 background-effect blur 撑视觉
            color: {
                const c = Qt.color(Theme.colors.surface_container)
                return Qt.rgba(c.r, c.g, c.b, 0.65)
            }

            Row {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: Niri.ready
                          ? `ws ${Niri.activeWorkspaceId}  ·  ${Niri.windows.length} wins  ·  ${overviewTag}${focusedTitle}`
                          : "Niri: connecting..."
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 14

                    readonly property var focusedWindow: Niri.windows.find(w => w.id === Niri.focusedWindowId)
                    readonly property string focusedTitle: {
                        if (!focusedWindow) return "(no focus)"
                        const t = focusedWindow.title ?? ""
                        return t.length > 60 ? t.slice(0, 60) + "…" : t
                    }
                    readonly property string overviewTag: Niri.overviewOpen ? "[overview]  " : ""
                }

                // 一个小色块,纯演示 Theme.primary 跟壁纸联动
                Rectangle {
                    width: 14
                    height: 14
                    radius: 4
                    color: Theme.colors.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // 测试 ipc
    IpcHandler {
        target: "test"
        function ping(): void { console.log("hi from mine") }
    }
}
