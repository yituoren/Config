pragma Singleton
pragma ComponentBehavior: Bound

// DateTime —— 全局时间单例
//
// 一个 Timer 驱动一次属性更新,所有 Clock / Calendar / 通知时间戳共用。
// 避免每个模块各开一个 Timer。

import QtQuick
import Quickshell

Singleton {
    id: root

    // 当前时间(JS Date)
    property date now: new Date()

    // 预格式化的常用串
    readonly property string hhmm: Qt.formatDateTime(root.now, "HH:mm")
    readonly property string hhmmss: Qt.formatDateTime(root.now, "HH:mm:ss")
    readonly property string dateShort: Qt.formatDateTime(root.now, "MM-dd ddd")
    readonly property string dateLong: Qt.formatDateTime(root.now, "yyyy-MM-dd dddd")

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
