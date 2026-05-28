pragma Singleton
pragma ComponentBehavior: Bound

// Notifications —— 桌面通知中转 + 历史缓存
//
// 桥接 Quickshell.Services.Notifications.NotificationServer:
//   - 注册 D-Bus name org.freedesktop.Notifications,接管系统通知
//   - 每条通知收到时拍快照存入 history(即便客户端 expire/close 也保留)
//   - dashboard 通知面板从 history 读、显示、可逐条 dismiss 或全清
//
// 选择拍快照而不是直接持有 Notification 对象:
//   - 对象 close 后部分字段可能失效
//   - 历史可以独立于 server 生命周期
//
// keepOnReload=false:dev reload 时清空,避免重复显示

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // 历史(最新在前)
    property var history: []
    readonly property int count: root.history.length

    // 当前展开的卡片 id(-1 表示无),用于通知面板点击展开/收起 body
    property int expandedId: -1
    function toggleExpand(id: int): void {
        root.expandedId = (root.expandedId === id) ? -1 : id
    }

    // 上限:超过就丢最老的
    readonly property int maxHistory: 50

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            n.tracked = true
            const snap = {
                id: n.id,
                time: new Date(),
                appName: n.appName || "Unknown",
                appIcon: n.appIcon || "",
                summary: n.summary || "",
                body: n.body || "",
                image: n.image || "",
                urgency: n.urgency,
            }
            const next = root.history.slice()
            next.unshift(snap)
            if (next.length > root.maxHistory) next.length = root.maxHistory
            root.history = next
        }
    }

    function dismiss(id: int): void {
        root.history = root.history.filter(h => h.id !== id)
    }

    function clearAll(): void {
        root.history = []
    }

    function formatTime(d: var): string {
        if (!d) return ""
        const now = new Date()
        const diffMs = now.getTime() - d.getTime()
        const diffMin = Math.floor(diffMs / 60000)
        if (diffMin < 1) return "now"
        if (diffMin < 60) return diffMin + "m"
        const diffHr = Math.floor(diffMin / 60)
        if (diffHr < 24) return diffHr + "h"
        const diffDay = Math.floor(diffHr / 24)
        if (diffDay < 7) return diffDay + "d"
        return Qt.formatDateTime(d, "MM-dd")
    }
}
