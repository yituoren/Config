pragma Singleton
pragma ComponentBehavior: Bound

// Cava —— 拉起 cava 进程,raw ASCII 输出解析成 [0,1] bar 值数组
// enabled 由外部组件(可见时)开关,不可见时停 cava 省 CPU

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // bars 数:cava 律动条不再走 SDF(改用 QML Gradient),不再受 16 个 BlobRect 上限制约
    readonly property int bars: 32
    property var values: {
        const a = []
        for (let i = 0; i < root.bars; i++) a.push(0)
        return a
    }

    // 多消费者:MediaTab / bar 律动条都可能要 cava
    property bool needMediaTab: false
    property bool needBarViz: false
    readonly property bool enabled: root.needMediaTab || root.needBarViz

    Process {
        id: cavaProc
        running: root.enabled
        // 一行 sh:写 config 到 /tmp 然后 exec cava
        command: ["sh", "-c",
            "cat > /tmp/qs-mine-cava.conf <<'EOF'\n" +
            "[general]\n" +
            "bars = " + root.bars + "\n" +
            "framerate = 60\n" +
            "sleep_timer = 0\n" +
            "[input]\n" +
            "method = pulse\n" +
            "source = auto\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 100\n" +
            "EOF\n" +
            "exec cava -p /tmp/qs-mine-cava.conf\n"
        ]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";").filter(s => s.length > 0)
                if (parts.length !== root.bars) return
                const v = []
                for (let i = 0; i < parts.length; i++) {
                    const n = parseInt(parts[i], 10)
                    v.push(isNaN(n) ? 0 : Math.max(0, Math.min(1, n / 100)))
                }
                root.values = v
            }
        }
    }
}
