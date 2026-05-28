pragma Singleton
pragma ComponentBehavior: Bound

// Lyrics —— LRCLIB 歌词服务
//
// 监听 MediaPlayer.active 的 title/artist/album/length 变化,debounce 400ms 后
// 调 lrclib.net REST API,返回 syncedLyrics 解 LRC 时间戳,
// 暴露 prevLine / currentLine / nextLine 跟 active.position 联动。
//
// LRCLIB API(无鉴权):
//   GET https://lrclib.net/api/get?track_name=&artist_name=&album_name=&duration=
//   命中:200 + {syncedLyrics, plainLyrics, ...}
//   未命中:404 + {code:404, name:"TrackNotFound"}
//
// status:
//   "idle"     —— 无 active 或无 title
//   "loading"  —— curl 正在跑
//   "ok"       —— 拿到 syncedLyrics(有时间戳)
//   "plain"    —— 只有 plainLyrics(无时间戳,不滚动,只整体显示)
//   "miss"     —— 404 / 无歌词
//   "error"    —— curl / JSON 失败

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property var active: MediaPlayer.active

    readonly property string trackTitle: root.active ? (root.active.trackTitle ?? "") : ""
    readonly property string trackArtist: {
        const a = root.active
        if (!a) return ""
        const arr = a.trackArtists ?? []
        return arr.length > 0 ? arr[0] : ""
    }
    readonly property string trackAlbum: root.active ? (root.active.trackAlbum ?? "") : ""
    readonly property real duration: root.active ? (root.active.length ?? 0) : 0
    readonly property real position: root.active ? (root.active.position ?? 0) : 0

    // 解析后的歌词行 [{time: seconds, text: string}]
    property var lines: []
    property string status: "idle"
    property string source: ""

    // 当前 track signature,变了才重 fetch
    property string sig: ""

    onTrackTitleChanged: root.scheduleFetch()
    onTrackArtistChanged: root.scheduleFetch()
    onTrackAlbumChanged: root.scheduleFetch()
    onDurationChanged: root.scheduleFetch()

    function scheduleFetch(): void {
        const newSig = root.trackTitle + "|" + root.trackArtist + "|" + root.trackAlbum
        if (newSig === root.sig) return
        root.sig = newSig
        root.lines = []
        root.source = ""
        if (!root.trackTitle || !root.trackArtist) {
            root.status = "idle"
            debounce.stop()
            return
        }
        root.status = "loading"
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 400
        repeat: false
        onTriggered: root.fetch()
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || ""
                if (text.length === 0) {
                    root.status = "error"
                    return
                }
                try {
                    const data = JSON.parse(text)
                    if (data.code === 404 || (!data.syncedLyrics && !data.plainLyrics)) {
                        root.status = "miss"
                        root.lines = []
                        return
                    }
                    if (data.syncedLyrics && data.syncedLyrics.length > 0) {
                        root.lines = root.parseLrc(data.syncedLyrics)
                        root.status = root.lines.length > 0 ? "ok" : "miss"
                        root.source = "lrclib"
                    } else if (data.plainLyrics && data.plainLyrics.length > 0) {
                        // 无时间戳,造一个伪 line 数组(time=-1)只为整体展示
                        root.lines = data.plainLyrics.split("\n")
                            .filter(l => l.trim().length > 0)
                            .map(l => ({ time: -1, text: l }))
                        root.status = "plain"
                        root.source = "lrclib"
                    } else {
                        root.status = "miss"
                    }
                } catch (e) {
                    console.warn("Lyrics: JSON parse failed", e, text.substring(0, 120))
                    root.status = "error"
                }
            }
        }
    }

    function fetch(): void {
        if (!root.trackTitle || !root.trackArtist) {
            root.status = "idle"
            return
        }
        const params = []
        params.push("track_name=" + encodeURIComponent(root.trackTitle))
        params.push("artist_name=" + encodeURIComponent(root.trackArtist))
        if (root.trackAlbum) params.push("album_name=" + encodeURIComponent(root.trackAlbum))
        if (root.duration > 0) params.push("duration=" + Math.round(root.duration))
        const url = "https://lrclib.net/api/get?" + params.join("&")
        fetchProc.command = ["curl", "-fsSL", "--max-time", "8",
            "-A", "qs-mine-lyrics/0.1 (https://github.com/yituoren/dotfiles)", url]
        fetchProc.running = true
    }

    function parseLrc(text: string): var {
        const out = []
        const lines = text.split("\n")
        const re = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/g
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            re.lastIndex = 0
            const stamps = []
            let m
            let lastIdx = 0
            while ((m = re.exec(line)) !== null) {
                const min = parseInt(m[1], 10)
                const sec = parseInt(m[2], 10)
                const fracStr = m[3] ?? ""
                const frac = fracStr ? parseInt(fracStr.padEnd(3, "0"), 10) / 1000 : 0
                stamps.push(min * 60 + sec + frac)
                lastIdx = m.index + m[0].length
            }
            if (stamps.length === 0) continue
            const txt = line.substring(lastIdx).trim()
            for (let j = 0; j < stamps.length; j++) {
                out.push({ time: stamps[j], text: txt })
            }
        }
        out.sort((a, b) => a.time - b.time)
        return out
    }

    // 二分查找当前行(time <= position 的最大 index)
    readonly property int currentIndex: {
        const n = root.lines.length
        if (n === 0) return -1
        // plain 模式 time=-1,直接返回 -1(没有"当前一行"的概念)
        if (root.lines[0].time < 0) return -1
        const p = root.position
        let lo = 0, hi = n - 1, ans = -1
        while (lo <= hi) {
            const mid = (lo + hi) >> 1
            if (root.lines[mid].time <= p) {
                ans = mid
                lo = mid + 1
            } else hi = mid - 1
        }
        return ans
    }

    readonly property string currentLine: root.currentIndex >= 0 ? root.lines[root.currentIndex].text : ""
    readonly property string prevLine: root.currentIndex >= 1 ? root.lines[root.currentIndex - 1].text : ""
    readonly property string nextLine: (root.currentIndex >= 0 && root.currentIndex + 1 < root.lines.length)
        ? root.lines[root.currentIndex + 1].text : ""

    readonly property bool hasSynced: root.status === "ok"
}
