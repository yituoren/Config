pragma Singleton
pragma ComponentBehavior: Bound

// Weather —— 天气服务
//
// 数据流:
//   1. 启动 / 30 分钟周期:跑 `where-am-i`(geoclue demo)拿 lat/lon
//      失败 → fallback curl ipapi.co/json
//   2. 拿到 lat/lon 后调 Open-Meteo current+hourly+daily,timezone=auto
//   3. 解 JSON,暴露 current / hourly(48 项)/ daily(7 项)
//
// WMO weather_code(0-99)→ Material Symbols Rounded 字体图标 + 中文标签
// 同时暴露 isPrecip / isSnow / isThunder 给 WeatherEffects 触发粒子动效

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============ 位置 ============
    property real lat: 0
    property real lon: 0
    property string locationName: ""   // ipapi 可能给城市名,geoclue 不一定
    property string locationSource: "" // "geoclue" | "ipapi"
    readonly property bool hasLocation: root.lat !== 0 || root.lon !== 0

    // ============ 当前天气 ============
    property var current: null         // {temp, feels, humidity, wind, code, isDay, precip, time}

    // hourly: [{time(Date), temp, code, precipProb}] 拿 48 项
    property var hourly: []

    // 真正"接下来 24 小时"(从当前时刻起,过滤掉已过去的小时)
    readonly property var hourlyNext24: {
        const now = new Date()
        const out = []
        for (let i = 0; i < root.hourly.length && out.length < 24; i++) {
            if (root.hourly[i].time.getTime() >= now.getTime() - 30 * 60 * 1000) {
                out.push(root.hourly[i])
            }
        }
        return out
    }

    // daily: [{date(Date), code, tmax, tmin, sunrise, sunset}] 拿 7 项
    property var daily: []

    property string status: "idle"     // "idle" | "loading" | "ok" | "error"
    property string updatedAt: ""      // 最后更新的人类可读时间

    // 触发动效用
    readonly property int currentCode: root.current ? root.current.code : -1
    readonly property bool isPrecip: [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].indexOf(root.currentCode) >= 0
    readonly property bool isSnow: [71, 73, 75, 77, 85, 86].indexOf(root.currentCode) >= 0
    readonly property bool isThunder: [95, 96, 99].indexOf(root.currentCode) >= 0
    readonly property bool isFog: [45, 48].indexOf(root.currentCode) >= 0
    readonly property bool isClear: [0, 1].indexOf(root.currentCode) >= 0

    // ============ WMO → 图标 / 描述 ============
    // 用 Material Symbols Rounded 的天气 ligature(部分可能没,fallback 时换名)
    function codeIcon(code: int, isDay: bool): string {
        switch (code) {
        case 0: return isDay ? "clear_day" : "clear_night"
        case 1: return isDay ? "clear_day" : "clear_night"
        case 2: return isDay ? "partly_cloudy_day" : "partly_cloudy_night"
        case 3: return "cloudy"
        case 45: case 48: return "foggy"
        case 51: case 53: case 55: return "rainy_light"
        case 56: case 57: return "weather_mix"
        case 61: case 63: case 80: case 81: return "rainy"
        case 65: case 82: return "rainy_heavy"
        case 66: case 67: return "weather_mix"
        case 71: case 73: case 85: return "cloudy_snowing"
        case 75: case 86: return "snowing_heavy"
        case 77: return "snowing"
        case 95: return "thunderstorm"
        case 96: case 99: return "thunderstorm"
        }
        return "cloudy"
    }

    function codeLabel(code: int): string {
        switch (code) {
        case 0: return "Clear"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Rime fog"
        case 51: return "Light drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy drizzle"
        case 56: case 57: return "Freezing drizzle"
        case 61: return "Light rain"
        case 63: return "Rain"
        case 65: return "Heavy rain"
        case 66: case 67: return "Freezing rain"
        case 71: return "Light snow"
        case 73: return "Snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80: return "Rain showers"
        case 81: return "Heavy showers"
        case 82: return "Violent showers"
        case 85: return "Snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96: case 99: return "Thunderstorm w/ hail"
        }
        return "—"
    }

    // ============ 位置抓取 ============
    Process {
        id: geoProc
        command: ["/usr/lib/geoclue-2.0/demos/where-am-i", "--timeout", "8"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || ""
                const latM = text.match(/Latitude:\s+(-?\d+(?:\.\d+)?)/)
                const lonM = text.match(/Longitude:\s+(-?\d+(?:\.\d+)?)/)
                if (latM && lonM) {
                    root.lat = parseFloat(latM[1])
                    root.lon = parseFloat(lonM[1])
                    root.locationSource = "geoclue"
                    root.fetchWeather()
                } else {
                    console.warn("Weather: geoclue parse failed, fallback to IP")
                    ipProc.running = true
                }
            }
        }
    }

    Process {
        id: ipProc
        command: ["curl", "-fsSL", "--max-time", "6", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}")
                    if (d.latitude && d.longitude) {
                        root.lat = d.latitude
                        root.lon = d.longitude
                        root.locationName = d.city || ""
                        root.locationSource = "ipapi"
                        root.fetchWeather()
                    } else {
                        root.status = "error"
                    }
                } catch (e) {
                    root.status = "error"
                }
            }
        }
    }

    // ============ 城市名 ============
    // Nominatim 之类的反向地理编码服务被代理拦截了,直接复用 ipapi.co/json
    // (IP-geo 不如 geoclue 准,但城市级别一般够用)
    Process {
        id: cityProc
        command: ["curl", "-fsSL", "--max-time", "6", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}")
                    if (d.city) root.locationName = d.city
                } catch (e) {
                    // 静默
                }
            }
        }
    }

    function fetchCity(): void {
        if (cityProc.running) return
        cityProc.running = true
    }

    // ============ Open-Meteo ============
    Process {
        id: forecastProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}")
                    if (!d.current) {
                        root.status = "error"
                        return
                    }
                    root.current = {
                        time: d.current.time,
                        temp: d.current.temperature_2m,
                        feels: d.current.apparent_temperature,
                        humidity: d.current.relative_humidity_2m,
                        wind: d.current.wind_speed_10m,
                        precip: d.current.precipitation,
                        code: d.current.weather_code,
                        isDay: d.current.is_day === 1
                    }
                    // hourly:48 项往后
                    const hh = []
                    if (d.hourly && d.hourly.time) {
                        const n = Math.min(48, d.hourly.time.length)
                        for (let i = 0; i < n; i++) {
                            hh.push({
                                time: new Date(d.hourly.time[i]),
                                temp: d.hourly.temperature_2m[i],
                                code: d.hourly.weather_code[i],
                                precipProb: d.hourly.precipitation_probability ? d.hourly.precipitation_probability[i] : 0
                            })
                        }
                    }
                    root.hourly = hh
                    // daily:7 天
                    const dd = []
                    if (d.daily && d.daily.time) {
                        for (let i = 0; i < d.daily.time.length; i++) {
                            dd.push({
                                date: new Date(d.daily.time[i]),
                                code: d.daily.weather_code[i],
                                tmax: d.daily.temperature_2m_max[i],
                                tmin: d.daily.temperature_2m_min[i],
                                sunrise: d.daily.sunrise ? d.daily.sunrise[i] : "",
                                sunset: d.daily.sunset ? d.daily.sunset[i] : ""
                            })
                        }
                    }
                    root.daily = dd
                    root.status = "ok"
                    root.updatedAt = Qt.formatDateTime(new Date(), "HH:mm")
                    // 已经有 lat/lon 但还没城市名 → 反查一下
                    if (!root.locationName && root.hasLocation) root.fetchCity()
                } catch (e) {
                    console.warn("Weather: forecast parse failed", e)
                    root.status = "error"
                }
            }
        }
    }

    function fetchWeather(): void {
        if (!root.hasLocation) return
        root.status = "loading"
        const params = [
            "latitude=" + root.lat,
            "longitude=" + root.lon,
            "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m",
            "hourly=temperature_2m,precipitation_probability,weather_code",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
            "timezone=auto",
            "forecast_days=7"
        ]
        const url = "https://api.open-meteo.com/v1/forecast?" + params.join("&")
        forecastProc.command = ["curl", "-fsSL", "--max-time", "10", url]
        forecastProc.running = true
    }

    function refresh(): void {
        if (geoProc.running || ipProc.running || forecastProc.running) return
        if (root.hasLocation) {
            // 已经有位置就只刷天气;位置 30 分钟才重新定位
            root.fetchWeather()
        } else {
            geoProc.running = true
        }
    }

    Component.onCompleted: root.refresh()

    // 每 15 分钟刷天气
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }

    // 每 30 分钟重定位(位置变化触发新的天气拉取)
    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: { if (!geoProc.running) geoProc.running = true }
    }
}
