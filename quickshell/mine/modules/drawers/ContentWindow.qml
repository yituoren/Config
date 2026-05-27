pragma ComponentBehavior: Bound

// ContentWindow —— 每屏一个全屏 PanelWindow,bar + popup 都画在同一个 scene graph 内,
// 这样 Caelestia.Blobs 的 SDF 着色器才能把它们 metaball 融合(BlobGroup 跨 PanelWindow 不工作)。
//
// 结构(从下到上):
//   1. BlobGroup + 多个 BlobRect(bar / popup)—— SDF 渲染的形状层
//   2. Bar widgets(ArchLogo / WorkspaceIndicator / ...)在 bar 形状之上
//   3. Popup content(Loader,各种 popup component)在 popup 形状之上
//   4. Scrim MouseArea —— popup 开时盖全屏(实际放在 popup 之下),click 关 popup
//
// 输入 mask:
//   - popup 关:只 bar 区域可点(其余穿透到桌面)
//   - popup 开:bar + popup + scrim 全可点(scrim 处理外部点击 → 关 popup)

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Caelestia.Blobs
import qs.services
import qs.modules.bar.widgets

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "mine-shell"
    // Overlay 而非 Top:让 BlurPanel(Top 层,只覆盖 popup 区域,niri 给它开 blur)
    // 渲染在 mine-shell 下方;mine-shell 的 SDF popup 半透 colorBottom 让 blur 画面透过来
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // 走 niri layout.kdl 的 struts 给 bar 留位(struts.top=0,bar 用 exclusive_zone),
    // 这里因为是全屏 anchor,exclusive_zone 没法用,改回靠 struts 预留

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    // ---- bar 几何常量 ----
    readonly property int barTopMargin: 8
    readonly property int barSideMargin: 8
    readonly property int barHeight: 44
    readonly property int barRadius: 16

    // bar 是否在这块屏(scrim/popup 也据此判断)
    readonly property bool popupOnThisScreen: PopupManager.currentScreen === root.modelData

    // popup 几何(屏幕本地坐标)
    // popupScale:[0,1],SDF 形状和 popup 实际显示尺寸都乘它。
    //   默认 = openAmount(0→1 全幅展开)
    //   scaleFrom > 0(如 dashboard)→ 形状从 scaleFrom 起跳,出场幅度小;不展开到 0% 而是 80%→100% 微动
    //   close 时 openAmount → 0,scale 也回到 0(经过 scaleFrom 后 bezier 尾段快速归零)
    // 只看 entry(不 fallback lastEntry):关闭时 entry → null,scaleFrom 立刻回 0,
    // popupScale 退化成 = openAmount,关闭动画就是从 1 → 0 直接收(不会"先缩到 80% 再砰一下消失")
    readonly property real popupScaleFrom: {
        const e = PopupManager.entry
        return e && e.scaleFrom !== undefined ? e.scaleFrom : 0
    }
    readonly property real popupRawAmount: root.popupOnThisScreen ? PopupManager.openAmount : 0
    readonly property real popupScale: {
        const oa = root.popupRawAmount
        const sf = root.popupScaleFrom
        if (sf <= 0) return oa
        if (oa <= 0) return 0
        return Math.min(1, sf + (1 - sf) * oa)
    }
    readonly property real popupWidth: PopupManager.displayWidth * root.popupScale
    // 高度 = 注册表里的 displayHeight + popup 自己动态加的 extraHeight(dropdown 展开用)
    readonly property real popupHeight: (PopupManager.displayHeight + PopupManager.extraHeight) * root.popupScale
    readonly property real popupX: PopupManager.animatedAnchorX - root.popupWidth * PopupManager.triggerRelativeX
    readonly property real popupY: root.barTopMargin + root.barHeight + 4  // 留 4px 给 SDF metaball blend 空间

    // ---- 输入 mask ----
    // popup 关:只 bar 区域捕捉(其余穿透);popup 开:整屏(scrim 捕捉外部 click)
    // 注意 popup 开时所有屏(包括 popup 不在的屏)都设 mask=null —— 这样点别屏空白处也能关 popup
    mask: PopupManager.isOpen ? null : barMask
    Region {
        id: barMask
        x: root.barSideMargin
        y: root.barTopMargin
        width: root.width - 2 * root.barSideMargin
        height: root.barHeight
    }

    // ==================== SDF Blob 形状层 ====================
    Item {
        anchors.fill: parent

        BlobGroup {
            id: blobGroup
            color: "#000000"
            // 平滑因子越大,bar 跟 popup 越容易融合成一坨(metaball)
            smoothing: 32

            // 渐变只给标了 transparent 的 popup(目前只有 dashboard);其它 popup colorBottom = 纯黑 = color,mix 退化
            // 关闭动画时 entry → null,用 lastEntry 保住状态;否则关闭时 popup 还在缩 colorBottom 就先变回纯黑了
            readonly property bool popupTransparent: {
                const e = PopupManager.entry ?? PopupManager.lastEntry
                return e && e.transparent === true
            }
            colorBottom: blobGroup.popupTransparent
                ? Qt.rgba(0, 0, 0, 0.35)
                : Qt.rgba(0, 0, 0, 1)
            gradientTop: root.popupY
            gradientBottom: root.popupY + root.popupHeight
        }

        // bar 形状:顶部固定矩形
        BlobRect {
            id: barShape
            group: blobGroup
            x: root.barSideMargin
            y: root.barTopMargin
            implicitWidth: root.width - 2 * root.barSideMargin
            implicitHeight: root.barHeight
            radius: root.barRadius
        }

        // popup 形状:位置 / 尺寸跟 PopupManager 动画状态走
        BlobRect {
            id: popupShape
            group: blobGroup
            visible: root.popupWidth > 0.5 && root.popupHeight > 0.5
            x: root.popupX
            y: root.popupY
            implicitWidth: root.popupWidth
            implicitHeight: root.popupHeight
            radius: root.barRadius
        }

    }

    // ==================== Cava 律动条层(SDF 之外)====================
    // popup 关闭时从 bar 中心向下倒挂,每根 Rectangle 走 QML Gradient:
    //   top(贴 bar)= primary 透明 → bottom = primary 不透明
    // 没声音(所有 value < 阈值)时整层 opacity 0 → 完全隐身
    // 离开 SDF 体系所以 bars 数 / 宽 / 长全无 16 个 rect 上限制约
    Loader {
        id: cavaVizLoader
        // 只在没"中央 popup"(标 transparent 的,目前是 dashboard)时显示
        // 右侧 wifi/bluetooth/volume/battery/tray/power 是窄 popup,不覆盖中央律动条,无需隐藏
        active: !(PopupManager.entry && PopupManager.entry.transparent === true)
        sourceComponent: cavaVizComp
        anchors.fill: parent
    }

    Component {
        id: cavaVizComp
        Item {
            id: cavaViz
            anchors.fill: parent

            Component.onCompleted: Cava.needBarViz = true
            Component.onDestruction: Cava.needBarViz = false

            // 任一 bar 值超阈值 → 有音乐;全为 0 → 没声音整层淡出
            readonly property bool hasAudio: {
                for (let i = 0; i < Cava.bars; i++) {
                    if ((Cava.values[i] ?? 0) > 0.04) return true
                }
                return false
            }
            opacity: cavaViz.hasAudio ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }

            // 几何:整体宽 = dashboard popup 宽度,bars 均分填满
            // 跟 popup 同宽同居中位置(popup 也居中 root.width/2),关 popup → cava 占同样的位置感
            readonly property real totalW: PopupManager.registry.dashboard.width
            readonly property real spacing: 6
            readonly property real barW: (cavaViz.totalW - (Cava.bars - 1) * cavaViz.spacing) / Cava.bars
            readonly property real maxHang: 96
            readonly property real startX: (root.width - cavaViz.totalW) / 2

            // primary 色对象(从 Theme 拿字符串 → color),抽出 r/g/b 给透明顶部用
            readonly property color primaryColor: Theme.colors.primary

            Repeater {
                model: Cava.bars
                delegate: Rectangle {
                    id: cavaBar
                    required property int index
                    readonly property real value: Cava.values[cavaBar.index] ?? 0

                    x: cavaViz.startX + cavaBar.index * (cavaViz.barW + cavaViz.spacing)
                    y: root.barTopMargin + root.barHeight
                    width: cavaViz.barW
                    height: cavaBar.value * cavaViz.maxHang
                    // 顶部贴 bar(直角),底部圆胶囊头
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: cavaViz.barW / 2
                    bottomRightRadius: cavaViz.barW / 2

                    gradient: Gradient {
                        // 根部纯黑 = bar 同色,无缝伸出;立刻开始过渡到 primary;尾部 primary 渐变透明
                        // 0.0  黑色不透明 → 0.5  primary 饱满 → 1.0  primary 完全透明(尖端化入空气)
                        GradientStop { position: 0;   color: "#000000" }
                        GradientStop { position: 0.5; color: cavaViz.primaryColor }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(cavaViz.primaryColor.r,
                                           cavaViz.primaryColor.g,
                                           cavaViz.primaryColor.b, 0)
                        }
                    }

                    // 80ms OutQuad 让 cava 60Hz 输出再丝滑一层
                    Behavior on height {
                        NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    // ==================== Scrim(popup 外点击关闭)====================
    // 放在 popup 内容之前,这样 popup 内容 click 优先
    // openInProgress 期间吞掉点击不关 —— 防止 hover 触发的 popup 还在展开就被外点闪关
    // 在 popup 不在的别屏也铺 scrim —— 点别屏空白同样关掉 popup(配合上面 mask=null)
    MouseArea {
        anchors.fill: parent
        visible: PopupManager.isOpen
        onClicked: {
            if (!PopupManager.openInProgress) PopupManager.close()
        }
    }

    // ==================== Bar Widgets ====================
    Item {
        id: barContent
        x: root.barSideMargin
        y: root.barTopMargin
        width: root.width - 2 * root.barSideMargin
        height: root.barHeight

        ArchLogo {
            id: archLogo
            anchors {
                left: parent.left
                leftMargin: 18
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
            id: titleText
            anchors.centerIn: parent
            readonly property real leftEdge: workspaceStrip.x + workspaceStrip.width
            readonly property real rightEdge: parent.width - rightCluster.x
            width: Math.min(implicitWidth,
                            parent.width - 2 * Math.max(titleText.leftEdge, titleText.rightEdge) - 32)
        }

        Row {
            id: rightCluster
            anchors {
                right: parent.right
                rightMargin: 18
                verticalCenter: parent.verticalCenter
            }
            spacing: 12

            Clock { anchors.verticalCenter: parent.verticalCenter }
            SystemTrayIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            WifiIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            BluetoothIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            VolumeIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            BatteryIndicator { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
            PowerButton { anchors.verticalCenter: parent.verticalCenter; triggerScreen: root.modelData }
        }

        // ============ Dashboard hover trigger ============
        // bar 正中固定宽窄条 hover 触发,跟 FocusedWindowTitle 中心对齐(都是 horizontalCenter)
        // 宽度限到 320 防止只是想 hover 看标题的鼠标在大半个 bar 范围内被误触
        Item {
            id: dashTriggerArea
            width: 320
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            HoverHandler { id: dashTriggerHover }
        }
    }

    // ==================== Popup Content ====================
    Item {
        id: popupContentArea
        visible: root.popupOnThisScreen && root.popupWidth > 0
        x: root.popupX
        y: root.popupY
        width: root.popupWidth
        height: root.popupHeight
        clip: true


        component PopupItem: Loader {
            id: popupItem
            required property string name
            readonly property bool shouldBeActive: PopupManager.currentPopup === popupItem.name
            anchors.fill: parent
            anchors.margins: 10
            opacity: 0
            active: false

            states: State {
                name: "active"
                when: popupItem.shouldBeActive
                PropertyChanges {
                    popupItem.active: true
                    popupItem.opacity: 1
                }
            }

            transitions: [
                Transition {
                    from: "active"; to: ""
                    SequentialAnimation {
                        NumberAnimation {
                            property: "opacity"; duration: 280
                            easing.type: Easing.OutQuad
                        }
                        PropertyAction { property: "active" }
                    }
                },
                Transition {
                    from: ""; to: "active"
                    SequentialAnimation {
                        PropertyAction { property: "active" }
                        NumberAnimation {
                            property: "opacity"; duration: 280
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            ]
        }

        PopupItem { name: "power";     sourceComponent: powerComp     }
        PopupItem { name: "wifi";      sourceComponent: wifiComp      }
        PopupItem { name: "bluetooth"; sourceComponent: bluetoothComp }
        PopupItem { name: "volume";    sourceComponent: volumeComp    }
        PopupItem { name: "battery";   sourceComponent: batteryComp   }
        PopupItem { name: "tray";      sourceComponent: trayComp      }
        PopupItem { name: "dashboard"; sourceComponent: dashboardComp }
    }

    // ==================== Popup 内容组件 ====================
    // 临时全部 inline,后续可拆文件

    // 共享 Process,给 power menu 执行命令用
    Process { id: actionProcInternal }

    // ==================== Dashboard hover-open ====================
    // 鼠标进 bar 中间 → 80ms 短延迟 → 开 dashboard。延迟防止鼠标快速划过秒触发,但不要长到感觉"慢半拍"
    // 不再自动关:popup 像其他 popup 一样靠 scrim click / 切到别的 popup 来关
    Connections {
        target: dashTriggerHover
        function onHoveredChanged() {
            if (dashTriggerHover.hovered) {
                if (PopupManager.currentPopup !== "dashboard") {
                    dashOpenTimer.restart()
                }
            } else {
                dashOpenTimer.stop()
            }
        }
    }

    Timer {
        id: dashOpenTimer
        interval: 80
        repeat: false
        onTriggered: {
            // anchorX = 屏正中。barContent 也是 horizontalCenter 居中,所以 FocusedWindowTitle / trigger
            // / popup 三者中线对齐,popup 看起来正卡在窗口标题正下方
            PopupManager.open("dashboard", root.modelData, root.width / 2)
        }
    }

    // =================== Power(2×2 图标网格)===================
    Component {
        id: powerComp
        Grid {
            columns: 2
            spacing: 12
            // 每个按钮一种 Material 颜色,图标颜色用对应的 on_*_container token
            Repeater {
                model: [
                    { iconName: "lock", bgColor: "secondary_container", fgColor: "on_secondary_container", cmd: ["loginctl", "lock-session"] },
                    { iconName: "logout", bgColor: "tertiary_container", fgColor: "on_tertiary_container", cmd: ["niri", "msg", "action", "quit"] },
                    { iconName: "restart_alt", bgColor: "primary_container", fgColor: "on_primary_container", cmd: ["systemctl", "reboot"] },
                    { iconName: "power_settings_new", bgColor: "error_container", fgColor: "on_error_container", cmd: ["systemctl", "poweroff"] }
                ]
                Rectangle {
                    id: powerItem
                    required property var modelData
                    width: (parent.width - 12) / 2
                    height: width
                    radius: 20
                    color: powerHover.containsMouse
                        ? Qt.tint(Theme.colors[powerItem.modelData.bgColor], "#20ffffff")
                        : Theme.colors[powerItem.modelData.bgColor]
                    Behavior on color { ColorAnimation { duration: 150 } }
                    scale: powerHover.pressed ? 0.95 : 1
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: powerItem.modelData.iconName
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 42
                        color: Theme.colors[powerItem.modelData.fgColor]
                    }

                    MouseArea {
                        id: powerHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            actionProcInternal.command = powerItem.modelData.cmd
                            actionProcInternal.running = true
                            PopupManager.close()
                        }
                    }
                }
            }
        }
    }

    // =================== Wifi(开关 + 当前连接 + 网络列表)===================
    Component {
        id: wifiComp
        Item {
            Component.onCompleted: SystemStatus.refreshWifi()

            // 顶部:飞行模式 + wifi 开关 + refresh(三档,refresh 是正方形小按钮)
            Row {
                id: switchRow
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 56
                spacing: 12

                // 飞行模式
                Rectangle {
                    // 总宽减 refresh(56)再扣 2 个 spacing,剩余对半分
                    width: (switchRow.width - switchRow.spacing * 2 - 56) / 2
                    height: parent.height
                    radius: 16
                    color: Theme.colors.surface_container
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: "airplanemode_active"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: SystemStatus.airplaneMode ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    IosSwitch {
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        checked: SystemStatus.airplaneMode
                        onToggled: SystemStatus.toggleAirplaneMode()
                    }
                }

                // Wifi 开关
                Rectangle {
                    width: (switchRow.width - switchRow.spacing * 2 - 56) / 2
                    height: parent.height
                    radius: 16
                    color: Theme.colors.surface_container
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: SystemStatus.wifiEnabled ? "wifi" : "wifi_off"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: SystemStatus.wifiEnabled ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    IosSwitch {
                        anchors {
                            right: parent.right
                            rightMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        checked: SystemStatus.wifiEnabled
                        onToggled: SystemStatus.toggleWifi()
                    }
                }

                // Refresh 按钮(正方形 56×56 图标卡)
                Rectangle {
                    width: 56
                    height: parent.height
                    radius: 16
                    color: wifiRefreshHover.containsMouse ? Theme.colors.surface_container_high : Theme.colors.surface_container
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: wifiRefreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: Theme.colors.on_surface

                        // 点击时图标转一圈
                        property real rot: 0
                        rotation: rot
                        Behavior on rot {
                            NumberAnimation { duration: 500; easing.type: Easing.OutQuad }
                        }
                    }

                    MouseArea {
                        id: wifiRefreshHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SystemStatus.refreshWifi()
                            wifiRefreshIcon.rot += 360
                        }
                    }
                }
            }

            // 当前连接状态(connected: primary_container 着色;disconnected: surface_container)
            Rectangle {
                id: wifiHeader
                anchors {
                    top: switchRow.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: SystemStatus.wifiConnected
                    ? Theme.colors.primary_container
                    : Theme.colors.surface_container

                Text {
                    id: wifiHeaderIcon
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.wifiConnected ? "wifi" : "wifi_off"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 32
                    color: SystemStatus.wifiConnected
                        ? Theme.colors.on_primary_container
                        : Theme.colors.on_surface_variant
                }
                Column {
                    anchors {
                        left: wifiHeaderIcon.right
                        leftMargin: 14
                        right: parent.right
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        text: SystemStatus.wifiConnected ? SystemStatus.wifiSsid : "Not connected"
                        color: SystemStatus.wifiConnected
                            ? Theme.colors.on_primary_container
                            : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 16
                        font.styleName: "Bold"
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        visible: SystemStatus.wifiConnected
                        text: `${SystemStatus.wifiSignal}%`
                        color: Theme.colors.on_primary_container
                        opacity: 0.7
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 12
                    }
                }
            }

            // 网络列表
            ListView {
                anchors {
                    top: wifiHeader.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                model: SystemStatus.wifiNetworks
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: wifiRow
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: 12
                    color: wifiRowHover.containsMouse
                        ? Theme.colors.surface_container_high
                        : (wifiRow.modelData.inUse ? Theme.colors.surface_container : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // 信号强度 icon —— 按 SSID 是否当前连接 / 是否加密 / 信号强度选不同 Material Symbols
                    Text {
                        id: signalIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            const s = wifiRow.modelData.signal
                            if (wifiRow.modelData.secured) {
                                if (s >= 75) return "network_wifi_3_bar_locked"
                                if (s >= 50) return "network_wifi_2_bar_locked"
                                if (s >= 25) return "network_wifi_1_bar_locked"
                                return "signal_wifi_0_bar"
                            }
                            if (s >= 75) return "signal_wifi_4_bar"
                            if (s >= 50) return "network_wifi_3_bar"
                            if (s >= 25) return "network_wifi_2_bar"
                            if (s > 0)  return "network_wifi_1_bar"
                            return "signal_wifi_0_bar"
                        }
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: wifiRow.modelData.inUse ? Theme.colors.primary : Theme.colors.on_surface
                    }

                    Text {
                        anchors {
                            left: signalIcon.right
                            leftMargin: 10
                            right: checkIcon.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: wifiRow.modelData.ssid
                        color: wifiRow.modelData.inUse ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: wifiRow.modelData.inUse ? "Bold" : "Medium"
                        elide: Text.ElideRight
                    }

                    // 已连接的网络打勾
                    Text {
                        id: checkIcon
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: wifiRow.modelData.inUse
                        text: "check"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.primary
                    }

                    MouseArea {
                        id: wifiRowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!wifiRow.modelData.inUse) {
                                SystemStatus.connectWifi(wifiRow.modelData.ssid)
                                // 不关闭 popup,让用户看到刷新后的连接状态
                            }
                        }
                    }
                }
            }
        }
    }

    // =================== Bluetooth(开关 + 状态 + 设备列表)===================
    Component {
        id: bluetoothComp
        Item {
            Component.onCompleted: SystemStatus.refreshBluetooth()

            // 顶部:bluetooth 开关 + refresh(没飞行模式,wifi popup 已经有)
            Row {
                id: btSwitchRow
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 56
                spacing: 12

                Rectangle {
                    width: btSwitchRow.width - btSwitchRow.spacing - 56
                    height: parent.height
                    radius: 16
                    color: Theme.colors.surface_container
                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: SystemStatus.bluetoothPowered ? "bluetooth" : "bluetooth_disabled"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: SystemStatus.bluetoothPowered ? Theme.colors.primary : Theme.colors.on_surface_variant
                    }
                    IosSwitch {
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        checked: SystemStatus.bluetoothPowered
                        onToggled: SystemStatus.toggleBluetooth()
                    }
                }

                // Refresh
                Rectangle {
                    width: 56
                    height: parent.height
                    radius: 16
                    color: btRefreshHover.containsMouse ? Theme.colors.surface_container_high : Theme.colors.surface_container
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: btRefreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: Theme.colors.on_surface

                        property real rot: 0
                        rotation: rot
                        Behavior on rot {
                            NumberAnimation { duration: 500; easing.type: Easing.OutQuad }
                        }
                    }

                    MouseArea {
                        id: btRefreshHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SystemStatus.refreshBluetooth()
                            btRefreshIcon.rot += 360
                        }
                    }
                }
            }

            // 状态卡:已连接数 / off
            Rectangle {
                id: btHeader
                anchors {
                    top: btSwitchRow.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: SystemStatus.bluetoothConnected
                    ? Theme.colors.primary_container
                    : Theme.colors.surface_container

                Text {
                    id: btHeaderIcon
                    anchors {
                        left: parent.left
                        leftMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.bluetoothPowered
                          ? (SystemStatus.bluetoothConnected ? "bluetooth_connected" : "bluetooth")
                          : "bluetooth_disabled"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 32
                    color: SystemStatus.bluetoothConnected
                        ? Theme.colors.on_primary_container
                        : Theme.colors.on_surface_variant
                }
                Text {
                    anchors {
                        left: btHeaderIcon.right
                        leftMargin: 14
                        right: parent.right
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    text: !SystemStatus.bluetoothPowered ? "Bluetooth off"
                          : SystemStatus.bluetoothConnected
                                ? (SystemStatus.bluetoothDeviceCount === 1
                                    ? "1 device connected"
                                    : `${SystemStatus.bluetoothDeviceCount} devices connected`)
                                : "No devices connected"
                    color: SystemStatus.bluetoothConnected
                        ? Theme.colors.on_primary_container
                        : Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 16
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
            }

            // 设备列表
            ListView {
                anchors {
                    top: btHeader.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                model: SystemStatus.bluetoothDevices
                clip: true
                spacing: 4

                // 没有 paired 设备时给个提示
                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: SystemStatus.bluetoothPowered ? "No paired devices" : ""
                    color: Theme.colors.on_surface_variant
                    opacity: 0.6
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                }

                delegate: Rectangle {
                    id: btRow
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: 12
                    color: btRowHover.containsMouse
                        ? Theme.colors.surface_container_high
                        : (btRow.modelData.connected ? Theme.colors.surface_container : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // 按设备名简单猜个 Material Symbol icon
                    readonly property string deviceIcon: {
                        const n = btRow.modelData.name.toLowerCase()
                        if (/headphone|headset|buds|airpod|earbud/.test(n)) return "headphones"
                        if (/keyboard|kbd/.test(n)) return "keyboard"
                        if (/mouse|trackpad/.test(n)) return "mouse"
                        if (/speaker|soundbar/.test(n)) return "speaker"
                        if (/phone|pixel|iphone|samsung|xiaomi|huawei/.test(n)) return "smartphone"
                        if (/watch/.test(n)) return "watch"
                        if (/laptop|macbook|computer/.test(n)) return "laptop_chromebook"
                        return "bluetooth"
                    }

                    Text {
                        id: btDevIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: btRow.deviceIcon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: btRow.modelData.connected ? Theme.colors.primary : Theme.colors.on_surface
                    }

                    Text {
                        anchors {
                            left: btDevIcon.right
                            leftMargin: 10
                            right: btCheckIcon.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: btRow.modelData.name
                        color: btRow.modelData.connected ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: btRow.modelData.connected ? "Bold" : "Medium"
                        elide: Text.ElideRight
                    }

                    Text {
                        id: btCheckIcon
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: btRow.modelData.connected
                        text: "check"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.primary
                    }

                    MouseArea {
                        id: btRowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (btRow.modelData.connected) {
                                SystemStatus.disconnectBluetoothDevice(btRow.modelData.mac)
                            } else {
                                SystemStatus.connectBluetoothDevice(btRow.modelData.mac)
                            }
                        }
                    }
                }
            }
        }
    }

    // =================== Volume(顶部音量条 + sink 下拉)===================
    Component {
        id: volumeComp
        Item {
            id: volRoot
            Component.onCompleted: SystemStatus.refreshAudio()

            // 当前默认 sink
            readonly property var defaultSink: SystemStatus.audioSinks.find(s => s.isDefault) || null
            // 展开状态(从 PopupManager.extraHeight 派生)
            readonly property bool sinksExpanded: PopupManager.extraHeight > 4

            function sinkIcon(sink) {
                if (!sink) return "speaker"
                const n = sink.name.toLowerCase()
                const d = sink.description.toLowerCase()
                if (/bluez/.test(n)) return "bluetooth_audio"
                if (/hdmi/.test(n) || /hdmi/.test(d)) return "tv"
                if (/usb/.test(n) && /head/.test(d)) return "headset"
                return "speaker"
            }

            // 顶部:音量条
            Rectangle {
                id: volCard
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: Theme.colors.surface_container

                Text {
                    id: volMuteIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: SystemStatus.volumeMuted ? "volume_off"
                          : SystemStatus.volumePercent === 0 ? "volume_mute"
                          : SystemStatus.volumePercent < 34 ? "volume_down"
                          : "volume_up"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 26
                    color: SystemStatus.volumeMuted ? Theme.colors.on_surface_variant : Theme.colors.primary
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemStatus.toggleMute()
                    }
                }

                SliderBar {
                    anchors {
                        left: volMuteIcon.right
                        leftMargin: 12
                        right: volPercentText.left
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    value: SystemStatus.volume
                    onMoved: (v) => SystemStatus.setVolume(v)
                }

                Text {
                    id: volPercentText
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: SystemStatus.volumeMuted ? "—" : `${SystemStatus.volumePercent}%`
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 14
                    font.styleName: "Bold"
                }
            }

            // sink 下拉按钮(显示当前 sink + chevron;点击切换 extraHeight)
            // 用 primary_container 跟 wifi/bluetooth 当前连接卡同款"亮色"风格 —— 输出设备一定有当前选中的
            Rectangle {
                id: sinkButton
                anchors {
                    top: volCard.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 56
                radius: 16
                color: sinkButtonHover.containsMouse
                    ? Qt.tint(Theme.colors.primary_container, "#15ffffff")
                    : Theme.colors.primary_container
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: curSinkIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: volRoot.sinkIcon(volRoot.defaultSink)
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Theme.colors.on_primary_container
                }

                Text {
                    anchors {
                        left: curSinkIcon.right
                        leftMargin: 10
                        right: chevron.left
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: volRoot.defaultSink ? volRoot.defaultSink.description : "—"
                    color: Theme.colors.on_primary_container
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }

                Text {
                    id: chevron
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: volRoot.sinksExpanded ? "expand_less" : "expand_more"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Theme.colors.on_primary_container
                    opacity: 0.7
                }

                MouseArea {
                    id: sinkButtonHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PopupManager.extraHeight = volRoot.sinksExpanded ? 0 : 160
                }
            }

            // 下拉的 sink 列表;只在 sinksExpanded 时占位渲染
            ListView {
                id: sinkList
                anchors {
                    top: sinkButton.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                visible: volRoot.sinksExpanded
                model: SystemStatus.audioSinks
                clip: true
                spacing: 4

                delegate: Rectangle {
                    id: sinkRow
                    required property var modelData
                    width: ListView.view.width
                    height: 40
                    radius: 12
                    color: sinkHover.containsMouse
                        ? Theme.colors.surface_container_high
                        : (sinkRow.modelData.isDefault ? Theme.colors.surface_container : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: sinkIconText
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        width: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: volRoot.sinkIcon(sinkRow.modelData)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: sinkRow.modelData.isDefault ? Theme.colors.primary : Theme.colors.on_surface
                    }

                    Text {
                        anchors {
                            left: sinkIconText.right
                            leftMargin: 10
                            right: sinkCheck.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: sinkRow.modelData.description
                        color: sinkRow.modelData.isDefault ? Theme.colors.primary : Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: sinkRow.modelData.isDefault ? "Bold" : "Medium"
                        elide: Text.ElideRight
                    }

                    Text {
                        id: sinkCheck
                        anchors {
                            right: parent.right
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        visible: sinkRow.modelData.isDefault
                        text: "check"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Theme.colors.primary
                    }

                    MouseArea {
                        id: sinkHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!sinkRow.modelData.isDefault) {
                                SystemStatus.setDefaultSink(sinkRow.modelData.name)
                            }
                            // 选完自动收起
                            PopupManager.extraHeight = 0
                        }
                    }
                }
            }
        }
    }

    // =================== Battery(电池信息 + 屏幕亮度)===================
    Component {
        id: batteryComp
        Item {
            id: batRoot

            // popup 所在屏的名字(亮度按此找 backlight 后端)
            readonly property string screenName: PopupManager.currentScreen ? PopupManager.currentScreen.name : ""
            readonly property bool hasBrightness: batRoot.screenName.length > 0
            readonly property real currentBrightness: {
                if (!batRoot.screenName) return 1.0
                const v = SystemStatus.brightnessByScreen[batRoot.screenName]
                return v !== undefined ? v : 1.0
            }
            readonly property int currentBrightnessPct: Math.round(batRoot.currentBrightness * 100)

            Component.onCompleted: {
                if (!batRoot.screenName) return
                // 有缓存(包括启动 prefetch 或上次 setBrightness 的乐观值)→ 不跑 ddcutil,popup 立刻就稳
                if (SystemStatus.brightnessByScreen[batRoot.screenName] !== undefined) return
                // 没缓存:内屏快 fetch;外屏延后 fetch(兜底,通常 prefetch 已经回来了不会进这里)
                if (SystemStatus.brightnessBackendFor(batRoot.screenName) === "brightnessctl") {
                    SystemStatus.fetchBrightnessFor(batRoot.screenName)
                } else {
                    ddcutilFetchDelay.start()
                }
            }
            Timer {
                id: ddcutilFetchDelay
                interval: 500
                repeat: false
                onTriggered: {
                    if (batRoot.screenName) SystemStatus.fetchBrightnessFor(batRoot.screenName)
                }
            }

            readonly property bool lowBattery: SystemStatus.batteryPercent >= 0
                                              && SystemStatus.batteryPercent <= 15
                                              && !SystemStatus.batteryCharging

            // 顶卡:电池信息(图标 + 百分比 + 状态),用 primary_container 亮色 —— 电池总是"在用"
            Rectangle {
                id: batCard
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 64
                radius: 16
                color: batRoot.lowBattery ? Theme.colors.error_container : Theme.colors.primary_container

                Text {
                    id: batCardIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: SystemStatus.batteryCharging ? "battery_charging_full"
                          : SystemStatus.batteryPercent >= 95 ? "battery_full"
                          : SystemStatus.batteryPercent <= 15 ? "battery_alert"
                          : "battery_5_bar"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 26
                    color: batRoot.lowBattery ? Theme.colors.on_error_container : Theme.colors.on_primary_container
                }
                Text {
                    id: batPctText
                    anchors {
                        left: batCardIcon.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.batteryPercent >= 0 ? `${SystemStatus.batteryPercent}%` : "—"
                    color: batRoot.lowBattery ? Theme.colors.on_error_container : Theme.colors.on_primary_container
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 18
                    font.styleName: "Bold"
                }
                Text {
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    text: SystemStatus.batteryCharging ? "charging" : SystemStatus.batteryStatus.toLowerCase()
                    color: batRoot.lowBattery ? Theme.colors.on_error_container : Theme.colors.on_primary_container
                    opacity: 0.7
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                }
            }

            // 亮度卡:仅调当前屏(brightnessctl 给内屏 / ddcutil 给外屏)
            Rectangle {
                id: brightCard
                anchors {
                    top: batCard.bottom
                    topMargin: 12
                    left: parent.left
                    right: parent.right
                }
                height: 56
                radius: 16
                color: Theme.colors.surface_container

                Text {
                    id: brightIcon
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: batRoot.currentBrightnessPct < 34 ? "brightness_low"
                          : batRoot.currentBrightnessPct < 67 ? "brightness_medium"
                          : "brightness_high"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 24
                    color: Theme.colors.primary
                }

                SliderBar {
                    anchors {
                        left: brightIcon.right
                        leftMargin: 12
                        right: brightPctText.left
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    value: batRoot.currentBrightness
                    minValue: 0.05
                    onMoved: (v) => {
                        if (batRoot.screenName) SystemStatus.setBrightnessFor(batRoot.screenName, v)
                    }
                }

                Text {
                    id: brightPctText
                    anchors {
                        right: parent.right
                        rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: `${batRoot.currentBrightnessPct}%`
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 14
                    font.styleName: "Bold"
                }
            }
        }
    }

    // =================== Dashboard(中央大 popup,4 tab 框架)===================
    // 顶栏 4 tab:media / dashboard / weather / control
    // 当前 tab 用 primary 色文字 + 下方滑动下划线指示;切换时下划线在 tab 间平滑滑过去
    // 内容区目前只是占位(图标 + "coming soon"),后续每个 tab 单独实现
    Component {
        id: dashboardComp
        Item {
            id: dashRoot

            // tab 状态存在 PopupManager(Singleton)上 —— Loader 销毁重建后 popup 再次打开还是上次那个 tab
            // 默认 "dashboard"(PopupManager 里设的初始值)
            readonly property string currentTab: PopupManager.dashboardTab

            readonly property var tabs: [
                { key: "media",     label: "Media",     icon: "music_note" },
                { key: "dashboard", label: "Dashboard", icon: "dashboard" },
                { key: "weather",   label: "Weather",   icon: "partly_cloudy_day" },
                { key: "control",   label: "Control",   icon: "tune" }
            ]

            // ============ 顶栏 ============
            Item {
                id: tabBar
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 44

                // tab 容器:Row 居中,Repeater 每个 tab 一个 Item
                // 每个 tab 不画自己的下划线 —— 共享一根 underline Rectangle 在外面,
                // 用 Behavior 平滑 x/width 在 tab 间滑动
                // tab 容器:整宽 N 等分,每个 tab Item 平均一份,label 在 Item 里居中
                Row {
                    id: tabRow
                    anchors.fill: parent

                    Repeater {
                        id: tabRepeater
                        model: dashRoot.tabs

                        delegate: Item {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool isActive: dashRoot.currentTab === tab.modelData.key
                            // 暴露 label 实际宽度给 underline 用,让下划线精确卡在文字底下
                            readonly property real labelWidth: tabLabel.implicitWidth

                            width: tabRow.width / tabRepeater.count
                            height: tabBar.height

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: tab.modelData.label
                                color: tab.isActive ? Theme.colors.primary : Theme.colors.on_surface_variant
                                font.family: "Maple Mono NF CN"
                                font.pixelSize: 16
                                font.styleName: tab.isActive ? "ExtraBold" : "Medium"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PopupManager.dashboardTab = tab.modelData.key
                            }
                        }
                    }
                }

                // 滑动下划线 —— 跟随当前 active tab 的 label 中心 + label 宽度
                Rectangle {
                    id: underline
                    readonly property Item activeTab: {
                        for (let i = 0; i < tabRepeater.count; i++) {
                            const t = tabRepeater.itemAt(i)
                            if (t && t.isActive) return t
                        }
                        return null
                    }
                    readonly property real targetX: underline.activeTab
                        ? tabRow.x + underline.activeTab.x
                            + (underline.activeTab.width - underline.activeTab.labelWidth) / 2 - 6
                        : 0
                    readonly property real targetW: underline.activeTab
                        ? underline.activeTab.labelWidth + 12
                        : 0

                    x: underline.targetX
                    width: underline.targetW
                    height: 2
                    radius: 1
                    color: Theme.colors.primary
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    visible: underline.activeTab !== null

                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                    Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                }
            }

            // ============ 内容区 ============
            // Loader 按 currentTab 切换 source;已实现的 tab → 自己的 Component / 文件,
            // 没实现的 tab → placeholderComp("图标 + coming soon")
            Loader {
                id: contentLoader
                anchors {
                    top: tabBar.bottom
                    topMargin: 16
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                sourceComponent: {
                    switch (dashRoot.currentTab) {
                    case "media": return mediaTabComp
                    default: return placeholderComp
                    }
                }
            }

            Component {
                id: mediaTabComp
                MediaTab {}
            }

            // 未实现的 tab 占位
            Component {
                id: placeholderComp
                Item {
                    id: phRoot
                    readonly property var activeTabData: dashRoot.tabs.find(t => t.key === dashRoot.currentTab) || null

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: phRoot.activeTabData ? phRoot.activeTabData.icon : "dashboard"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 72
                            color: Theme.colors.on_surface_variant
                            opacity: 0.45
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: phRoot.activeTabData
                                ? `${phRoot.activeTabData.label} — coming soon`
                                : ""
                            color: Theme.colors.on_surface_variant
                            opacity: 0.6
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 13
                            font.styleName: "Medium"
                        }
                    }
                }
            }
        }
    }

    // =================== System Tray ===================
    // 列出所有 StatusNotifierItem(clash-verge / fcitx5 等)。
    // 左键 activate(默认动作);右键 secondaryActivate;滚轮 scroll。
    Component {
        id: trayComp
        ListView {
            anchors.fill: parent
            clip: true
            spacing: 4
            model: SystemTray.items

            delegate: Rectangle {
                id: trayRow
                required property SystemTrayItem modelData
                width: ListView.view.width
                height: 40
                radius: 10
                color: trayHover.containsMouse ? Theme.colors.surface_container_high : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 12

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: trayRow.modelData.icon
                        sourceSize.width: 22
                        sourceSize.height: 22
                        width: 22
                        height: 22
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: trayRow.modelData.title || trayRow.modelData.id
                        color: Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 13
                        font.styleName: "Bold"
                        elide: Text.ElideRight
                        width: trayRow.width - 24 - 22 - 12
                    }
                }

                MouseArea {
                    id: trayHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            trayRow.modelData.secondaryActivate()
                        } else {
                            trayRow.modelData.activate()
                        }
                        PopupManager.close()
                    }
                    onWheel: (event) => {
                        trayRow.modelData.scroll(event.angleDelta.y, false)
                        event.accepted = true
                    }
                }
            }
        }
    }
}
