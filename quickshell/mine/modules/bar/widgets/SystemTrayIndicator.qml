pragma ComponentBehavior: Bound

// SystemTrayIndicator —— 聚合的系统托盘入口
// 点击展开 tray popup,里面列出所有 SNI items(clash-verge / fcitx5 / 等等)
// 单独显示一个 "apps" 通用图标,不展开所有 tray icon —— bar 干净

import QtQuick
import Quickshell.Services.SystemTray
import qs.services

Text {
    id: root
    required property var triggerScreen

    text: "apps"
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    // 没 tray item 时灰一点
    color: SystemTray.items.values.length > 0 ? Theme.colors.on_surface
                                               : Theme.colors.on_surface_variant
    opacity: SystemTray.items.values.length > 0 ? 1 : 0.6
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "tray", root.triggerScreen)
    }
}
