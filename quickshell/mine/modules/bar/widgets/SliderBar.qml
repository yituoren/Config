pragma ComponentBehavior: Bound

// SliderBar —— 通用进度/数值条
// 鼠标 hover 时尾端的 thumb 弹出,可以按住拖动实时改值;松开/移开 → thumb 缩回去
//
// 用法:
//   SliderBar {
//       value: SystemStatus.volume
//       onMoved: (v) => SystemStatus.setVolume(v)
//   }

import QtQuick
import qs.services

Item {
    id: root

    // 公共 API
    property real value: 0                  // 0.0 - 1.0
    property real wheelStep: 0.05           // 滚轮步进
    property real minValue: 0               // 不能拖到 0 以下;某些场景(如屏幕亮度)可以设 0.05 避免黑屏
    signal moved(real newValue)             // 用户改值时触发(parent 实际去写后端)

    readonly property bool active: hover.containsMouse || hover.pressed

    implicitHeight: 24                      // 整体的鼠标触摸高度(track 之外有一圈 hover 区域)

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: 8
        radius: 4
        color: Theme.colors.surface_container_high

        // 填充部分
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: parent.radius
            color: Theme.colors.primary
        }
    }

    // Thumb —— hover/press 时弹出,松开消失。白色 knob 跟 IosSwitch 一致
    Rectangle {
        id: thumb
        readonly property real targetX: parent.width * Math.max(0, Math.min(1, root.value)) - width / 2
        x: Math.max(0, Math.min(parent.width - width, thumb.targetX))
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: "#ffffff"
        border.color: Theme.colors.outline_variant
        border.width: 1
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        z: 1
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function commit(mx) {
            const v = Math.max(root.minValue, Math.min(1, mx / width))
            root.moved(v)
        }

        onPressed: (mouse) => hover.commit(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed) hover.commit(mouse.x)
        }
        onWheel: (event) => {
            const step = event.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep
            const v = Math.max(root.minValue, Math.min(1, root.value + step))
            root.moved(v)
            event.accepted = true
        }
    }
}
