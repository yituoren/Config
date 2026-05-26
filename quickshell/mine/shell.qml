//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// shell.qml —— 入口。只装配模块,不写实际 UI。

import Quickshell
import Quickshell.Io
import qs.modules.bar
// 显式 import 这些子目录是为了让 qs 在 shell 启动时自动建 qmldir 索引。
// 不写在这里,虽然 Bar.qml 自己也 import 它们,但 qs 不会"自下而上"建索引,
// 子文件就会拿到 "module not installed"。
import qs.services
import qs.modules.bar.widgets

ShellRoot {
    // 每块屏幕一个 Bar(modelData 由 Variants 注入,Bar.qml 内部声明 required)
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // 测试 ipc:`qs -c mine ipc call test ping`
    IpcHandler {
        target: "test"
        function ping(): void { console.log("hi from mine") }
    }
}
