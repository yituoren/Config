pragma ComponentBehavior: Bound

// BlurPanel —— 专门做 popup 背景模糊的 layer-shell window
//
// 思路:
//   - 单独一个小层(只覆盖 popup 几何 ±pad)透明 surface
//   - niri layer-rule `^mine-blur$` background-effect blur → 只在这块小区域糊后面窗口 + 壁纸
//   - mine-shell 走 Overlay 层在它之上,SDF 仍然在同一 scene graph,metaball 不破
//   - mine-shell 的 SDF popup 用 colorBottom alpha < 1 让 BlurPanel 的模糊画面透过来
//
// 输入:本 panel mask 设空 Region,不抓任何 click(clicks 全交给 mine-shell)
// 几何:跟 PopupManager 的开合动画同步(popupScale/animatedAnchorX/extraHeight)
//
// 边界处理:pad 8px 把 SDF metaball blend 区也包进 blur 矩形(否则 popup 边沿那一圈不糊)

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "mine-blur"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"

    readonly property bool popupOnThisScreen: PopupManager.currentScreen === root.modelData

    // 只为 transparent popup(dashboard)启用 BlurPanel
    readonly property bool popupTransparent: {
        const e = PopupManager.entry ?? PopupManager.lastEntry
        return e && e.transparent === true
    }

    // BlurPanel 不参与 popup 的 scale 动画 —— 只在 popup **完全打开后**才出现
    // 尺寸 = popup 显示尺寸(displayWidth × displayHeight + extraHeight),无缩放
    // 关闭时:openAmount 一离开 ~1 → BlurPanel 立刻 snap 隐藏 → popup 才继续收回
    //   这样实现"先关 blur 再关 popup"的顺序,不会出现 BlurPanel 边沿露出 popup 缩小后的边界
    readonly property real popupW: PopupManager.displayWidth
    readonly property real popupH: PopupManager.displayHeight + PopupManager.extraHeight
    readonly property real popupCX: PopupManager.animatedAnchorX - root.popupW * PopupManager.triggerRelativeX
    // 跟 ContentWindow.popupY 一致(barTopMargin 8 + barHeight 44 + 4)
    readonly property real popupCY: 56

    // 动画因子:0 → BlurPanel 收成中心一点(不可见),1 → 满展到 popup 同尺
    // PopupManager.blurVisible 翻转时,Behavior 把它平滑从 0 ↔ 1
    // 关闭时 PopupManager.blurDisappearDelay(600ms)≥ 这里 duration,保证 popup 在 blur 完全缩回后才开始收
    property real animatedScale: PopupManager.blurVisible ? 1 : 0
    Behavior on animatedScale {
        NumberAnimation {
            duration: 600
            easing.type: Easing.BezierSpline
            // gentle ease-out:开头快(blur 立刻有感),尾巴慢慢饱和到满
            easing.bezierCurve: [0.22, 0.61, 0.36, 1, 1, 1]
        }
    }

    // 缩放后的尺寸 + 中心保持在 popup 几何中心
    readonly property real scaledW: root.popupW * root.animatedScale
    readonly property real scaledH: root.popupH * root.animatedScale
    readonly property real centerX: root.popupCX + root.popupW / 2
    readonly property real centerY: root.popupCY + root.popupH / 2

    visible: root.popupOnThisScreen && root.popupTransparent
             && root.animatedScale > 0.001
             && root.popupW > 1 && root.popupH > 1

    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.round(root.centerY - root.scaledH / 2)
        left: Math.round(root.centerX - root.scaledW / 2)
    }
    implicitWidth: Math.max(1, Math.round(root.scaledW))
    implicitHeight: Math.max(1, Math.round(root.scaledH))

    // 完全不抓输入 —— click 全交给上层 mine-shell 的 scrim/popup
    mask: emptyRegion
    Region { id: emptyRegion }
}
