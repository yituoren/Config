pragma Singleton
pragma ComponentBehavior: Bound

// Niri.qml —— niri 兼容层(替代 ii 的 HyprlandData.qml)
//
// 长连接 `niri msg --json event-stream`,把事件解码成响应式属性。
// 初版只接最小核心:工作区列表、窗口列表、焦点窗口、活动工作区。
// 不认识的事件全部 console.log,方便观察 niri 实际吐什么。

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ------- 响应式状态 -------
    property var workspaces: []          // [{id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}, ...]
    property var windows: []             // [{id, title, app_id, pid, workspace_id, is_focused, ...}, ...]
    property int focusedWindowId: -1
    property int activeWorkspaceId: -1
    property bool overviewOpen: false
    property bool configOk: true
    property bool ready: false           // 第一次 WorkspacesChanged 后置 true

    // ------- 长连接 niri 事件流 -------
    Process {
        id: stream
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.handleLine(line)
        }
        // niri 退出会让 Process 结束;niri 重启后这里没有自动重连逻辑,
        // 通常 niri 不会中途挂,先不做重试,等真出问题再补 onExited 重启
    }

    // ------- 解析 -------
    function handleLine(line: string): void {
        if (!line || line.length === 0) return
        let event
        try {
            event = JSON.parse(line)
        } catch (e) {
            console.warn("Niri: invalid JSON:", line.slice(0, 200))
            return
        }
        const type = Object.keys(event)[0]
        const data = event[type]

        switch (type) {
            // ===== 快照(连接时一次性发) =====
            case "WorkspacesChanged":
                root.workspaces = data.workspaces
                const focusedWs = data.workspaces.find(w => w.is_focused)
                if (focusedWs) root.activeWorkspaceId = focusedWs.id
                root.ready = true
                break

            case "WindowsChanged":
                root.windows = data.windows
                const focusedWin = data.windows.find(w => w.is_focused)
                root.focusedWindowId = focusedWin ? focusedWin.id : -1
                break

            // ===== 增量 =====
            case "WorkspaceActivated":
                // 切到某个工作区;data: {id, focused}
                // focused=true 表示用户主动聚焦(对应 activeWorkspaceId),
                // focused=false 表示该 output 上的 active workspace 变了但用户没聚焦它
                if (data.focused) root.activeWorkspaceId = data.id
                // 同步 workspaces 数组里的 is_active / is_focused
                const target = root.workspaces.find(w => w.id === data.id)
                if (target) {
                    root.workspaces = root.workspaces.map(w => {
                        if (w.output !== target.output) return w
                        return Object.assign({}, w, {
                            is_active: w.id === data.id,
                            is_focused: w.id === data.id && data.focused ? true
                                       : data.focused ? false
                                       : w.is_focused,
                        })
                    })
                }
                break

            case "WindowFocusChanged":
                root.focusedWindowId = data.id ?? -1
                root.windows = root.windows.map(w =>
                    Object.assign({}, w, { is_focused: w.id === data.id })
                )
                break

            case "WindowOpenedOrChanged":
                // 单窗口的新增或属性变化(标题/floating 等)
                const w = data.window
                const idx = root.windows.findIndex(x => x.id === w.id)
                const next = root.windows.slice()
                if (idx >= 0) next[idx] = w
                else next.push(w)
                root.windows = next
                if (w.is_focused) root.focusedWindowId = w.id
                break

            case "WindowClosed":
                root.windows = root.windows.filter(w => w.id !== data.id)
                if (root.focusedWindowId === data.id) root.focusedWindowId = -1
                break

            case "OverviewOpenedOrClosed":
                root.overviewOpen = data.is_open
                console.log("Niri: overview =", data.is_open)
                break

            case "ConfigLoaded":
                root.configOk = !data.failed
                break

            // 暂不处理但要观察的:
            case "WorkspaceActiveWindowChanged":
            case "WorkspaceUrgencyChanged":
            case "WindowUrgencyChanged":
            case "WindowLayoutsChanged":
            case "KeyboardLayoutsChanged":
            case "CastsChanged":
            case "WindowFocusTimestampChanged":  // 每次聚焦都触发,niri 内部用;Bar/Overview 都不关心
                // 静默,以后补
                break

            default:
                console.log("Niri: unhandled event:", type, JSON.stringify(data).slice(0, 200))
        }
    }

    // ------- 调试用:打印当前状态摘要(qs ipc call niri dump) -------
    IpcHandler {
        target: "niri"
        function dump(): void {
            console.log(`Niri: ws=${root.workspaces.length} wins=${root.windows.length} active_ws=${root.activeWorkspaceId} focused_win=${root.focusedWindowId} overview=${root.overviewOpen}`)
        }
    }
}
