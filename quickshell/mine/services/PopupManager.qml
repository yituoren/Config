pragma Singleton
pragma ComponentBehavior: Bound

// PopupManager —— 全局 popup 状态单例
//
// 定位逻辑(关键):
//   popup 不是简单"居中于 anchorX"。triggerRelativeX 决定 trigger 在 popup 内的相对位置:
//     - 中间区域的按钮:tr = 0.5,popup 居中于 anchorX,左右对称展开
//     - 屏幕右边的按钮(如 PowerButton):tr = 1.0,popup 右边沿在 anchorX,向左展开
//     - 屏幕左边的按钮:tr = 0.0,popup 左边沿在 anchorX,向右展开
//   关闭时 popup 朝 anchorX 收缩 → 跟按钮位置对齐,不会"闪到一边"。
//
// 同时 triggerRelativeX 在 onEntryChanged 里计算时考虑了 bar 凹槽的安全边距,
// 避免凹槽超出 bar 外圆角(issue #4 的自然修复)。

import QtQuick
import Quickshell

Singleton {
    id: root

    // ============ 基本状态 ============
    property string currentPopup: ""
    property var currentScreen: null
    property real anchorX: 0

    readonly property var registry: ({
        "power":     { width: 280, height: 280 },
        "wifi":      { width: 320, height: 440 },
        "bluetooth": { width: 320, height: 440 },
        "volume":    { width: 320, height: 154 },
        "battery":   { width: 320, height: 154 },
        "tray":      { width: 320, height: 280 },
        // dashboard:宽 720;高随屏(底沿落在屏幕中线附近);scaleFrom=0.8 让 SDF 形状不从 0 长起而从 80% 起跳,
        // 配合 content 自带的 opacity fade,出场幅度减小不"砰一下铺开"
        "dashboard": {
            width: 880,
            heightFn: (s) => Math.min(540, Math.round((s ? s.height : 1440) * 0.42)),
            scaleFrom: 0.85,
            // transparent: true 才走渐变 + BlurPanel;其他 popup 留纯黑实色
            transparent: true
        }
    })

    readonly property var entry: root.registry[root.currentPopup] ?? null
    readonly property bool isOpen: root.entry !== null
    property var lastEntry: null

    // 当前 popup 的动画时长(切换时取新 entry 的 duration;关闭时保留上次值,让关闭动画跟打开同速)
    property int activeDuration: 320

    // dashboard popup 记住上次选中的 tab,下次打开就从这开始;首次默认 "dashboard"
    property string dashboardTab: "dashboard"

    // 开合动画进行中标记;scrim / popup 自己在这个期间应忽略 click,避免刚 hover 触发就被外点关掉
    property bool openInProgress: false
    Timer {
        id: openInProgressTimer
        interval: root.activeDuration + 30
        repeat: false
        onTriggered: root.openInProgress = false
    }
    onCurrentPopupChanged: {
        if (root.currentPopup !== "") {
            root.openInProgress = true
            openInProgressTimer.restart()
        }
    }

    // ====== Blur 两段式调度 ======
    // 打开:popup 动画完成(openAmount 到 1)后再等 blurAppearDelay 才显示 blur
    // 关闭:用户 close() 时立刻把 blur 关掉,等 blurDisappearDelay 后才真正开始 popup 收回动画
    // 这样视觉上 blur 永远在 popup 完全展开后才慢一拍出现,关闭也先消失再缩 popup
    property bool blurVisible: false
    // appearDelay:popup 完全展开后等一拍才开始 blur grow 动画(节奏感)
    // disappearDelay:close 时 blurVisible=false 后等多久才真正收 popup(等 BlurPanel scale 缩完)
    //   要 ≥ BlurPanel 内 Behavior on animatedScale duration,否则 popup 会在 blur 还没缩完时就开始收
    readonly property int blurAppearDelay: 120
    readonly property int blurDisappearDelay: 600

    Timer {
        id: blurAppearTimer
        interval: root.blurAppearDelay
        repeat: false
        onTriggered: {
            // 双重保险:只在 popup 当前还是 transparent 类型 + 完全展开时才真的亮 blur
            if (root.entry && root.entry.transparent === true && root.openAmount >= 0.999) {
                root.blurVisible = true
            }
        }
    }
    Timer {
        id: blurCloseTimer
        interval: root.blurDisappearDelay
        repeat: false
        onTriggered: root.currentPopup = ""
    }

    // openAmount 越过 0.999 → 调度 blur 出现;低于 → 取消调度并强制 blur 关
    // (popup 切换中 / 关闭中 都走这里,自动撤销已排队的 blur)
    onOpenAmountChanged: {
        if (root.openAmount >= 0.999 && root.entry && root.entry.transparent === true) {
            blurAppearTimer.restart()
        } else {
            blurAppearTimer.stop()
            root.blurVisible = false
        }
    }


    // ============ 尺寸(带 Behavior 平滑切换 popup)============
    property real displayWidth: 0
    property real displayHeight: 0
    Behavior on displayWidth {
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }
    Behavior on displayHeight {
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    // ============ 凹陷 ============
    readonly property int dipMaxDepth: 16

    // ============ 开合动画 ============
    property real openAmount: 0
    Behavior on openAmount {
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    // ============ 动态加高(给 popup 内部可展开的 dropdown 用,如 volume 的输出设备列表)============
    // popup 用 PopupManager.extraHeight = N 主动撑开;切换 popup 自动 reset 0
    property real extraHeight: 0
    Behavior on extraHeight {
        NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    // ============ Trigger 相对位置 ============
    // 0 = trigger 在 popup 左边沿;1 = 在 popup 右边沿;0.5 = 在 popup 正中
    // 在 onEntryChanged 里根据 anchorX、屏宽、bar 安全边距计算
    property real triggerRelativeX: 0.5

    // animatedAnchorX —— 切换 popup 时让 popup 横向位置平滑过渡
    property real animatedAnchorX: 0
    Behavior on animatedAnchorX {
        enabled: root.isOpen  // 初次打开 snap;只有 popup 已经打开切换时才动画
        NumberAnimation { duration: root.activeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    onEntryChanged: {
        if (root.entry) {
            root.lastEntry = root.entry
            // 切到新 popup 立刻把 duration 换上,后续所有 Behavior 用这个速度
            // 关闭时(entry → null)不动 activeDuration,关闭动画就会沿用打开时的速度
            root.activeDuration = root.entry.duration ?? 320
            root.displayWidth = root.entry.width
            // 支持 heightFn(s) 动态算高度(dashboard 用,跟屏高挂钩)
            root.displayHeight = root.entry.heightFn
                ? root.entry.heightFn(root.currentScreen)
                : root.entry.height
            // 切换 / 新开 popup 都把内部 dropdown 收回去
            root.extraHeight = 0

            // 计算 triggerRelativeX,带 bar 安全边距(让 popup 右沿不超过 sw - 40,左沿不低于 40)
            // 40 = 8 (bar margin) + 16 (bar 外圆角) + 16 (bar 凹槽 mouth 半径)
            if (root.currentScreen) {
                const sw = root.currentScreen.width
                const w = root.entry.width
                const safeEdge = 40

                // popup_left = anchorX - w × tr ≥ safeEdge   →  tr ≤ (anchorX - safeEdge) / w
                // popup_right = anchorX + w × (1 - tr) ≤ sw - safeEdge  →  tr ≥ 1 - (sw - safeEdge - anchorX) / w
                const trMax = (root.anchorX - safeEdge) / w
                const trMin = 1 - (sw - safeEdge - root.anchorX) / w

                let tr = 0.5
                if (tr > trMax) tr = trMax
                if (tr < trMin) tr = trMin
                tr = Math.max(0, Math.min(1, tr))
                root.triggerRelativeX = tr
            }

            root.animatedAnchorX = root.anchorX
        }
        root.openAmount = root.entry ? 1 : 0
    }

    function open(popupKey: string, screen: var, screenLocalX: real): void {
        root.currentScreen = screen
        root.anchorX = screenLocalX
        root.currentPopup = popupKey
    }

    function close(): void {
        // transparent popup 且 blur 已经亮起:先关 blur,等一拍再真正收回 popup
        // 别的情形:直接收
        if (root.entry && root.entry.transparent === true && root.blurVisible) {
            root.blurVisible = false
            blurAppearTimer.stop()
            blurCloseTimer.restart()  // 时间到 → currentPopup = ""
        } else {
            blurAppearTimer.stop()
            blurCloseTimer.stop()
            root.blurVisible = false
            root.currentPopup = ""
        }
    }

    function toggle(popupKey: string, screen: var, screenLocalX: real): void {
        if (root.currentPopup === popupKey) {
            root.close()
        } else {
            root.open(popupKey, screen, screenLocalX)
        }
    }

    function toggleAt(triggerItem: Item, popupKey: string, screen: var): void {
        if (!triggerItem || !screen) {
            console.warn("PopupManager.toggleAt: missing triggerItem or screen")
            return
        }
        const g = triggerItem.mapToGlobal(triggerItem.width / 2, 0)
        const localX = g.x - (screen.x ?? 0)
        root.toggle(popupKey, screen, localX)
    }
}
