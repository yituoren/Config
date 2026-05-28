pragma ComponentBehavior: Bound

// WeatherEffects —— 根据 Weather.currentCode 在 popup 内叠粒子动效
//
// 当前实现:
//   - 雨(rain):60 根斜雨滴细线,随机 x / 速度 / 长度循环下落
//   - 雪(snow):40 颗圆,慢速下落 + 左右摆动
//   - 雷(thunder):整层全屏白闪 + opacity 衰减,每 4~8s 触发一次
//   - 晴 / 多云 / 雾:无效果(留 hook)
//
// 用法:
//   WeatherEffects { anchors.fill: parent }  ← 放在 WeatherTab 的根 Item 里、控件之上

import QtQuick
import qs.services

Item {
    id: root
    clip: true

    // 切换天气时简单 0.4s 内淡入淡出,避免效果突变
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // ============ Rain ============
    Repeater {
        model: Weather.isPrecip ? 70 : 0
        delegate: Rectangle {
            id: drop
            required property int index
            // 随机参数 —— 一次绑定固定值,避免每帧重算
            readonly property real speedMs: 700 + (drop.index * 113) % 700
            readonly property real lengthPx: 10 + (drop.index * 37) % 8
            readonly property real xStart: (drop.index * 71) % Math.max(1, root.width)
            readonly property real delay: (drop.index * 41) % 1500

            width: 1
            height: drop.lengthPx
            color: Qt.rgba(0.7, 0.8, 1.0, 0.55)
            rotation: 12
            opacity: 0.7
            x: drop.xStart

            NumberAnimation on y {
                from: -drop.lengthPx - 10
                to: root.height + 10
                duration: drop.speedMs
                loops: Animation.Infinite
                running: Weather.isPrecip
                // 起始 delay 让所有雨滴错峰
                Component.onCompleted: {
                    // 起手让 from 的 y 加一个偏移
                }
            }
        }
    }

    // ============ Snow ============
    Repeater {
        model: Weather.isSnow ? 40 : 0
        delegate: Rectangle {
            id: flake
            required property int index
            readonly property real speedMs: 4500 + (flake.index * 211) % 3000
            readonly property real radius_: 2 + (flake.index * 7) % 3
            readonly property real xBase: (flake.index * 89) % Math.max(1, root.width)
            readonly property real swayAmp: 12 + (flake.index * 17) % 18
            readonly property real swayDur: 2200 + (flake.index * 67) % 1800

            width: flake.radius_ * 2
            height: flake.radius_ * 2
            radius: flake.radius_
            color: Qt.rgba(1, 1, 1, 0.85)

            x: flake.xBase
            NumberAnimation on y {
                from: -10
                to: root.height + 10
                duration: flake.speedMs
                loops: Animation.Infinite
                running: Weather.isSnow
            }
            // 左右摆动
            SequentialAnimation on x {
                loops: Animation.Infinite
                running: Weather.isSnow
                NumberAnimation { from: flake.xBase - flake.swayAmp; to: flake.xBase + flake.swayAmp; duration: flake.swayDur; easing.type: Easing.InOutSine }
                NumberAnimation { from: flake.xBase + flake.swayAmp; to: flake.xBase - flake.swayAmp; duration: flake.swayDur; easing.type: Easing.InOutSine }
            }
        }
    }

    // ============ Thunder flash ============
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0
        visible: Weather.isThunder

        SequentialAnimation {
            id: flashAnim
            running: Weather.isThunder
            loops: Animation.Infinite
            PauseAnimation { duration: 4000 + Math.floor(Math.random() * 4000) }
            // 双闪
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.4; duration: 60 }
            NumberAnimation { target: flash; property: "opacity"; from: 0.4; to: 0; duration: 80 }
            PauseAnimation { duration: 120 }
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.55; duration: 50 }
            NumberAnimation { target: flash; property: "opacity"; from: 0.55; to: 0; duration: 200 }
        }
    }

    // ============ Fog overlay ============
    Rectangle {
        anchors.fill: parent
        visible: Weather.isFog
        opacity: 0.18
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(0.9, 0.9, 0.9, 1) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
