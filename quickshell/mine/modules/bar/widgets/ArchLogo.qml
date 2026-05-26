pragma ComponentBehavior: Bound

// ArchLogo —— Nerd Font 的 Arch Linux 字形(nf-linux-archlinux U+F303)
// Maple Mono NF CN 自带 Nerd Font 字符集,直接用 codepoint。

import QtQuick
import qs.services

Text {
    text: ""
    color: Theme.colors.primary
    font.family: "Maple Mono NF CN"
    font.pixelSize: 20
    font.styleName: "ExtraBold"
}
