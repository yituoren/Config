pragma ComponentBehavior: Bound

// Clock —— HH:mm 时钟显示
// 详细日期 + 秒数 等留给后续 hover 控制面板里的日历组件,这里保持极简

import QtQuick
import qs.services

Text {
    text: DateTime.hhmm
    color: Theme.colors.on_surface
    font.family: "Maple Mono NF CN"
    font.pixelSize: 15
    font.styleName: "ExtraBold"
}
