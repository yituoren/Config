pragma ComponentBehavior: Bound

// ControlTab —— dashboard "Control" tab
//
// btop 风格,严格写死位置,纯主题色。size 为 popup 600 高(content 520)优化,
// 上下、左右、各 section 之间 padding 16 统一:
//
//   y 16-44     header strip       h 28    uptime / load / CPU temp
//   y 60-244    metric rows        h 184   3 行 × 60 + 2 × 4 gap,2 列
//   y 260-360   graph CPU/GPU      h 100   左右各 390 宽
//   y 376-496   Network 段         h 120   ↓ + ↑ 各 42 高带曲线
//
// 坐标系:popup 内容宽 860,左右 28 padding → 内容宽 804
//         左列 x 28  右列 x 442  各 w 390  列间隔 24

import QtQuick
import qs.services

Item {
    id: root

    Component.onCompleted: SysMonitor.enabled = true
    Component.onDestruction: SysMonitor.enabled = false

    readonly property bool hasData:
        SysMonitor.cpuPerCore.length > 0 || SysMonitor.memTotalGB > 0

    // ═══════════════ 文本工具 ═══════════════
    function shortCpu(s: string): string {
        return s.replace(/\(R\)|\(TM\)|\bCPU\b|\bProcessor\b/g, "")
            .replace(/\s+/g, " ").trim()
    }
    function shortGpu(s: string): string {
        return s.replace(/NVIDIA |GeForce /g, "").trim()
    }

    // ═══════════════ 数据模型 ═══════════════
    readonly property var leftMetrics: {
        const out = []
        out.push({
            icon: "memory",
            label: "CPU",
            pct: SysMonitor.cpuUsage,
            value: (SysMonitor.cpuTempC > 0
                ? Math.round(SysMonitor.cpuTempC) + "°C"
                : "—"),
            spec: SysMonitor.cpuModel
                ? root.shortCpu(SysMonitor.cpuModel) + " · " + SysMonitor.cpuPerCore.length + " cores"
                : SysMonitor.cpuPerCore.length + " cores"
        })
        out.push({
            icon: "developer_board",
            label: "RAM",
            pct: SysMonitor.memUsagePct,
            value: SysMonitor.memUsedGB.toFixed(1) + "/" + SysMonitor.memTotalGB.toFixed(1) + " GB",
            spec: SysMonitor.memTotalGB.toFixed(0) + " GB total"
        })
        // 第一个 disk
        if (SysMonitor.diskMounts.length > 0) {
            const d = SysMonitor.diskMounts[0]
            out.push({
                icon: "hard_drive",
                label: d.mount,
                pct: d.pct,
                value: d.usedGB.toFixed(0) + "/" + d.totalGB.toFixed(0) + " GB",
                spec: "Filesystem " + d.totalGB.toFixed(0) + " GB"
            })
        }
        return out
    }

    readonly property var rightMetrics: {
        const out = []
        if (SysMonitor.gpuName) {
            out.push({
                icon: "deployed_code",
                label: "GPU",
                pct: SysMonitor.gpuUsage,
                value: SysMonitor.gpuTempC > 0
                    ? Math.round(SysMonitor.gpuTempC) + "°C"
                    : "—",
                spec: root.shortGpu(SysMonitor.gpuName)
            })
            out.push({
                icon: "auto_awesome_mosaic",
                label: "VRAM",
                pct: SysMonitor.gpuMemTotalGB > 0
                    ? SysMonitor.gpuMemUsedGB / SysMonitor.gpuMemTotalGB
                    : 0,
                value: SysMonitor.gpuMemUsedGB.toFixed(1) + "/" + SysMonitor.gpuMemTotalGB.toFixed(1) + " GB",
                spec: SysMonitor.gpuMemTotalGB.toFixed(0) + " GB GDDR"
            })
        }
        if (SysMonitor.swapTotalGB > 0) {
            out.push({
                icon: "swap_horiz",
                label: "Swap",
                pct: SysMonitor.swapTotalGB > 0
                    ? SysMonitor.swapUsedGB / SysMonitor.swapTotalGB
                    : 0,
                value: SysMonitor.swapUsedGB.toFixed(1) + "/" + SysMonitor.swapTotalGB.toFixed(1) + " GB",
                spec: SysMonitor.swapTotalGB.toFixed(0) + " GB swap"
            })
        }
        // 后续 disks
        for (let i = 1; i < SysMonitor.diskMounts.length && out.length < 3; i++) {
            const d = SysMonitor.diskMounts[i]
            out.push({
                icon: "hard_drive",
                label: d.mount,
                pct: d.pct,
                value: d.usedGB.toFixed(0) + "/" + d.totalGB.toFixed(0) + " GB",
                spec: "Filesystem " + d.totalGB.toFixed(0) + " GB"
            })
        }
        return out
    }

    // ═══════════════ Loading 占位 ═══════════════
    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: !root.hasData

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "memory"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 48
            color: Theme.colors.on_surface_variant
            opacity: 0.45
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Loading system stats…"
            color: Theme.colors.on_surface_variant
            opacity: 0.6
            font.family: "Maple Mono NF CN"
            font.pixelSize: 13
            font.styleName: "Medium"
        }
    }

    // ═══════════════ Header strip (y 16, h 28) ═══════════════
    Item {
        x: 28
        y: 16
        width: 804
        height: 28
        visible: root.hasData

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Row {
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "schedule"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.colors.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Uptime"
                    color: Theme.colors.on_surface_variant
                    opacity: 0.7
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Medium"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SysMonitor.uptimeStr
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "ExtraBold"
                }
            }

            Row {
                spacing: 5
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "speed"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.colors.on_surface_variant
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Load"
                    color: Theme.colors.on_surface_variant
                    opacity: 0.7
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Medium"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SysMonitor.load1.toFixed(2) + "  "
                        + SysMonitor.load5.toFixed(2) + "  "
                        + SysMonitor.load15.toFixed(2)
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "ExtraBold"
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "device_thermostat"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: SysMonitor.cpuTempC > 80
                    ? Theme.colors.error
                    : Theme.colors.on_surface_variant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitor.cpuTempC > 0
                    ? Math.round(SysMonitor.cpuTempC) + "°C"
                    : "—"
                color: Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 13
                font.styleName: "ExtraBold"
            }
        }
    }

    // ═══════════════ Metric row 复用组件 ═══════════════
    // 每行 60 高:main(36)+ gap(4) + spec(20)
    // 内部布局(col width 390):
    //   icon 22 / gap 6 / label 56 / gap 6 / % 44 / gap 6 / bar 168 / gap 6 / right 76
    component MetricRow: Item {
        id: row
        property var metric: ({})
        width: 390
        height: 60

        // 主行
        Item {
            x: 0
            y: 0
            width: 390
            height: 36

            Text {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: row.metric.icon ?? ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: Theme.colors.on_surface_variant
            }
            Text {
                x: 28
                width: 56
                anchors.verticalCenter: parent.verticalCenter
                text: row.metric.label ?? ""
                color: Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 14
                font.styleName: "ExtraBold"
                elide: Text.ElideRight
            }
            Text {
                x: 90
                width: 44
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round((row.metric.pct ?? 0) * 100) + "%"
                color: (row.metric.pct ?? 0) > 0.85
                    ? Theme.colors.error
                    : Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 16
                font.styleName: "ExtraBold"
                horizontalAlignment: Text.AlignRight
            }
            Rectangle {
                x: 140
                anchors.verticalCenter: parent.verticalCenter
                width: 168
                height: 12
                radius: 6
                color: Theme.colors.surface_container_high
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0, Math.min(1, row.metric.pct ?? 0))
                    radius: 6
                    color: (row.metric.pct ?? 0) > 0.85
                        ? Theme.colors.error
                        : Theme.colors.primary
                }
            }
            Text {
                x: 314
                width: 76
                anchors.verticalCenter: parent.verticalCenter
                text: row.metric.value ?? ""
                color: Theme.colors.on_surface_variant
                font.family: "Maple Mono NF CN"
                font.pixelSize: 12
                font.styleName: "Medium"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        // Spec 副行
        Text {
            x: 28
            y: 40
            width: 362
            height: 20
            text: row.metric.spec ?? ""
            color: Theme.colors.on_surface_variant
            opacity: 0.6
            font.family: "Maple Mono NF CN"
            font.pixelSize: 11
            font.styleName: "Medium"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    // ═══════════════ Metrics 左列 (x 28, y 60) ═══════════════
    // 每槽位 64 高(60 + 4 gap),3 行总高 184
    Repeater {
        model: root.leftMetrics
        delegate: MetricRow {
            required property var modelData
            required property int index
            metric: modelData
            x: 28
            y: 60 + index * 64
            visible: root.hasData
        }
    }

    // ═══════════════ Metrics 右列 (x 442, y 60) ═══════════════
    Repeater {
        model: root.rightMetrics
        delegate: MetricRow {
            required property var modelData
            required property int index
            metric: modelData
            x: 442
            y: 60 + index * 64
            visible: root.hasData
        }
    }

    // ═══════════════ History 曲线复用组件 ═══════════════
    component HistoryGraph: Item {
        id: graph
        property var values: []
        property color tint: Theme.colors.primary
        property string title: ""
        property string subtitle: ""
        property real maxVal: 1

        // 卡片底
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.colors.surface_container
        }

        // 标题
        Item {
            x: 14
            y: 8
            width: graph.width - 28
            height: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: graph.title
                color: Theme.colors.on_surface
                font.family: "Maple Mono NF CN"
                font.pixelSize: 11
                font.styleName: "ExtraBold"
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: graph.subtitle
                color: Theme.colors.on_surface_variant
                opacity: 0.7
                font.family: "Maple Mono NF CN"
                font.pixelSize: 10
                font.styleName: "ExtraBold"
            }
        }

        // 曲线 Canvas
        Canvas {
            id: canv
            x: 8
            y: 30
            width: graph.width - 16
            height: graph.height - 38
            contextType: "2d"

            property var src: graph.values
            property color tnt: graph.tint
            property real mx: graph.maxVal
            onSrcChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const v = canv.src
                const n = v.length
                if (n < 2) return
                const pts = []
                const m = canv.mx > 0 ? canv.mx : 1
                for (let i = 0; i < n; i++) {
                    const x = (i / Math.max(1, n - 1)) * width
                    const y = height - (v[i] / m) * height
                    pts.push({ x: x, y: y })
                }
                const c = canv.tnt
                const grad = ctx.createLinearGradient(0, 0, 0, height)
                grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.40).toString())
                grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0).toString())
                ctx.fillStyle = grad
                ctx.beginPath()
                ctx.moveTo(pts[0].x, height)
                ctx.lineTo(pts[0].x, pts[0].y)
                for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                ctx.lineTo(pts[n - 1].x, height)
                ctx.closePath()
                ctx.fill()
                ctx.strokeStyle = c.toString()
                ctx.lineWidth = 1.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                ctx.stroke()
            }
        }
    }

    // ═══════════════ CPU graph (左下, y 260, h 100) ═══════════════
    HistoryGraph {
        x: 28
        y: 260
        width: 390
        height: 100
        visible: root.hasData
        title: "CPU usage"
        subtitle: Math.round(SysMonitor.cpuUsage * 100) + "%"
        tint: Theme.colors.primary
        values: SysMonitor.cpuHistory
        maxVal: 1
    }

    // ═══════════════ GPU graph (右下) ═══════════════
    HistoryGraph {
        x: 442
        y: 260
        width: 390
        height: 100
        visible: root.hasData && SysMonitor.gpuName !== ""
        title: "GPU usage"
        subtitle: Math.round(SysMonitor.gpuUsage * 100) + "%"
        tint: Theme.colors.primary
        values: SysMonitor.gpuHistory
        maxVal: 1
    }

    // ═══════════════ Network 段(y 376, h 120) ═══════════════
    Item {
        x: 28
        y: 376
        width: 804
        height: 120
        visible: root.hasData

        Rectangle {
            x: 0
            y: 0
            width: 804
            height: 1
            color: Theme.colors.surface_container_high
        }
        Text {
            x: 0
            y: 4
            height: 20
            text: "Network"
            color: Theme.colors.on_surface
            font.family: "Maple Mono NF CN"
            font.pixelSize: 13
            font.styleName: "ExtraBold"
            verticalAlignment: Text.AlignVCenter
        }

        // ↓ 行
        Item {
            x: 0
            y: 32
            width: 804
            height: 40

            Text {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_downward"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: Theme.colors.primary
            }
            Text {
                x: 32
                width: 150
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitor.fmtBps(SysMonitor.netRxBps)
                color: Theme.colors.primary
                font.family: "Maple Mono NF CN"
                font.pixelSize: 17
                font.styleName: "ExtraBold"
            }
            Canvas {
                id: rxCanvas
                x: 190
                y: 0
                width: 614
                height: 40
                contextType: "2d"
                property var values: SysMonitor.netRxHistory
                onValuesChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const v = rxCanvas.values
                    const n = v.length
                    if (n < 2) return
                    let mx = 0
                    for (let i = 0; i < n; i++) if (v[i] > mx) mx = v[i]
                    if (mx < 1024) mx = 1024
                    const c = Theme.colors.primary
                    const pts = []
                    for (let i = 0; i < n; i++) {
                        const x = (i / Math.max(1, n - 1)) * width
                        const y = height - (v[i] / mx) * height
                        pts.push({ x: x, y: y })
                    }
                    const grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.40).toString())
                    grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0).toString())
                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, height)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.lineTo(pts[n - 1].x, height)
                    ctx.closePath()
                    ctx.fill()
                    ctx.strokeStyle = c.toString()
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.stroke()
                }
            }
        }

        // ↑ 行
        Item {
            x: 0
            y: 78
            width: 804
            height: 40

            Text {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_upward"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: Theme.colors.primary
            }
            Text {
                x: 32
                width: 150
                anchors.verticalCenter: parent.verticalCenter
                text: SysMonitor.fmtBps(SysMonitor.netTxBps)
                color: Theme.colors.primary
                font.family: "Maple Mono NF CN"
                font.pixelSize: 17
                font.styleName: "ExtraBold"
            }
            Canvas {
                id: txCanvas
                x: 190
                y: 0
                width: 614
                height: 40
                contextType: "2d"
                property var values: SysMonitor.netTxHistory
                onValuesChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const v = txCanvas.values
                    const n = v.length
                    if (n < 2) return
                    let mx = 0
                    for (let i = 0; i < n; i++) if (v[i] > mx) mx = v[i]
                    if (mx < 1024) mx = 1024
                    const c = Theme.colors.primary
                    const pts = []
                    for (let i = 0; i < n; i++) {
                        const x = (i / Math.max(1, n - 1)) * width
                        const y = height - (v[i] / mx) * height
                        pts.push({ x: x, y: y })
                    }
                    const grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.40).toString())
                    grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0).toString())
                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, height)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.lineTo(pts[n - 1].x, height)
                    ctx.closePath()
                    ctx.fill()
                    ctx.strokeStyle = c.toString()
                    ctx.lineWidth = 1.6
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n; i++) ctx.lineTo(pts[i].x, pts[i].y)
                    ctx.stroke()
                }
            }
        }
    }
}
