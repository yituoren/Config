pragma ComponentBehavior: Bound

// BatteryIndicator —— 只显示图标(百分比留给 popup);点击展开 battery popup
// 低于 15% 且非充电状态时变 error 色

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    visible: SystemStatus.hasBattery

    readonly property bool low:
        SystemStatus.batteryPercent >= 0
        && SystemStatus.batteryPercent <= 15
        && !SystemStatus.batteryCharging

    readonly property string iconName: {
        if (SystemStatus.batteryCharging) return "battery_charging_full"
        const p = SystemStatus.batteryPercent
        if (p < 0) return "battery_unknown"
        if (p >= 95) return "battery_full"
        if (p >= 80) return "battery_6_bar"
        if (p >= 65) return "battery_5_bar"
        if (p >= 50) return "battery_4_bar"
        if (p >= 35) return "battery_3_bar"
        if (p >= 20) return "battery_2_bar"
        if (p >= 10) return "battery_1_bar"
        return "battery_alert"
    }

    text: root.iconName
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: root.low ? Theme.colors.error : Theme.colors.on_surface
    Behavior on color { ColorAnimation { duration: 250 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "battery", root.triggerScreen)
    }
}
