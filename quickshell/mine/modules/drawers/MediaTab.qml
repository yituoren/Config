pragma ComponentBehavior: Bound

// MediaTab —— dashboard "Media" tab
//
// 布局(上下交换后):
//   ┌─ 上排:vol pill + sink ▼ + player ▼(按比例分宽,均匀间距)
//   │
//   └─ 下半:[左 文字播放面板(无底板)]  [右 唱片 + cava 环形 halo]
//        - 唱片:圆形封面(MultiEffect mask) + 中心钉 + 周围 32 根 cava bar 朝外辐射
//        - 文字面板:title(小一点)/ artist / album / [歌词留空区] / progress / time / controls
//
// 关键依赖:QtQuick.Effects 的 MultiEffect 把方形封面 mask 成圆形
// Cava service 启 cava 进程,本 Tab 可见时开,销毁时关

import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.services
import qs.modules.bar.widgets

Item {
    id: root

    readonly property MprisPlayer active: MediaPlayer.active
    readonly property real progress: {
        const a = root.active
        return (a && a.length > 0) ? (a.position % a.length) / a.length : 0
    }
    readonly property var defaultSink: SystemStatus.audioSinks.find(s => s.isDefault) || null

    // dropdown 互斥:"" / "sink" / "player"
    property string openMenu: ""

    // Cava 生命周期 —— 通过 needMediaTab 标记;Cava.enabled = needMediaTab || needBarViz
    Component.onCompleted: Cava.needMediaTab = true
    Component.onDestruction: Cava.needMediaTab = false

    // MPRIS position tick
    Timer {
        running: root.active ? root.active.isPlaying : false
        interval: 1000; repeat: true; triggeredOnStart: true
        onTriggered: { if (root.active) root.active.positionChanged() }
    }

    // 唱片旋转
    property real discAngle: 0
    Timer {
        running: root.active ? root.active.isPlaying : false
        interval: 33; repeat: true
        onTriggered: root.discAngle = (root.discAngle + 3) % 360
    }

    function sinkIcon(sink) {
        if (!sink) return "speaker"
        const n = (sink.name ?? "").toLowerCase()
        const d = (sink.description ?? "").toLowerCase()
        if (/bluez/.test(n)) return "bluetooth_audio"
        if (/hdmi/.test(n) || /hdmi/.test(d)) return "tv"
        if (/usb/.test(n) && /head/.test(d)) return "headset"
        return "speaker"
    }

    // ============ 空态 ============
    Item {
        anchors.fill: parent
        visible: !root.active
        Column {
            anchors.centerIn: parent
            spacing: 16
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "music_off"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 72
                color: Theme.colors.on_surface_variant
                opacity: 0.45
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No active media player"
                color: Theme.colors.on_surface_variant
                opacity: 0.6
                font.family: "Maple Mono NF CN"
                font.pixelSize: 14
                font.styleName: "Medium"
            }
        }
    }

    // ============ 主视图 ============
    Item {
        id: mainView
        anchors.fill: parent
        visible: root.active !== null

        // ─────────────────── 上排:vol + sink ▼ + player ▼ ───────────────────
        // 按比例分:vol 36% / sink 28% / player 36%(spacing 内扣)
        Item {
            id: topRow
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                leftMargin: 14
                rightMargin: 14
            }
            height: 44

            readonly property int spacing: 8
            readonly property real cellAvail: width - 2 * spacing

            // vol pill
            Rectangle {
                id: volPill
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Math.round(topRow.cellAvail * 0.30)
                radius: height / 2
                color: Theme.colors.surface_container

                Text {
                    id: volIcon
                    anchors {
                        left: parent.left; leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22; horizontalAlignment: Text.AlignHCenter
                    text: SystemStatus.volumeMuted ? "volume_off"
                          : SystemStatus.volumePercent === 0 ? "volume_mute"
                          : SystemStatus.volumePercent < 34 ? "volume_down"
                          : "volume_up"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: SystemStatus.volumeMuted ? Theme.colors.on_surface_variant : Theme.colors.primary
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemStatus.toggleMute()
                    }
                }
                SliderBar {
                    anchors {
                        left: volIcon.right; leftMargin: 10
                        right: volPctText.left; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    value: SystemStatus.volume
                    onMoved: (v) => SystemStatus.setVolume(v)
                }
                Text {
                    id: volPctText
                    anchors {
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 32; horizontalAlignment: Text.AlignRight
                    text: SystemStatus.volumeMuted ? "—" : `${SystemStatus.volumePercent}%`
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Bold"
                }
            }

            // sink trigger
            Rectangle {
                id: sinkBtn
                anchors {
                    left: volPill.right; leftMargin: topRow.spacing
                    top: parent.top; bottom: parent.bottom
                }
                width: Math.round(topRow.cellAvail * 0.44)
                radius: height / 2
                color: sinkBtnHover.containsMouse
                    ? Qt.tint(Theme.colors.primary_container, "#15ffffff")
                    : Theme.colors.primary_container
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: sinkBtnIcon
                    anchors {
                        left: parent.left; leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22; horizontalAlignment: Text.AlignHCenter
                    text: root.sinkIcon(root.defaultSink)
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.on_primary_container
                }
                Text {
                    anchors {
                        left: sinkBtnIcon.right; leftMargin: 8
                        right: sinkBtnChevron.left; rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.defaultSink ? root.defaultSink.description : "—"
                    color: Theme.colors.on_primary_container
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
                Text {
                    id: sinkBtnChevron
                    anchors {
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.openMenu === "sink" ? "expand_less" : "expand_more"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.on_primary_container
                    opacity: 0.8
                }
                MouseArea {
                    id: sinkBtnHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMenu = root.openMenu === "sink" ? "" : "sink"
                }
            }

            // player trigger
            Rectangle {
                id: playerBtn
                anchors {
                    left: sinkBtn.right; leftMargin: topRow.spacing
                    right: parent.right
                    top: parent.top; bottom: parent.bottom
                }
                radius: height / 2
                color: playerBtnHover.containsMouse
                    ? Theme.colors.surface_container_high
                    : Theme.colors.surface_container
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: playerBtnIcon
                    anchors {
                        left: parent.left; leftMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    width: 22; horizontalAlignment: Text.AlignHCenter
                    text: root.active ? "music_note" : "music_off"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.primary
                }
                Text {
                    anchors {
                        left: playerBtnIcon.right; leftMargin: 8
                        right: playerBtnChevron.left; rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.active ? MediaPlayer.getIdentity(root.active) : "No player"
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
                Text {
                    id: playerBtnChevron
                    anchors {
                        right: parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.openMenu === "player" ? "expand_less" : "expand_more"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                    color: Theme.colors.on_surface
                    opacity: 0.8
                }
                MouseArea {
                    id: playerBtnHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openMenu = root.openMenu === "player" ? "" : "player"
                }
            }
        }

        // ─────────────────── 下半:文字面板 + 唱片 halo ───────────────────
        Item {
            id: playbackArea
            anchors {
                top: topRow.bottom
                topMargin: 14
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 10
            }

            // ---- 左:文字播放面板(无底板)----
            Item {
                id: panel
                anchors {
                    left: parent.left
                    leftMargin: 28
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: 32
                    bottomMargin: 18
                }
                // 给右侧 disc 留位置:disc 280 + disc rightMargin 28 + 中间 gap 28 + panel leftMargin 28 在 anchor 里扣过
                width: parent.width - 280 - 28 - 28 - 28

                // ── 顶部 title / artist / album ──
                Text {
                    id: titleText
                    anchors {
                        top: parent.top
                        left: parent.left; right: parent.right
                    }
                    text: root.active && root.active.trackTitle ? root.active.trackTitle : "Unknown Title"
                    color: Theme.colors.on_surface
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 17
                    font.styleName: "ExtraBold"
                    elide: Text.ElideRight
                }
                Text {
                    id: artistText
                    anchors {
                        top: titleText.bottom; topMargin: 4
                        left: parent.left; right: parent.right
                    }
                    text: root.active && root.active.trackArtist ? root.active.trackArtist : ""
                    color: Theme.colors.primary
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 13
                    font.styleName: "Bold"
                    elide: Text.ElideRight
                }
                Text {
                    id: albumText
                    anchors {
                        top: artistText.bottom; topMargin: 2
                        left: parent.left; right: parent.right
                    }
                    text: root.active && root.active.trackAlbum ? root.active.trackAlbum : ""
                    color: Theme.colors.on_surface_variant
                    opacity: 0.75
                    font.family: "Maple Mono NF CN"
                    font.pixelSize: 12
                    font.styleName: "Medium"
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                // ── 底部:控件 + 时间 + 进度 ──
                Row {
                    id: controlsRow
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                    }
                    spacing: 10

                    component IconBtn: Rectangle {
                        id: btn
                        required property string icon
                        property bool big: false
                        property bool primary: false
                        property bool disabled: false
                        signal clicked()

                        readonly property real sz: btn.big ? 48 : 36
                        width: sz; height: sz; radius: sz / 2
                        color: {
                            if (btn.disabled) return "transparent"
                            if (btn.primary) return btnHover.containsMouse
                                ? Qt.tint(Theme.colors.primary, "#20ffffff")
                                : Theme.colors.primary
                            return btnHover.containsMouse
                                ? Theme.colors.surface_container_high
                                : "transparent"
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        opacity: btn.disabled ? 0.35 : 1
                        scale: btnHover.pressed ? 0.92 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: btn.icon
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: btn.big ? 26 : 20
                            color: btn.primary ? Theme.colors.on_primary : Theme.colors.on_surface
                        }
                        MouseArea {
                            id: btnHover
                            anchors.fill: parent
                            hoverEnabled: !btn.disabled
                            cursorShape: btn.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: if (!btn.disabled) btn.clicked()
                        }
                    }

                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: (root.active && root.active.shuffle) ? "shuffle_on" : "shuffle"
                        disabled: !(root.active && root.active.shuffleSupported)
                        onClicked: { if (root.active) root.active.shuffle = !root.active.shuffle }
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_previous"
                        disabled: !(root.active && root.active.canGoPrevious)
                        onClicked: if (root.active) root.active.previous()
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        big: true; primary: true
                        icon: (root.active && root.active.isPlaying) ? "pause" : "play_arrow"
                        disabled: !(root.active && root.active.canTogglePlaying)
                        onClicked: if (root.active) root.active.togglePlaying()
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "skip_next"
                        disabled: !(root.active && root.active.canGoNext)
                        onClicked: if (root.active) root.active.next()
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: {
                            if (!root.active) return "repeat"
                            switch (root.active.loopState) {
                            case MprisLoopState.Track: return "repeat_one_on"
                            case MprisLoopState.Playlist: return "repeat_on"
                            default: return "repeat"
                            }
                        }
                        disabled: !(root.active && root.active.loopSupported)
                        onClicked: {
                            if (!root.active) return
                            const s = root.active.loopState
                            root.active.loopState = s === MprisLoopState.None
                                ? MprisLoopState.Playlist
                                : s === MprisLoopState.Playlist
                                    ? MprisLoopState.Track
                                    : MprisLoopState.None
                        }
                    }
                }

                Item {
                    id: timeRow
                    anchors {
                        left: parent.left; right: parent.right
                        bottom: controlsRow.top; bottomMargin: 10
                    }
                    height: 14
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: MediaPlayer.formatTime(root.active ? root.active.position : 0)
                        color: Theme.colors.on_surface_variant
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: MediaPlayer.formatTime(root.active ? root.active.length : 0)
                        color: Theme.colors.on_surface_variant
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 11
                    }
                }
                Item {
                    id: progressRow
                    anchors {
                        left: parent.left; right: parent.right
                        bottom: timeRow.top; bottomMargin: 2
                    }
                    height: 22
                    SliderBar {
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        value: root.progress
                        minValue: 0
                        onMoved: (v) => {
                            const a = root.active
                            if (a && a.canSeek && a.positionSupported && a.length > 0) {
                                a.position = v * a.length
                            }
                        }
                    }
                }

                // ── 中间歌词区(占位:前一句 / 当前 / 后一句 三行)──
                // 真实歌词后续接 LyricsService;现在用占位字符串展示布局
                // 当前句字号大 Bold + primary 色;前后句字号小 Medium + 半透 outline 色
                Item {
                    id: lyricArea
                    anchors {
                        top: albumText.bottom; topMargin: 18
                        bottom: progressRow.top; bottomMargin: 18
                        left: parent.left; right: parent.right
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        width: parent.width

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "♪  lyrics coming soon"
                            color: Theme.colors.on_surface_variant
                            opacity: 0.35
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 11
                            font.styleName: "Medium"
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.active ? "♪" : "—"
                            color: Theme.colors.primary
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 15
                            font.styleName: "Bold"
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: ""
                            color: Theme.colors.on_surface_variant
                            opacity: 0.35
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 11
                            font.styleName: "Medium"
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ---- 右:唱片 + cava 环形 halo ----
            Item {
                id: discArea
                anchors {
                    right: parent.right
                    rightMargin: 28
                    verticalCenter: parent.verticalCenter
                }
                width: 280
                height: 280

                readonly property real coverDiameter: 174  // 内圆封面(略缩,留更多 halo 空间)
                readonly property real innerRadius: discArea.coverDiameter / 2 + 8  // halo 起点
                readonly property real maxBar: 36

                // ── cava halo bars ──
                Repeater {
                    model: Cava.bars
                    delegate: Item {
                        id: barItem
                        required property int index
                        readonly property real value: Cava.values[barItem.index] ?? 0
                        readonly property real angle: barItem.index * 360 / Cava.bars

                        anchors.centerIn: parent
                        width: 1; height: 1
                        rotation: barItem.angle

                        Rectangle {
                            // 中心在父 Item (0,0),rotation=0 时朝正上;height 增加杆向外延伸
                            x: -width / 2
                            y: -(discArea.innerRadius + height)
                            width: 4
                            height: Math.max(3, barItem.value * discArea.maxBar)
                            radius: 2
                            color: Theme.colors.primary
                            opacity: 0.55
                            Behavior on height {
                                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                // ── 唱片本体(整圈跟着 discAngle 转)──
                Item {
                    id: discSpin
                    anchors.centerIn: parent
                    width: discArea.coverDiameter
                    height: discArea.coverDiameter
                    rotation: root.discAngle

                    // vinyl 黑底
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#0a0a0a"
                    }

                    // 圆形封面 —— MultiEffect mask 把方形 image 裁圆
                    Image {
                        id: coverImage
                        anchors.centerIn: parent
                        width: discArea.coverDiameter - 16
                        height: discArea.coverDiameter - 16
                        source: root.active ? MediaPlayer.getArtUrl(root.active) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: width
                        sourceSize.height: height
                        visible: false
                    }
                    Item {
                        id: coverMaskShape
                        anchors.fill: coverImage
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "white"
                        }
                    }
                    MultiEffect {
                        anchors.fill: coverImage
                        source: coverImage
                        maskEnabled: true
                        maskSource: coverMaskShape
                        maskThresholdMin: 0.5
                        visible: coverImage.status === Image.Ready
                    }

                    // 没封面时的 fallback
                    Rectangle {
                        anchors.fill: coverImage
                        radius: width / 2
                        color: Theme.colors.surface_container_high
                        visible: coverImage.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 56
                            color: Theme.colors.on_surface_variant
                            opacity: 0.45
                        }
                    }

                    // 中心钉(在旋转层里所以跟着转,符合 vinyl 视觉)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        radius: 7
                        color: Theme.colors.surface_container_high
                        border.color: Theme.colors.outline
                        border.width: 1
                    }
                }
            }
        }

        // ─────────────────── Dropdown menus(在 playbackArea 之后,z 序自然在上)───────────────────
        // sink menu —— 从 sinkBtn 下方展开,覆盖 playbackArea
        Rectangle {
            id: sinkMenu
            visible: root.openMenu === "sink" || menuOpacity > 0
            opacity: menuOpacity
            property real menuOpacity: root.openMenu === "sink" ? 1 : 0
            Behavior on menuOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            x: sinkBtn.x
            y: sinkBtn.y + sinkBtn.height + 6
            width: sinkBtn.width
            height: Math.min(SystemStatus.audioSinks.length * 42 + 12, 220)
            radius: 16
            color: Theme.colors.surface_container_high
            z: 10

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: SystemStatus.audioSinks
                    delegate: Rectangle {
                        id: sinkItem
                        required property var modelData
                        width: parent.width
                        height: 36
                        radius: 12
                        color: sinkItem.modelData.isDefault
                            ? Theme.colors.primary_container
                            : (sinkItemHover.containsMouse ? Theme.colors.surface_container_highest : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: sinkItemIcon
                            anchors {
                                left: parent.left; leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: root.sinkIcon(sinkItem.modelData)
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: sinkItem.modelData.isDefault
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface
                        }
                        Text {
                            anchors {
                                left: sinkItemIcon.right; leftMargin: 8
                                right: parent.right; rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: sinkItem.modelData.description
                            color: sinkItem.modelData.isDefault
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: sinkItem.modelData.isDefault ? "Bold" : "Medium"
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: sinkItemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!sinkItem.modelData.isDefault) {
                                    SystemStatus.setDefaultSink(sinkItem.modelData.name)
                                }
                                root.openMenu = ""
                            }
                        }
                    }
                }
            }
        }

        // player menu
        Rectangle {
            id: playerMenu
            visible: root.openMenu === "player" || menuOpacity > 0
            opacity: menuOpacity
            property real menuOpacity: root.openMenu === "player" ? 1 : 0
            Behavior on menuOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            x: playerBtn.x
            y: playerBtn.y + playerBtn.height + 6
            width: playerBtn.width
            height: Math.max(48, Math.min(MediaPlayer.list.length * 42 + 12, 220))
            radius: 16
            color: Theme.colors.surface_container_high
            z: 10

            Text {
                anchors.centerIn: parent
                visible: MediaPlayer.list.length === 0
                text: "No players"
                color: Theme.colors.on_surface_variant
                opacity: 0.6
                font.family: "Maple Mono NF CN"
                font.pixelSize: 12
            }

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: MediaPlayer.list
                    delegate: Rectangle {
                        id: pItem
                        required property MprisPlayer modelData
                        readonly property bool isActive: pItem.modelData === root.active

                        width: parent.width
                        height: 36
                        radius: 12
                        color: pItem.isActive
                            ? Theme.colors.primary_container
                            : (pItemHover.containsMouse ? Theme.colors.surface_container_highest : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: pItemIcon
                            anchors {
                                left: parent.left; leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: pItem.modelData.isPlaying ? "play_arrow" : "music_note"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: pItem.isActive
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface
                        }
                        Text {
                            anchors {
                                left: pItemIcon.right; leftMargin: 8
                                right: parent.right; rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: MediaPlayer.getIdentity(pItem.modelData)
                            color: pItem.isActive
                                ? Theme.colors.on_primary_container
                                : Theme.colors.on_surface
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: pItem.isActive ? "Bold" : "Medium"
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: pItemHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                MediaPlayer.manualActive = pItem.modelData
                                root.openMenu = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
