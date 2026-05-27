pragma ComponentBehavior: Bound

// BluetoothIndicator —— 蓝牙图标。点击展开 BluetoothDropdown(内含 power toggle)

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    readonly property string iconName: {
        if (!SystemStatus.bluetoothPowered) return "bluetooth_disabled"
        if (SystemStatus.bluetoothConnected) return "bluetooth_connected"
        return "bluetooth"
    }

    text: root.iconName
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: SystemStatus.bluetoothPowered ? Theme.colors.on_surface
                                         : Theme.colors.on_surface_variant
    opacity: SystemStatus.bluetoothPowered ? 1 : 0.6
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "bluetooth", root.triggerScreen)
    }
}
