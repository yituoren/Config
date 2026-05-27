pragma ComponentBehavior: Bound

// PowerButton —— 点击展开 PowerDropdown
// hover 变 error 色作为视觉警示

import QtQuick
import qs.services

Text {
    id: root
    required property var triggerScreen

    text: "power_settings_new"
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20
    // 固定 bounding box 22px,glyph 居中。统一所有 right-cluster 图标的宽度,
    // 让 Row.spacing 给出的视觉间距尽量均匀(不同 Material Symbol glyph 自然宽度不同)
    width: 22
    horizontalAlignment: Text.AlignHCenter
    color: mouse.containsMouse ? Theme.colors.error : Theme.colors.on_surface
    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggleAt(root, "power", root.triggerScreen)
    }
}
