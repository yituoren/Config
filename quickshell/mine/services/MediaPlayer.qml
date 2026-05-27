pragma Singleton
pragma ComponentBehavior: Bound

// MediaPlayer —— MPRIS 薄壳
// active:手动选 > 正在播 > 第一个;过滤掉 playerctld 镜像总线避免重复
// active.position 不会自动 tick,要靠 Timer 周期性 positionChanged() 强制 quickshell 重读 DBus

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // 过滤后的 player 列表
    readonly property list<MprisPlayer> list: Mpris.players.values.filter(p =>
        !((p.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.playerctld"))
    )

    // 用户手动钉住的 player(在 UI 上点 player 切换器写它);失效会自动 fallback
    property MprisPlayer manualActive: null

    // 当前 active:钉住 > 正在播 > 第一个 > null
    readonly property MprisPlayer active: {
        if (root.manualActive && root.list.indexOf(root.manualActive) >= 0) return root.manualActive
        for (let i = 0; i < root.list.length; i++) {
            if (root.list[i].isPlaying) return root.list[i]
        }
        return root.list[0] ?? null
    }

    readonly property bool hasActive: root.active !== null

    // 封面 URL,带 youtube 缩略图兜底(参考 caelestia)
    function getArtUrl(player: var): string {
        if (!player) return ""
        if (player.trackArtUrl) return player.trackArtUrl
        const url = player.metadata?.["xesam:url"] ?? ""
        if (typeof url === "string" && url.startsWith("https://www.youtube.com/watch")) {
            const m = url.match(/[?&]v=([\w-]{11})/)
            if (m) return `https://img.youtube.com/vi/${m[1]}/hqdefault.jpg`
        }
        return ""
    }

    function getIdentity(player: var): string {
        if (!player) return ""
        return player.identity || (player.dbusName ?? "").split(".").pop() || "Unknown"
    }

    function formatTime(seconds: real): string {
        if (!seconds || seconds < 0 || !isFinite(seconds)) return "0:00"
        const total = Math.floor(seconds)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = (total % 60).toString().padStart(2, "0")
        if (h > 0) return `${h}:${m.toString().padStart(2, "0")}:${s}`
        return `${m}:${s}`
    }
}
