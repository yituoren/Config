pragma ComponentBehavior: Bound

// WeatherTab —— dashboard "Weather" tab
//
// 布局方式:所有控件 anchors 绝对定位,**写死高度**;chart 例外 —— 两端同时 anchor,
// 高度由 anchors.top 和 anchors.bottom 之间的距离自动得出。这不是 Layout.fillHeight,
// 而是 anchor 计算,严格可预测。
//
// 上下两头是固定高度的"卡片"(topSec / cardsRow);中间 chart 吃 popup 高度变化带来的所有
// slack —— 小屏(popup 518)chart ≈ 126,大屏(popup 600)chart ≈ 208。
//
// 垂直布局:
//   topSec     116    top-anchored
//   sep1         1    8 上 8 下
//   title24h    16
//   chart      auto   4 上 / 8 下
//   sep2         1    8 上下
//   title7d     16    4 下
//   cardsRow   142    bottom-anchored

import QtQuick
import qs.services

Item {
    id: root

    readonly property bool ready: Weather.status === "ok" && Weather.current !== null

    // ────────── Loading / error 占位 ──────────
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !root.ready

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.status === "loading" ? "cloud_sync" : "cloud_off"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 56
            color: Theme.colors.on_surface_variant
            opacity: 0.45
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                switch (Weather.status) {
                case "loading": return "Loading weather…"
                case "error": return "Weather fetch failed"
                default: return "Waiting for location…"
                }
            }
            color: Theme.colors.on_surface_variant
            opacity: 0.6
            font.family: "Maple Mono NF CN"
            font.pixelSize: 13
            font.styleName: "Medium"
        }
    }

    // ────────── 主内容容器 ──────────
    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 0
        anchors.bottomMargin: 18
        visible: root.ready

        // ╔══════════════ topSec ══════════════╗
        Item {
            id: topSec
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 116

            // ── 右侧 city block ──
            Item {
                id: cityBlock
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 220

                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        anchors.right: parent.right
                        text: Weather.locationName
                            || (Weather.hasLocation
                                ? ("(" + Math.round(Weather.lat * 100) / 100 + ", " + Math.round(Weather.lon * 100) / 100 + ")")
                                : "—")
                        color: Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 24
                        font.styleName: "ExtraBold"
                    }
                    Text {
                        anchors.right: parent.right
                        text: Qt.formatDateTime(DateTime.now, "dddd, MMM d")
                        color: Theme.colors.on_surface_variant
                        opacity: 0.75
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 12
                        font.styleName: "Medium"
                    }
                    Text {
                        anchors.right: parent.right
                        text: "updated " + Weather.updatedAt
                        color: Theme.colors.on_surface_variant
                        opacity: 0.5
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 10
                        font.styleName: "Medium"
                    }
                }
            }

            // ── 左侧 5 cell ──
            Item {
                id: leftMain
                anchors.left: parent.left
                anchors.right: cityBlock.left
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                readonly property real spacingPx: 4
                readonly property real totalGap: leftMain.spacingPx * 4
                readonly property real big: (leftMain.width - leftMain.totalGap) * 0.32
                readonly property real small: (leftMain.width - leftMain.totalGap) * 0.17

                // Cell 1: icon + 大温度(左对齐,跟下方 chart / cards 同一列起点)
                Item {
                    id: cell1
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    x: 0
                    width: leftMain.big

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.codeIcon(Weather.currentCode, Weather.current ? Weather.current.isDay : true)
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 76
                            color: Theme.colors.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.current ? Math.round(Weather.current.temp) + "°" : "—"
                            color: Theme.colors.on_surface
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 58
                            font.styleName: "ExtraBold"
                        }
                    }
                }

                // Cell 2: condition + feels
                Item {
                    id: cell2
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    x: cell1.x + cell1.width + leftMain.spacingPx
                    width: leftMain.small

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.codeLabel(Weather.currentCode)
                            color: Theme.colors.on_surface
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 13
                            font.styleName: "ExtraBold"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Weather.current
                                ? "Feels " + Math.round(Weather.current.feels) + "°"
                                : ""
                            color: Theme.colors.on_surface_variant
                            opacity: 0.7
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 11
                            font.styleName: "Medium"
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Cells 3-5: humidity / wind / precip
                Repeater {
                    model: [
                        { icon: "humidity_percentage",
                          value: Weather.current ? Weather.current.humidity + "%" : "—",
                          label: "Humidity" },
                        { icon: "air",
                          value: Weather.current ? (Math.round(Weather.current.wind * 10) / 10) + " km/h" : "—",
                          label: "Wind" },
                        { icon: "rainy",
                          value: Weather.current ? Weather.current.precip + " mm" : "—",
                          label: "Precip" }
                    ]
                    delegate: Item {
                        id: detailCell
                        required property var modelData
                        required property int index

                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        x: cell2.x + cell2.width + leftMain.spacingPx
                            + (leftMain.small + leftMain.spacingPx) * detailCell.index
                        width: leftMain.small

                        Column {
                            anchors.centerIn: parent
                            spacing: 0

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: detailCell.modelData.icon
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 22
                                    color: Theme.colors.primary
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: detailCell.modelData.value
                                    color: Theme.colors.on_surface
                                    font.family: "Maple Mono NF CN"
                                    font.pixelSize: 14
                                    font.styleName: "ExtraBold"
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: detailCell.modelData.label
                                color: Theme.colors.on_surface_variant
                                opacity: 0.55
                                font.family: "Maple Mono NF CN"
                                font.pixelSize: 10
                                font.styleName: "Medium"
                            }
                        }
                    }
                }
            }
        }

        // sep1
        Rectangle {
            id: sep1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topSec.bottom
            anchors.topMargin: 8
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // title24h
        Text {
            id: title24h
            anchors.left: parent.left
            anchors.top: sep1.bottom
            anchors.topMargin: 8
            height: 16
            text: "Next 24 hours"
            color: Theme.colors.on_surface
            font.family: "Maple Mono NF CN"
            font.pixelSize: 13
            font.styleName: "ExtraBold"
            verticalAlignment: Text.AlignVCenter
        }

        // ╔══════════════ chart:两端 anchored,吃剩余 ══════════════╗
        Item {
            id: chart
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title24h.bottom
            anchors.topMargin: 4
            anchors.bottom: sep2.top
            anchors.bottomMargin: 8

            readonly property var series: Weather.hourlyNext24
            readonly property int n: chart.series.length

            readonly property real leftPad: 4
            readonly property real rightPad: 4
            readonly property real topPad: 14
            readonly property real bottomLabelH: 14
            readonly property real precipMaxH: 28

            readonly property real curveAreaH: chart.height - chart.topPad - chart.bottomLabelH - chart.precipMaxH - 4
            readonly property real curveTop: chart.topPad
            readonly property real curveBottom: chart.curveTop + chart.curveAreaH
            readonly property real precipBottom: chart.height - chart.bottomLabelH
            readonly property real plotW: chart.width - chart.leftPad - chart.rightPad

            readonly property real tempMin: {
                if (chart.n === 0) return 0
                let m = chart.series[0].temp
                for (let i = 1; i < chart.n; i++) if (chart.series[i].temp < m) m = chart.series[i].temp
                return m
            }
            readonly property real tempMax: {
                if (chart.n === 0) return 1
                let m = chart.series[0].temp
                for (let i = 1; i < chart.n; i++) if (chart.series[i].temp > m) m = chart.series[i].temp
                return m
            }
            readonly property real tempRange: Math.max(1, chart.tempMax - chart.tempMin)

            function xAt(i) {
                return chart.leftPad + chart.plotW * (i / Math.max(1, chart.n - 1))
            }
            function yAt(temp) {
                return chart.curveTop + chart.curveAreaH * (1 - (temp - chart.tempMin) / chart.tempRange)
            }

            Repeater {
                model: chart.series
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property real cellW: chart.plotW / Math.max(1, chart.n - 1)
                    readonly property real barH: chart.precipMaxH * Math.min(1, (modelData.precipProb ?? 0) / 100)
                    x: chart.xAt(index) - width / 2
                    y: chart.precipBottom - barH
                    width: Math.max(3, cellW * 0.45)
                    height: barH
                    radius: 2
                    color: Theme.colors.primary
                    opacity: 0.32
                    visible: (modelData.precipProb ?? 0) > 0
                }
            }

            Canvas {
                id: curveCanvas
                anchors.fill: parent
                contextType: "2d"

                property color stroke: Theme.colors.primary
                property color fillStart: Qt.rgba(Theme.colors.primary.r, Theme.colors.primary.g, Theme.colors.primary.b, 0.18)
                property color fillEnd: Qt.rgba(Theme.colors.primary.r, Theme.colors.primary.g, Theme.colors.primary.b, 0.0)

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const n = chart.n
                    if (n < 2) return

                    const pts = []
                    for (let i = 0; i < n; i++) pts.push({ x: chart.xAt(i), y: chart.yAt(chart.series[i].temp) })

                    const grad = ctx.createLinearGradient(0, chart.curveTop, 0, chart.curveBottom)
                    grad.addColorStop(0, curveCanvas.fillStart.toString())
                    grad.addColorStop(1, curveCanvas.fillEnd.toString())
                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, chart.curveBottom)
                    ctx.lineTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n - 1; i++) {
                        const midX = (pts[i].x + pts[i + 1].x) / 2
                        const midY = (pts[i].y + pts[i + 1].y) / 2
                        ctx.quadraticCurveTo(pts[i].x, pts[i].y, midX, midY)
                    }
                    ctx.lineTo(pts[n - 1].x, pts[n - 1].y)
                    ctx.lineTo(pts[n - 1].x, chart.curveBottom)
                    ctx.closePath()
                    ctx.fill()

                    ctx.strokeStyle = curveCanvas.stroke.toString()
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (let i = 1; i < n - 1; i++) {
                        const midX = (pts[i].x + pts[i + 1].x) / 2
                        const midY = (pts[i].y + pts[i + 1].y) / 2
                        ctx.quadraticCurveTo(pts[i].x, pts[i].y, midX, midY)
                    }
                    ctx.lineTo(pts[n - 1].x, pts[n - 1].y)
                    ctx.stroke()
                }

                Connections {
                    target: chart
                    function onWidthChanged() { curveCanvas.requestPaint() }
                    function onHeightChanged() { curveCanvas.requestPaint() }
                    function onSeriesChanged() { curveCanvas.requestPaint() }
                }
                Connections {
                    target: Theme
                    function onColorsChanged() {
                        curveCanvas.stroke = Theme.colors.primary
                        curveCanvas.fillStart = Qt.rgba(Theme.colors.primary.r, Theme.colors.primary.g, Theme.colors.primary.b, 0.18)
                        curveCanvas.fillEnd = Qt.rgba(Theme.colors.primary.r, Theme.colors.primary.g, Theme.colors.primary.b, 0.0)
                        curveCanvas.requestPaint()
                    }
                }
            }

            Repeater {
                model: chart.series
                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool isMax: modelData.temp >= chart.tempMax - 0.01
                    readonly property bool isMin: modelData.temp <= chart.tempMin + 0.01
                    readonly property bool show: (isMax || isMin) && index !== 0 && index !== chart.n - 1
                    visible: show
                    x: chart.xAt(index) - tipLabel.width / 2
                    y: chart.yAt(modelData.temp) - 14
                    width: tipLabel.width
                    height: tipLabel.height
                    Text {
                        id: tipLabel
                        text: Math.round(parent.modelData.temp) + "°"
                        color: Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 10
                        font.styleName: "ExtraBold"
                    }
                }
            }

            Repeater {
                model: chart.n
                delegate: Item {
                    required property int index
                    readonly property bool show: index === 0
                        || index === chart.n - 1
                        || index % 4 === 0
                    readonly property var d: chart.series[index]
                    visible: show && d
                    x: chart.xAt(index) - hLabel.width / 2
                    y: chart.height - chart.bottomLabelH
                    width: hLabel.width
                    height: chart.bottomLabelH
                    Text {
                        id: hLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: index === 0 ? "now" : Qt.formatDateTime(parent.d.time, "HH")
                        color: Theme.colors.on_surface_variant
                        opacity: 0.7
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 9
                        font.styleName: "Medium"
                    }
                }
            }
        }

        // sep2(直接锚到 cardsRow 上方,不再有 "Next 7 days" 标题)
        Rectangle {
            id: sep2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: cardsRow.top
            anchors.bottomMargin: 12
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ╔══════════════ cardsRow ══════════════╗
        // 142 高,内部三段固定 anchor:header 顶 / icon 中心 / footer 底,12px padding 均匀
        Item {
            id: cardsRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 142

            readonly property real spacingPx: 6
            readonly property real cardW: (cardsRow.width - cardsRow.spacingPx * 6) / 7

            Repeater {
                model: Weather.daily
                delegate: Rectangle {
                    id: dayCell
                    required property var modelData
                    required property int index
                    readonly property bool isToday: dayCell.index === 0

                    x: (cardsRow.cardW + cardsRow.spacingPx) * dayCell.index
                    y: 0
                    width: cardsRow.cardW
                    height: cardsRow.height
                    radius: 16
                    // wifi popup 同款配色
                    color: dayCell.isToday
                        ? Theme.colors.primary_container
                        : Theme.colors.surface_container

                    // ── header(顶,12 padding)──
                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCell.isToday
                                ? "Today"
                                : Qt.formatDateTime(dayCell.modelData.date, "ddd")
                            color: dayCell.isToday
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 13
                            font.styleName: "ExtraBold"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(dayCell.modelData.date, "MMM d")
                            color: dayCell.isToday
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface_variant
                            opacity: dayCell.isToday ? 0.8 : 0.6
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 10
                            font.styleName: "Medium"
                        }
                    }

                    // ── icon(垂直居中)──
                    Text {
                        anchors.centerIn: parent
                        text: Weather.codeIcon(dayCell.modelData.code, true)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 38
                        color: dayCell.isToday
                            ? Theme.colors.on_primary_container
                            : Theme.colors.primary
                    }

                    // ── footer(底,12 padding)──
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(dayCell.modelData.tmax) + "°"
                            color: dayCell.isToday
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 18
                            font.styleName: "ExtraBold"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(dayCell.modelData.tmin) + "°"
                            color: dayCell.isToday
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface_variant
                            opacity: 0.7
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: "Medium"
                        }
                    }
                }
            }
        }
    }

    // ╔══════════════ 天气特效层 ══════════════╗
    WeatherEffects {
        anchors.fill: parent
        z: 999
    }
}
