// Bar.qml —— 整屏边框 + 顶部加宽作 bar
//
// 思路:PanelWindow 4 边都 anchor,覆盖整屏。内部用 Shape 画一个"外矩 − 内圆角矩"
// 形成的边框路径(OddEvenFill 规则,内圆角矩形作为空洞)。顶部加宽即为 bar 内容区。
//
// niri 配合:
//   - layout.kdl struts { top=barHeight, left/right/bottom=sideFrame } —— 让窗口给边框让位
//   - rules.kdl ^mine-bar$ geometry-corner-radius=0 + blur=false —— layer 占满整屏,
//     若启用 blur 则整屏中间空洞处也会被模糊
//
// 输入 mask:只让顶部 bar 那块接收点击,其它区域 click 穿透到下层窗口
// 注:Quickshell 的 Region 输入 mask 必须用 `item:` 引用一个 Item,
//     不要直接写 x/y/width/height(虽然 qmltypes 里能看到这些属性,但跟严格 pragma
//     或某些 PendingRegion 行为不兼容,会让整文件解析失败、错误冒泡成上面 import 不存在的假象)。

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.bar.widgets

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "mine-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ---- 框架尺寸 ----
    // 改尺寸时同步改 niri/layout.kdl 的 struts(top=barHeight, left/right/bottom=sideFrame)
    readonly property int barHeight: 44
    readonly property int sideFrame: 8
    readonly property int innerRadius: 18  // 跟 niri window radius 18 对齐

    color: "transparent"

    // ---- 输入 mask(顶部那条接收 click,其余穿透) ----
    mask: Region { item: barArea }

    // ---- 边框形状 ----
    Shape {
        id: frame
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // 边框填色(OddEvenFill:外矩 - 内圆角矩 = 框)
        // 深色背景 + 0.7 alpha
        ShapePath {
            fillRule: ShapePath.OddEvenFill
            fillColor: {
                const c = Qt.color(Theme.colors.surface_container_lowest)
                return Qt.rgba(c.r, c.g, c.b, 0.7)
            }
            strokeWidth: 0
            strokeColor: "transparent"

            startX: 0
            startY: 0
            PathLine { x: frame.width; y: 0 }
            PathLine { x: frame.width; y: frame.height }
            PathLine { x: 0; y: frame.height }
            PathLine { x: 0; y: 0 }

            PathMove { x: bar.sideFrame; y: bar.barHeight + bar.innerRadius }
            PathArc {
                x: bar.sideFrame + bar.innerRadius
                y: bar.barHeight
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: frame.width - bar.sideFrame - bar.innerRadius; y: bar.barHeight }
            PathArc {
                x: frame.width - bar.sideFrame
                y: bar.barHeight + bar.innerRadius
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: frame.width - bar.sideFrame; y: frame.height - bar.sideFrame - bar.innerRadius }
            PathArc {
                x: frame.width - bar.sideFrame - bar.innerRadius
                y: frame.height - bar.sideFrame
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: bar.sideFrame + bar.innerRadius; y: frame.height - bar.sideFrame }
            PathArc {
                x: bar.sideFrame
                y: frame.height - bar.sideFrame - bar.innerRadius
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: bar.sideFrame; y: bar.barHeight + bar.innerRadius }
        }

        // 内侧 1px 暗描边,做"阴影"层次
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(0, 0, 0, 0.45)
            strokeWidth: 1

            startX: bar.sideFrame
            startY: bar.barHeight + bar.innerRadius
            PathArc {
                x: bar.sideFrame + bar.innerRadius
                y: bar.barHeight
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: frame.width - bar.sideFrame - bar.innerRadius; y: bar.barHeight }
            PathArc {
                x: frame.width - bar.sideFrame
                y: bar.barHeight + bar.innerRadius
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: frame.width - bar.sideFrame; y: frame.height - bar.sideFrame - bar.innerRadius }
            PathArc {
                x: frame.width - bar.sideFrame - bar.innerRadius
                y: frame.height - bar.sideFrame
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: bar.sideFrame + bar.innerRadius; y: frame.height - bar.sideFrame }
            PathArc {
                x: bar.sideFrame
                y: frame.height - bar.sideFrame - bar.innerRadius
                radiusX: bar.innerRadius; radiusY: bar.innerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: bar.sideFrame; y: bar.barHeight + bar.innerRadius }
        }
    }

    // ---- Bar 内容区(同时也是输入 mask 的形状载体) ----
    Item {
        id: barArea
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: bar.barHeight

        ArchLogo {
            id: archLogo
            anchors {
                left: parent.left
                leftMargin: bar.sideFrame + 14
                verticalCenter: parent.verticalCenter
            }
        }

        WorkspaceIndicator {
            id: workspaceStrip
            anchors {
                left: archLogo.right
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }
        }

        FocusedWindowTitle {
            anchors.centerIn: parent
            width: Math.min(implicitWidth,
                            parent.width
                            - (workspaceStrip.x + workspaceStrip.width) * 2
                            - 40)
        }

        Clock {
            anchors {
                right: parent.right
                rightMargin: bar.sideFrame + 14
                verticalCenter: parent.verticalCenter
            }
        }
    }
}
