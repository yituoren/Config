pragma ComponentBehavior: Bound

// IosSwitch —— 苹果风格的开关。背景圆角胶囊,白色 knob 平滑滑动。
//
// 用法:
//   IosSwitch {
//       checked: SystemStatus.bluetoothPowered
//       onToggled: SystemStatus.toggleBluetooth()
//   }

import QtQuick
import qs.services

Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 48
    implicitHeight: 28
    radius: height / 2

    color: root.checked ? Theme.colors.primary
                        : Theme.colors.surface_container_high
    Behavior on color { ColorAnimation { duration: 200 } }

    Rectangle {
        id: knob
        width: parent.height - 4
        height: width
        radius: width / 2
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x {
            NumberAnimation {
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1]
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
