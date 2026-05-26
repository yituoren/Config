pragma ComponentBehavior: Bound

// FocusedWindowTitle —— 当前焦点窗口的 title,超长省略

import QtQuick
import qs.services

Text {
    id: root

    readonly property var focusedWindow: Niri.windows.find(w => w.id === Niri.focusedWindowId)
    readonly property string overviewTag: Niri.overviewOpen ? "[overview]  " : ""
    readonly property string focusedTitle: {
        if (!focusedWindow) return "(no focus)"
        return focusedWindow.title ?? "(untitled)"
    }

    text: Niri.ready
          ? `${overviewTag}${focusedTitle}`
          : "Niri: connecting..."

    color: Theme.colors.on_surface
    font.family: "Maple Mono NF CN"
    font.pixelSize: 15
    font.styleName: "ExtraBold"
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
}
