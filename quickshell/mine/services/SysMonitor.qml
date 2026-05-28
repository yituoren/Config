pragma Singleton
pragma ComponentBehavior: Bound

// SysMonitor —— 系统资源监控
//
// 数据源 /proc 文件:每秒一次 Process 跑一行 sh 把所有需要的文件 cat 出来,
// 中间用 ===NAME=== 分隔,QML 端 split 解析。比起每项一个 Process 省 fork。
// 磁盘 `df` 调用较慢,单独 10s 一次。
//
// 暴露指标:
//   CPU:     cpuUsage(0-1) / cpuPerCore[] / cpuTempC / cpuHistory[]
//   Memory:  memUsedGB / memTotalGB / memUsagePct / swapUsedGB / swapTotalGB
//   Load:    load1 / load5 / load15
//   Uptime:  uptimeSec / uptimeStr
//   Network: netRxBps / netTxBps / netRxHistory[] / netTxHistory[]
//   Disk:    diskMounts[]
//
// enabled 标志由消费者(目前 ControlTab)切换,关闭时停 Timer 省 CPU

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool enabled: false
    readonly property int historyLen: 60

    // ============ CPU ============
    property real cpuUsage: 0
    property var cpuPerCore: []
    property real cpuTempC: 0
    property var cpuHistory: []
    property string cpuModel: ""

    // ============ Memory ============
    property real memUsedGB: 0
    property real memTotalGB: 0
    property real memUsagePct: 0
    property real swapUsedGB: 0
    property real swapTotalGB: 0

    // ============ Load ============
    property real load1: 0
    property real load5: 0
    property real load15: 0

    // ============ Uptime ============
    property real uptimeSec: 0
    readonly property string uptimeStr: {
        const s = root.uptimeSec
        if (s <= 0) return "—"
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    // ============ Network ============
    property real netRxBps: 0
    property real netTxBps: 0
    property var netRxHistory: []
    property var netTxHistory: []

    // ============ GPU ============
    property string gpuName: ""
    property real gpuUsage: 0
    property real gpuMemUsedGB: 0
    property real gpuMemTotalGB: 0
    property real gpuTempC: 0
    property var gpuHistory: []
    property var vramHistory: []

    // ============ Disk ============
    property var diskMounts: []

    // ============ 内部 state ============
    property var _lastPerCore: null
    property var _lastNetStat: null
    property real _lastTickMs: 0

    Process {
        id: tickProc
        command: ["sh", "-c",
            "echo '===STAT==='; cat /proc/stat; " +
            "echo '===MEM==='; cat /proc/meminfo; " +
            "echo '===NET==='; cat /proc/net/dev; " +
            "echo '===LOAD==='; cat /proc/loadavg; " +
            "echo '===UPTIME==='; cat /proc/uptime; " +
            "echo '===TEMP==='; " +
            "for f in /sys/class/hwmon/hwmon*/temp1_input; do " +
            "  d=$(dirname \"$f\"); n=$(cat \"$d/name\" 2>/dev/null); v=$(cat \"$f\" 2>/dev/null); " +
            "  echo \"$n $v\"; " +
            "done; " +
            "echo '===GPU==='; " +
            "command -v nvidia-smi >/dev/null 2>&1 && " +
            "nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu " +
            "--format=csv,noheader,nounits 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.parseTick(this.text || "")
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay -x fuse 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDisk(this.text || "")
        }
    }

    function parseTick(text: string): void {
        // 行扫描:遇到 ===NAME=== 切 section,其余行 push 到当前 section 缓冲
        // (之前用 text.split("===") 会把 ===STAT=== 切成 ["", "STAT", "\n内容..."]
        //  错位导致 section name + content 不在同一片,所有解析失败)
        const lines = text.split("\n")
        const map = {}
        let curName = null
        let curLines = []
        const headerRe = /^===([A-Z]+)===$/
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(headerRe)
            if (m) {
                if (curName) map[curName] = curLines.join("\n")
                curName = m[1]
                curLines = []
            } else if (curName) {
                curLines.push(lines[i])
            }
        }
        if (curName) map[curName] = curLines.join("\n")

        if (map.STAT) root.parseStat(map.STAT)
        if (map.MEM) root.parseMem(map.MEM)
        if (map.NET) root.parseNet(map.NET)
        if (map.LOAD) root.parseLoad(map.LOAD)
        if (map.UPTIME) root.parseUptime(map.UPTIME)
        if (map.TEMP) root.parseTemp(map.TEMP)
        if (map.GPU) root.parseGpu(map.GPU)
    }

    function parseGpu(text: string): void {
        // CSV: name, util%, mem_used_MB, mem_total_MB, temp_C
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const ln = lines[i].trim()
            if (!ln) continue
            const parts = ln.split(",").map(p => p.trim())
            if (parts.length < 5) continue
            root.gpuName = parts[0]
            root.gpuUsage = (parseFloat(parts[1]) || 0) / 100
            root.gpuMemUsedGB = (parseFloat(parts[2]) || 0) / 1024
            root.gpuMemTotalGB = (parseFloat(parts[3]) || 0) / 1024
            root.gpuTempC = parseFloat(parts[4]) || 0

            const gh = root.gpuHistory.slice()
            gh.push(root.gpuUsage)
            while (gh.length > root.historyLen) gh.shift()
            root.gpuHistory = gh

            const vh = root.vramHistory.slice()
            const vramPct = root.gpuMemTotalGB > 0
                ? root.gpuMemUsedGB / root.gpuMemTotalGB
                : 0
            vh.push(vramPct)
            while (vh.length > root.historyLen) vh.shift()
            root.vramHistory = vh
            return
        }
    }

    // 启动读 CPU 型号(只读一次,基本不变)
    Process {
        id: cpuModelProc
        running: true
        command: ["sh", "-c",
            "awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = (this.text || "").trim()
                if (t) root.cpuModel = t
            }
        }
    }

    function parseStat(text: string): void {
        const cpus = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const ln = lines[i]
            if (!ln.startsWith("cpu")) continue
            const parts = ln.split(/\s+/)
            if (parts.length < 5) continue
            const nums = []
            for (let j = 1; j < parts.length; j++) nums.push(parseInt(parts[j], 10) || 0)
            const idle = nums[3] + (nums[4] || 0)
            let total = 0
            for (let j = 0; j < nums.length; j++) total += nums[j]
            cpus.push({ idle: idle, total: total })
        }
        if (root._lastPerCore && root._lastPerCore.length === cpus.length) {
            const newPerCore = []
            for (let i = 0; i < cpus.length; i++) {
                const cur = cpus[i]
                const prev = root._lastPerCore[i]
                const td = cur.total - prev.total
                const id = cur.idle - prev.idle
                const usage = td > 0 ? Math.max(0, Math.min(1, 1 - id / td)) : 0
                if (i === 0) {
                    root.cpuUsage = usage
                    const h = root.cpuHistory.slice()
                    h.push(usage)
                    while (h.length > root.historyLen) h.shift()
                    root.cpuHistory = h
                } else {
                    newPerCore.push(usage)
                }
            }
            root.cpuPerCore = newPerCore
        }
        root._lastPerCore = cpus
    }

    function parseMem(text: string): void {
        const map = {}
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\S+):\s+(\d+)/)
            if (m) map[m[1]] = parseInt(m[2], 10)
        }
        const total = map.MemTotal || 1
        const avail = map.MemAvailable
            ?? ((map.MemFree || 0) + (map.Buffers || 0) + (map.Cached || 0))
        const used = total - avail
        root.memTotalGB = total / (1024 * 1024)
        root.memUsedGB = used / (1024 * 1024)
        root.memUsagePct = used / total
        root.swapTotalGB = (map.SwapTotal || 0) / (1024 * 1024)
        root.swapUsedGB = ((map.SwapTotal || 0) - (map.SwapFree || 0)) / (1024 * 1024)
    }

    function parseNet(text: string): void {
        const lines = text.split("\n").slice(2)
        let totalRx = 0, totalTx = 0
        for (let i = 0; i < lines.length; i++) {
            const ln = lines[i].trim()
            if (!ln) continue
            const colonIdx = ln.indexOf(":")
            if (colonIdx < 0) continue
            const iface = ln.substring(0, colonIdx).trim()
            if (iface === "lo") continue
            const nums = ln.substring(colonIdx + 1).trim().split(/\s+/).map(Number)
            if (nums.length < 9) continue
            totalRx += nums[0] || 0
            totalTx += nums[8] || 0
        }
        const now = Date.now()
        if (root._lastNetStat && root._lastTickMs > 0) {
            const dt = (now - root._lastTickMs) / 1000
            if (dt > 0) {
                root.netRxBps = Math.max(0, (totalRx - root._lastNetStat.rx) / dt)
                root.netTxBps = Math.max(0, (totalTx - root._lastNetStat.tx) / dt)
                const rxH = root.netRxHistory.slice()
                rxH.push(root.netRxBps)
                while (rxH.length > root.historyLen) rxH.shift()
                root.netRxHistory = rxH
                const txH = root.netTxHistory.slice()
                txH.push(root.netTxBps)
                while (txH.length > root.historyLen) txH.shift()
                root.netTxHistory = txH
            }
        }
        root._lastNetStat = { rx: totalRx, tx: totalTx }
        root._lastTickMs = now
    }

    function parseLoad(text: string): void {
        const m = text.match(/^(\S+)\s+(\S+)\s+(\S+)/)
        if (m) {
            root.load1 = parseFloat(m[1])
            root.load5 = parseFloat(m[2])
            root.load15 = parseFloat(m[3])
        }
    }

    function parseUptime(text: string): void {
        const m = text.match(/^(\S+)/)
        if (m) root.uptimeSec = parseFloat(m[1])
    }

    function parseTemp(text: string): void {
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/)
            if (parts.length < 2) continue
            const name = parts[0]
            const val = parseInt(parts[1], 10)
            if (!val) continue
            // 优先 CPU 温度源(AMD: k10temp / zenpower, Intel: coretemp)
            if (name === "k10temp" || name === "coretemp" || name === "zenpower") {
                root.cpuTempC = val / 1000
                return
            }
        }
    }

    function parseDisk(text: string): void {
        const out = []
        const lines = text.split("\n")
        for (let i = 1; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/)
            if (parts.length < 6) continue
            const total = parseInt(parts[1], 10)
            const used = parseInt(parts[2], 10)
            const mount = parts[parts.length - 1]
            if (total < 1024 * 1024 * 100) continue   // 跳过 < 100MB
            out.push({
                mount: mount,
                used: used,
                total: total,
                pct: total > 0 ? used / total : 0,
                usedGB: used / (1024 * 1024 * 1024),
                totalGB: total / (1024 * 1024 * 1024)
            })
        }
        out.sort((a, b) => b.total - a.total)
        root.diskMounts = out.slice(0, 4)
    }

    function fmtBps(bps: real): string {
        if (bps < 1024) return Math.round(bps) + " B/s"
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s"
        if (bps < 1024 * 1024 * 1024) return (bps / 1024 / 1024).toFixed(1) + " MB/s"
        return (bps / 1024 / 1024 / 1024).toFixed(2) + " GB/s"
    }

    Timer {
        interval: 1500
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!tickProc.running) tickProc.running = true }
    }

    Timer {
        interval: 10000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!diskProc.running) diskProc.running = true }
    }
}
