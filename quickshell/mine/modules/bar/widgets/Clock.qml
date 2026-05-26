pragma ComponentBehavior: Bound

// Clock —— HH:mm,鼠标悬停时换成完整日期
// 后续可扩成点击弹日历

import QtQuick
import qs.services

Text {
    id: root
    text: hover.hovered ? DateTime.dateShort + "  " + DateTime.hhmmss
                        : DateTime.hhmm
    color: Theme.colors.on_surface
    font.family: "Maple Mono NF CN"
    font.pixelSize: 15
    font.styleName: "ExtraBold"

    HoverHandler { id: hover }
}
