pragma Singleton
pragma ComponentBehavior: Bound

// SystemStatus —— 电池 / WiFi / 音量 的轮询采集
//
// 三组 Process + Timer 独立运行。轮询周期:
//   - battery: 10s   (电量变化慢)
//   - wifi:    5s    (连接状态偶尔变)
//   - volume:  2s    (用户调音量希望快速反馈;本地操作时 setVolume / toggleMute 会做乐观更新)
//
// 后续可换成 reactive(udev 监听电池 / nmcli monitor / wpctl subscribe),现在轮询足够。

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============ 电池 ============

    // -1 = 未轮询过;0-100 = 实际百分比;NaN guard 下视为 -1
    property int batteryPercent: -1
    property string batteryStatus: ""   // "Charging" / "Discharging" / "Not charging" / "Full" / "Unknown"
    readonly property bool batteryCharging: root.batteryStatus === "Charging"
    readonly property bool hasBattery: root.batteryPercent >= 0

    Process {
        id: batCapProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim())
                if (!isNaN(v)) root.batteryPercent = v
            }
        }
    }
    Process {
        id: batStatProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                if (s.length > 0) root.batteryStatus = s
            }
        }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batCapProc.running = true
            batStatProc.running = true
        }
    }

    // ============ WiFi ============

    property bool wifiConnected: false
    property int wifiSignal: 0          // 0-100
    property string wifiSsid: ""
    // 扫到的网络列表(包含已连接的);wifi popup 用
    // 元素:{ ssid: string, signal: int, secured: bool, inUse: bool }
    property var wifiNetworks: []

    // wifi 开关 + 飞行模式
    property bool wifiEnabled: true
    // 飞行模式 = wifi 关 && bluetooth 关(派生,不单独存,免得跟硬件状态对不上)
    readonly property bool airplaneMode: !root.wifiEnabled && !root.bluetoothPowered

    Process {
        id: wifiProc
        // -t 用 colon 分隔;SSID 含 colon 会被 \: 转义
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                // 按 SSID 去重:一个 SSID 可能有多个 AP(BSSID),只留信号最强的那个
                // 已连接的那条用 inUse 标记保留(优先于强信号那条)
                const bySsid = ({})
                let foundCurrent = false

                for (const line of lines) {
                    // 解析 -t 格式:\: 是字段内的 literal colon,裸 : 是分隔符
                    const parts = []
                    let buf = ""
                    let i = 0
                    while (i < line.length) {
                        const c = line[i]
                        if (c === '\\' && i + 1 < line.length) {
                            buf += line[i + 1]
                            i += 2
                        } else if (c === ':') {
                            parts.push(buf)
                            buf = ""
                            i++
                        } else {
                            buf += c
                            i++
                        }
                    }
                    parts.push(buf)
                    if (parts.length < 4) continue

                    const inUse = parts[0] === "*"
                    const ssid = parts[1]
                    const signal = parseInt(parts[2]) || 0
                    const security = parts[3]
                    if (!ssid) continue  // 跳过隐藏网络

                    const existing = bySsid[ssid]
                    // 保留规则:inUse 优先;否则信号强的
                    if (!existing || inUse || (!existing.inUse && signal > existing.signal)) {
                        bySsid[ssid] = {
                            ssid: ssid,
                            signal: signal,
                            secured: security !== "" && security !== "--",
                            inUse: inUse
                        }
                    }

                    if (inUse && !foundCurrent) {
                        root.wifiConnected = true
                        root.wifiSignal = signal
                        root.wifiSsid = ssid
                        foundCurrent = true
                    }
                }

                if (!foundCurrent) {
                    root.wifiConnected = false
                    root.wifiSignal = 0
                    root.wifiSsid = ""
                }

                // 按信号强度降序(已连接的优先放最前)
                const list = Object.values(bySsid)
                list.sort((a, b) => {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1
                    return b.signal - a.signal
                })
                root.wifiNetworks = list
            }
        }
    }
    // 查询 wifi 是否被启用(nmcli radio wifi)
    Process {
        id: wifiRadioProc
        command: ["nmcli", "-t", "-f", "WIFI", "g"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = this.text.trim().toLowerCase() === "enabled"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiProc.running = true
            wifiRadioProc.running = true
        }
    }

    // 手动触发刷新(popup 打开时调一次)
    function refreshWifi(): void {
        wifiProc.running = true
        wifiRadioProc.running = true
    }

    // 连接指定 SSID(已存过密码的直接连,新网络需要密码会失败 — 后续做密码弹窗)
    function connectWifi(ssid: string): void {
        wifiConnect.command = ["nmcli", "device", "wifi", "connect", ssid]
        wifiConnect.running = true
    }

    function toggleWifi(): void {
        wifiToggle.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]
        wifiToggle.running = true
        root.wifiEnabled = !root.wifiEnabled  // 乐观更新
    }

    // 飞行模式:同时关 wifi + bluetooth(开:同时恢复)
    function toggleAirplaneMode(): void {
        const turningOn = !root.airplaneMode
        wifiToggle.command = ["nmcli", "radio", "wifi", turningOn ? "off" : "on"]
        wifiToggle.running = true
        airplaneBtProc.command = ["bluetoothctl", "power", turningOn ? "off" : "on"]
        airplaneBtProc.running = true
        root.wifiEnabled = !turningOn
        root.bluetoothPowered = !turningOn
    }

    Process { id: wifiConnect }
    Process { id: wifiToggle }
    Process { id: airplaneBtProc }

    // ============ 蓝牙 ============
    //
    // 依赖 bluetoothctl(包名 bluez-utils)。没装 bluetoothctl 时所有 Process 失败,
    // 三个属性保持初值(false/0),Widget 显示"关闭"状态,无破坏性。
    //
    // 状态分三档:
    //   bluetoothPowered=false        → 未通电(关 / 未装 utils)
    //   bluetoothPowered=true, conn=0 → 通电但无设备连接
    //   bluetoothConnected=true       → 至少一个设备连接中

    property bool bluetoothPowered: false
    property bool bluetoothConnected: false
    property int bluetoothDeviceCount: 0
    // 已配对的设备列表;bluetooth popup 用
    // 元素:{ mac: string, name: string, connected: bool }
    property var bluetoothDevices: []

    Process {
        id: btShowProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                // 输出含 "Powered: yes"(开启)或 "Powered: no"(关闭)
                root.bluetoothPowered = this.text.includes("Powered: yes")
            }
        }
    }

    // 一次拉 paired + connected,用 sh 拼输出,前面加分隔符方便切分
    Process {
        id: btDevsProc
        command: ["sh", "-c", "echo '###paired'; bluetoothctl devices Paired; echo '###connected'; bluetoothctl devices Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text
                const pairedSec = text.match(/###paired\n([\s\S]*?)\n###connected/)
                const connSec = text.match(/###connected\n([\s\S]*)/)

                const paired = []
                const connectedMacs = ({})

                if (pairedSec) {
                    for (const line of pairedSec[1].split("\n")) {
                        const m = line.match(/^Device (\S+) (.+)$/)
                        if (m) paired.push({ mac: m[1], name: m[2] })
                    }
                }
                if (connSec) {
                    for (const line of connSec[1].split("\n")) {
                        const m = line.match(/^Device (\S+) /)
                        if (m) connectedMacs[m[1]] = true
                    }
                }

                const devices = paired.map(d => ({
                    mac: d.mac,
                    name: d.name,
                    connected: !!connectedMacs[d.mac]
                }))
                // 已连接的排前,再按名字排序
                devices.sort((a, b) => {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    return a.name.localeCompare(b.name)
                })

                const connCount = Object.keys(connectedMacs).length
                root.bluetoothDevices = devices
                root.bluetoothDeviceCount = connCount
                root.bluetoothConnected = connCount > 0
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            btShowProc.running = true
            btDevsProc.running = true
        }
    }

    function refreshBluetooth(): void {
        btShowProc.running = true
        btDevsProc.running = true
    }

    function toggleBluetooth(): void {
        btToggle.command = [
            "bluetoothctl", "power", root.bluetoothPowered ? "off" : "on"
        ]
        btToggle.running = true
        root.bluetoothPowered = !root.bluetoothPowered  // 乐观更新
    }

    function connectBluetoothDevice(mac: string): void {
        btConnect.command = ["bluetoothctl", "connect", mac]
        btConnect.running = true
    }

    function disconnectBluetoothDevice(mac: string): void {
        btConnect.command = ["bluetoothctl", "disconnect", mac]
        btConnect.running = true
    }

    Process { id: btToggle }
    Process { id: btConnect }

    // ============ 音量 ============

    property real volume: 0             // 0.0 - 1.0
    property bool volumeMuted: false
    readonly property int volumePercent: Math.round(root.volume * 100)

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                // 输出格式: "Volume: 0.40" 或 "Volume: 0.40 [MUTED]"
                const m = this.text.match(/Volume:\s*([0-9.]+)(\s*\[MUTED\])?/)
                if (m) {
                    root.volume = parseFloat(m[1])
                    root.volumeMuted = !!m[2]
                }
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: volProc.running = true
    }

    function setVolumeDelta(stepPercent: int): void {
        // 相对调节,bar widget 滚轮用
        const sign = stepPercent >= 0 ? "+" : "-"
        const mag = Math.abs(stepPercent)
        volStep.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${mag}%${sign}`]
        volStep.running = true
        const next = Math.max(0, Math.min(1, root.volume + stepPercent / 100))
        root.volume = next
    }

    function setVolume(absolute: real): void {
        // 绝对值 0-1,SliderBar 拖动用
        const p = Math.max(0, Math.min(1, absolute))
        volSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", String(p)]
        volSet.running = true
        root.volume = p
    }

    function toggleMute(): void {
        volMute.running = true
        root.volumeMuted = !root.volumeMuted
    }

    Process { id: volStep }
    Process { id: volSet }
    Process {
        id: volMute
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    }

    // ============ 音频输出设备(sink)============
    //
    // 一次 pactl 拉 default sink + 所有 sink 列表,解析后给 popup 用
    // 元素:{ id, name, description, isDefault }
    property var audioSinks: []
    property string defaultSinkName: ""

    Process {
        id: audioSinksProc
        command: ["sh", "-c", "pactl get-default-sink; echo '###sinks###'; pactl list sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const sections = this.text.split("###sinks###")
                if (sections.length < 2) return
                const defaultName = sections[0].trim()
                const sinksText = sections[1]

                const sinks = []
                // pactl list sinks 输出按 "Sink #N\n" 分块
                const blocks = sinksText.split(/^Sink #/m).slice(1)
                for (const block of blocks) {
                    const idMatch = block.match(/^(\d+)/)
                    const nameMatch = block.match(/\n\s*Name:\s+(\S+)/)
                    const descMatch = block.match(/\n\s*Description:\s+(.+)/)
                    if (idMatch && nameMatch) {
                        const sinkName = nameMatch[1].trim()
                        sinks.push({
                            id: parseInt(idMatch[1]),
                            name: sinkName,
                            description: descMatch ? descMatch[1].trim() : sinkName,
                            isDefault: sinkName === defaultName
                        })
                    }
                }
                // default 优先,然后按描述排
                sinks.sort((a, b) => {
                    if (a.isDefault !== b.isDefault) return a.isDefault ? -1 : 1
                    return a.description.localeCompare(b.description)
                })
                root.audioSinks = sinks
                root.defaultSinkName = defaultName
            }
        }
    }

    Timer {
        interval: 10000  // sink 变化频率低,10s 够
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: audioSinksProc.running = true
    }

    function refreshAudio(): void {
        audioSinksProc.running = true
        volProc.running = true
    }

    function setDefaultSink(sinkName: string): void {
        setDefaultSinkProc.command = ["pactl", "set-default-sink", sinkName]
        setDefaultSinkProc.running = true
        // 乐观更新
        root.defaultSinkName = sinkName
        root.audioSinks = root.audioSinks.map(s => ({
            id: s.id, name: s.name, description: s.description,
            isDefault: s.name === sinkName
        }))
    }

    Process { id: setDefaultSinkProc }

    // ============ 屏幕亮度(每屏独立)============
    //
    // 内屏(eDP/LVDS/DSI)走 brightnessctl(读 /sys/class/backlight,基本即时)
    // 外屏走 ddcutil(走 I2C/DDC-CI,需要 ddcutil + 用户在 i2c 组 / 装 udev 规则;较慢,1-3s/call)
    //
    // brightnessByScreen 是 { "eDP-1": 0.85, "DP-2": 0.50 } 这样的 map,popup 按
    // PopupManager.currentScreen.name 取自己屏的值。
    property var brightnessByScreen: ({})

    function brightnessBackendFor(screenName: string): string {
        return /^(eDP|LVDS|DSI)/i.test(screenName) ? "brightnessctl" : "ddcutil"
    }

    function fetchBrightnessFor(screenName: string): void {
        if (!screenName) return
        const backend = root.brightnessBackendFor(screenName)
        if (backend === "brightnessctl") {
            brightnessctlRead._target = screenName
            brightnessctlRead.running = true
        } else {
            ddcutilRead._target = screenName
            ddcutilRead.running = true
        }
    }

    function setBrightnessFor(screenName: string, value: real): void {
        if (!screenName) return
        const v = Math.max(0.05, Math.min(1, value))
        const backend = root.brightnessBackendFor(screenName)
        // 乐观更新本地状态(slider 实时跟手),实际写入按后端决定时机
        const next = Object.assign({}, root.brightnessByScreen)
        next[screenName] = v
        root.brightnessByScreen = next

        if (backend === "brightnessctl") {
            // 快,直接发
            brightnessctlSet.command = ["brightnessctl", "s", `${Math.round(v * 100)}%`, "-q"]
            brightnessctlSet.running = true
        } else {
            // ddcutil 走 I2C/DDC,单次调用 1-3s。drag 时每个 onPositionChanged 都 fire 会堆死,
            // 改成 debounce:停止操作 250ms 后发最后一个值
            root._pendingBrightnessValue = v
            root._pendingBrightnessScreen = screenName
            ddcutilDebounce.restart()
        }
    }

    property real _pendingBrightnessValue: -1
    property string _pendingBrightnessScreen: ""
    Timer {
        id: ddcutilDebounce
        interval: 250
        repeat: false
        onTriggered: {
            if (!root._pendingBrightnessScreen) return
            ddcutilSet.command = [
                "ddcutil", "setvcp", "10",
                String(Math.round(root._pendingBrightnessValue * 100)),
                "--noverify",                 // 不读回校验,省一次 I2C 往返
                "--sleep-multiplier=0.1"      // ddcutil 默认调用间隔很保守,这里降到 1/10
            ]
            ddcutilSet.running = true
        }
    }

    Process {
        id: brightnessctlRead
        property string _target: ""
        command: ["sh", "-c", "echo $(brightnessctl g):$(brightnessctl m)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(":")
                const cur = parseInt(parts[0])
                const max = parseInt(parts[1])
                if (!isNaN(cur) && !isNaN(max) && max > 0 && brightnessctlRead._target) {
                    const next = Object.assign({}, root.brightnessByScreen)
                    next[brightnessctlRead._target] = cur / max
                    root.brightnessByScreen = next
                }
            }
        }
    }

    Process {
        id: ddcutilRead
        property string _target: ""
        command: ["sh", "-c", "ddcutil --terse --sleep-multiplier=0.1 getvcp 10 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // `ddcutil --terse getvcp 10` 输出形如 "VCP 10 C 75 100"(code type cur max)
                const m = this.text.trim().match(/VCP\s+\S+\s+\S+\s+(\d+)\s+(\d+)/)
                if (m && ddcutilRead._target) {
                    const cur = parseInt(m[1])
                    const max = parseInt(m[2])
                    if (max > 0) {
                        const next = Object.assign({}, root.brightnessByScreen)
                        next[ddcutilRead._target] = cur / max
                        root.brightnessByScreen = next
                    }
                }
            }
        }
    }

    Process { id: brightnessctlSet }
    Process { id: ddcutilSet }

    // 周期性 poll 内屏亮度(FN 键改了亮度,popup 也能反映)
    // 外屏不 poll,ddcutil 太慢
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const sc = Quickshell.screens[i]
                if (root.brightnessBackendFor(sc.name) === "brightnessctl") {
                    root.fetchBrightnessFor(sc.name)
                    break  // brightnessctl 只控一个 backlight,poll 第一个就够
                }
            }
        }
    }

    // 启动时把外屏亮度 prefetch 一次,以后 popup 打开走缓存不再跑 ddcutil
    // (ddcutil 跑的时候独占 I2C 总线,可能跟显示器刷新争资源导致瞬卡 —— 移到启动阶段
    //  用户感知不到)。1s 延迟是等 niri + qs 启动稳定再做。
    Component.onCompleted: externalBrightnessPrefetch.start()
    Timer {
        id: externalBrightnessPrefetch
        interval: 1000
        repeat: false
        onTriggered: {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const sc = Quickshell.screens[i]
                if (root.brightnessBackendFor(sc.name) !== "brightnessctl") {
                    root.fetchBrightnessFor(sc.name)
                }
            }
        }
    }
}
