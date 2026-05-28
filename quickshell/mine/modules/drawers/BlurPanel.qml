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

    // 几何来源:
    //   - blurVisible=true 期间(BlurPanel 在显示中):跟着 PopupManager.displayWidth 实时走
    //   - blurVisible=false 但 animatedScale > 0 还在收缩(切走 transparent 后):
    //       用 PopupManager.frozenBlurW/H/CX 快照,避免 BlurPanel 边收缩边变形成 wifi 形状
    readonly property bool useFrozen: !PopupManager.blurVisible && root.animatedScale > 0.001
    readonly property real liveW: PopupManager.displayWidth
    readonly property real liveH: PopupManager.displayHeight + PopupManager.extraHeight
    readonly property real liveCX: PopupManager.animatedAnchorX - root.liveW * PopupManager.triggerRelativeX

    readonly property real popupW: root.useFrozen ? PopupManager.frozenBlurW : root.liveW
    readonly property real popupH: root.useFrozen ? PopupManager.frozenBlurH : root.liveH
    readonly property real popupCX: root.useFrozen ? PopupManager.frozenBlurCX : root.liveCX
    // 跟 ContentWindow.popupY 一致(barTopMargin 8 + barHeight 44 + 4)
    readonly property real popupCY: 56

    // 动画因子:0 → BlurPanel 收成中心一点,1 → 满展到 popup 同尺
    // PopupManager.blurVisible 翻转时 Behavior 把它平滑从 0 ↔ 1(600ms)
    property real animatedScale: PopupManager.blurVisible ? 1 : 0
    Behavior on animatedScale {
        NumberAnimation {
            duration: 600
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.22, 0.61, 0.36, 1, 1, 1]
        }
    }

    // 缩放后尺寸,中心保持在 popup 中心
    readonly property real scaledW: root.popupW * root.animatedScale
    readonly property real scaledH: root.popupH * root.animatedScale
    readonly property real centerX: root.popupCX + root.popupW / 2
    readonly property real centerY: root.popupCY + root.popupH / 2

    // 不再用 popupTransparent 守门:只要 animatedScale > 阈值就显示。
    // 真正"是不是该出现 BlurPanel"由 PopupManager.blurVisible 控制 → animatedScale → 这里
    visible: root.popupOnThisScreen
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
