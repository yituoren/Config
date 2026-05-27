pragma ComponentBehavior: Bound

// VolumeIndicator —— 音量图标
// 左键:展开 VolumeDropdown(滑块 + mute toggle 都在里面)
// 滚轮:直接 ±5% 调音量(不开 dropdown 因为太频繁)

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    readonly property bool silent: SystemStatus.volumeMuted || SystemStatus.volumePercent === 0

    readonly property string iconName: {
        if (SystemStatus.volumeMuted) return "volume_off"
        const p = SystemStatus.volumePercent
        if (p === 0) return "volume_mute"
        if (p < 34) return "volume_down"
        return "volume_up"
    }

    text: root.iconName
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: root.silent ? Theme.colors.on_surface_variant : Theme.colors.on_surface
    opacity: root.silent ? 0.6 : 1
    Behavior on color { ColorAnimation { duration: 200 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: PopupManager.toggleAt(root, "volume", root.triggerScreen)
        onWheel: (event) => {
            SystemStatus.setVolumeDelta(event.angleDelta.y > 0 ? 5 : -5)
            event.accepted = true
        }
    }
}
