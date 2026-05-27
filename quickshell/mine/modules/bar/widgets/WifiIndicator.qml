pragma ComponentBehavior: Bound

// WifiIndicator —— 信号强度图标。点击展开 WifiDropdown

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    readonly property string iconName: {
        if (!SystemStatus.wifiConnected) return "wifi_off"
        const sig = SystemStatus.wifiSignal
        if (sig >= 75) return "signal_wifi_4_bar"
        if (sig >= 50) return "network_wifi_3_bar"
        if (sig >= 25) return "network_wifi_2_bar"
        if (sig > 0) return "network_wifi_1_bar"
        return "signal_wifi_0_bar"
    }

    text: root.iconName
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: SystemStatus.wifiConnected ? Theme.colors.on_surface
                                      : Theme.colors.on_surface_variant
    opacity: SystemStatus.wifiConnected ? 1 : 0.6
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "wifi", root.triggerScreen)
    }
}
