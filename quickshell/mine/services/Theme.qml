pragma Singleton
pragma ComponentBehavior: Bound

// Theme.qml —— matugen 颜色单例
//
// 设计取舍:不再用 FileView.watchChanges(matugen 原子写换 inode,
// quickshell 在某些版本下 watch 失效)。改用 Process 直接读 + IPC 显式触发:
//   - 启动时 Process 跑一次,加载 colors.json
//   - setwall 在 matugen 跑完后调 `qs -c mine ipc call theme reload`,
//     这边重新跑 Process,更新 root.colors,所有 binding 自动刷新。
//
// 访问:Theme.colors.primary / Theme.colors.on_background / ...
// 命名跟 matugen 的 snake_case 保持一致,也避开 QML "on<Cap>" 命名禁忌。

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string colorsFile:
        Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"

    // 默认 fallback,文件读不到时不至于整片黑
    property var colors: ({
        background: "#101418",
        on_background: "#e0e2e8",
        surface: "#101418",
        surface_dim: "#101418",
        surface_bright: "#363a3e",
        surface_tint: "#a9c7ff",
        surface_variant: "#42474e",
        on_surface: "#e0e2e8",
        on_surface_variant: "#c2c7cf",
        surface_container_lowest: "#0b0e12",
        surface_container_low: "#191c20",
        surface_container: "#1d2024",
        surface_container_high: "#272a2f",
        surface_container_highest: "#32353a",
        primary: "#a9c7ff",
        on_primary: "#003354",
        primary_container: "#114a73",
        on_primary_container: "#cfe5ff",
        primary_fixed: "#cfe5ff",
        primary_fixed_dim: "#a9c7ff",
        on_primary_fixed: "#001d33",
        on_primary_fixed_variant: "#114a73",
        secondary: "#bdc7dc",
        on_secondary: "#243240",
        secondary_container: "#3a4857",
        on_secondary_container: "#d5e4f7",
        secondary_fixed: "#d5e4f7",
        secondary_fixed_dim: "#bdc7dc",
        on_secondary_fixed: "#0e1d2a",
        on_secondary_fixed_variant: "#3a4857",
        tertiary: "#dcbce1",
        on_tertiary: "#3f2845",
        tertiary_container: "#563e5c",
        on_tertiary_container: "#f9d8fd",
        tertiary_fixed: "#f9d8fd",
        tertiary_fixed_dim: "#dcbce1",
        on_tertiary_fixed: "#28132f",
        on_tertiary_fixed_variant: "#563e5c",
        error: "#ffb4ab",
        on_error: "#690005",
        error_container: "#93000a",
        on_error_container: "#ffdad6",
        inverse_surface: "#e0e2e8",
        inverse_on_surface: "#2d3135",
        inverse_primary: "#31628d",
        outline: "#8c9199",
        outline_variant: "#42474e",
        shadow: "#000000",
        scrim: "#000000",
    })

    function reload(): void {
        reader.running = true
    }

    function parse(content: string): void {
        if (!content) return
        try {
            const c = JSON.parse(content)
            root.colors = c
            console.log("Theme: reloaded,", Object.keys(c).length, "tokens, primary =", c.primary)
        } catch (e) {
            console.warn("Theme: invalid JSON in", root.colorsFile, e)
        }
    }

    Process {
        id: reader
        command: ["cat", root.colorsFile]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    // 启动时拉一次
    Component.onCompleted: root.reload()

    // setwall 用:`qs -c mine ipc call theme reload`
    IpcHandler {
        target: "theme"
        function reload(): void { root.reload() }
    }
}
