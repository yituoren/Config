//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

// shell.qml —— 入口。Caelestia 风格:每屏一个 ContentWindow,内含 bar + popup
// (SDF blob 融合要求 bar/popup 在同一 scene graph)

import Quickshell
import Quickshell.Io
import Caelestia.Blobs  // 自己编译的 SDF blob plugin (~/.local/share/qt6/qml/Caelestia/Blobs/)
import qs.modules.drawers
import qs.modules.bar.widgets
import qs.services

ShellRoot {
    // BlurPanel —— popup 底下的模糊层(每屏一个),niri 给它单独 blur
    // 注意:必须先创建 BlurPanel(Top 层),再创建 ContentWindow(Overlay 层),
    // 保证 ContentWindow 渲染在上,BlurPanel 在下,SDF 半透时能透出 blur 画面
    Variants {
        model: Quickshell.screens
        BlurPanel {}
    }

    Variants {
        model: Quickshell.screens
        ContentWindow {}
    }

    IpcHandler {
        target: "test"
        function ping(): void { console.log("hi from mine") }
    }
}
