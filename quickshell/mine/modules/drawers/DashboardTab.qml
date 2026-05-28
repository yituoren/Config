pragma ComponentBehavior: Bound

// DashboardTab —— dashboard "Dashboard" tab
//
// 布局:
//   左 ~45% : 时间块(上)+ 双切换 pill(Notifications / Todo)+ 列表(下)
//             - Notifications 模式:Notifications.history,可点展开 / X 单条 / Clear all
//             - Todo 模式:Tasks.tasksOn(selectedDate),checkbox 完成 / X 删除 / 底部 add 输入框
//   右 ~55% : Calendar 独占,点格子选 selectedDate(联动左侧 Todo 模式)
//
// activeList 状态:"notif" | "todo",默认 "notif"

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services

Item {
    id: root

    property date viewDate: new Date()
    property date selectedDate: new Date()
    property string activeList: "notif"   // "notif" | "todo"

    function gridStart(d: var): date {
        const first = new Date(d.getFullYear(), d.getMonth(), 1)
        const dow = first.getDay()
        return new Date(d.getFullYear(), d.getMonth(), 1 - dow)
    }

    function sameDay(a: var, b: var): bool {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    function shiftMonth(delta: int): void {
        const v = root.viewDate
        root.viewDate = new Date(v.getFullYear(), v.getMonth() + delta, 1)
    }

    function isoDate(d: var): string {
        return Qt.formatDateTime(d, "yyyy-MM-dd")
    }

    readonly property var todayTasks: Tasks.tasksOn(root.selectedDate)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 24
        spacing: 24

        // ╔══════════════════ 左半(~45%) ══════════════════╗
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.45
            Layout.minimumWidth: parent.width * 0.45
            spacing: 14

            // ─── TimeBlock ───
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 84

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: DateTime.hhmm
                        color: Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 52
                        font.styleName: "ExtraBold"
                    }

                    Row {
                        spacing: 12
                        Text {
                            text: Qt.formatDateTime(DateTime.now, "yyyy-MM-dd dddd")
                            color: Theme.colors.on_surface_variant
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: "Medium"
                        }
                        Text {
                            text: "⛅ —"
                            color: Theme.colors.on_surface_variant
                            opacity: 0.55
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: "Medium"
                        }
                    }
                }
            }

            // ─── 切换开关 ───
            // 两个 pill 并排,带动画滑动的高亮底
            Rectangle {
                id: switcher
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 17
                color: Qt.rgba(1, 1, 1, 0.05)

                readonly property real cellW: width / 2

                // 滑动 highlight
                Rectangle {
                    width: switcher.cellW
                    height: parent.height
                    radius: parent.radius
                    color: Theme.colors.primary_container
                    x: root.activeList === "notif" ? 0 : switcher.cellW
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 0.61, 0.36, 1, 1, 1] } }
                }

                Row {
                    anchors.fill: parent
                    Repeater {
                        model: [
                            { key: "notif", label: "Notifications", icon: "notifications", count: Notifications.count },
                            { key: "todo",  label: "Todo",          icon: "task_alt",      count: root.todayTasks.length }
                        ]
                        delegate: Item {
                            required property var modelData
                            required property int index
                            readonly property bool isActive: root.activeList === modelData.key
                            width: switcher.cellW
                            height: switcher.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.modelData.icon
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 16
                                    color: parent.parent.isActive
                                        ? Theme.colors.on_primary_container
                                        : Theme.colors.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.parent.modelData.label
                                    color: parent.parent.isActive
                                        ? Theme.colors.on_primary_container
                                        : Theme.colors.on_surface_variant
                                    font.family: "Maple Mono NF CN"
                                    font.pixelSize: 12
                                    font.styleName: parent.parent.isActive ? "ExtraBold" : "Medium"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(16, countLabel.implicitWidth + 8)
                                    height: 16
                                    radius: 8
                                    color: parent.parent.isActive
                                        ? Qt.rgba(0, 0, 0, 0.18)
                                        : Qt.rgba(1, 1, 1, 0.08)
                                    visible: parent.parent.modelData.count > 0
                                    Text {
                                        id: countLabel
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData.count
                                        color: parent.parent.parent.isActive
                                            ? Theme.colors.on_primary_container
                                            : Theme.colors.on_surface_variant
                                        font.family: "Maple Mono NF CN"
                                        font.pixelSize: 10
                                        font.styleName: "ExtraBold"
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeList = parent.modelData.key
                            }
                        }
                    }
                }
            }

            // ─── 列表区 ───
            // notif / todo 两套 UI 用 Loader + 滑动横向切换;active 变化时 opacity 渐变
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Notifications
                Item {
                    anchors.fill: parent
                    visible: root.activeList === "notif"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // 顶上一行 "Clear all"
                    Item {
                        id: notifHeader
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: clearLabel.implicitWidth + 20
                        height: 24
                        visible: Notifications.count > 0

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear all"
                            color: Theme.colors.on_surface_variant
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 11
                            font.styleName: "Medium"
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.clearAll()
                        }
                    }

                    // 空状态
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: Notifications.count === 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "notifications_off"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 40
                            color: Theme.colors.on_surface_variant
                            opacity: 0.45
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All caught up"
                            color: Theme.colors.on_surface_variant
                            opacity: 0.6
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: "Medium"
                        }
                    }

                    ListView {
                        anchors.top: Notifications.count > 0 ? notifHeader.bottom : parent.top
                        anchors.topMargin: Notifications.count > 0 ? 4 : 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        spacing: 6
                        visible: Notifications.count > 0
                        model: Notifications.history
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property bool expanded: Notifications.expandedId === card.modelData.id

                            width: ListView.view.width
                            height: bodyCol.implicitHeight + 16
                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            radius: 12
                            color: cardHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.06)
                                : Qt.rgba(1, 1, 1, 0.03)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            MouseArea {
                                id: cardHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifications.toggleExpand(card.modelData.id)
                            }

                            Column {
                                id: bodyCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 3

                                Item {
                                    width: parent.width
                                    height: 16

                                    IconImage {
                                        id: appIcon
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 13
                                        height: 13
                                        source: card.modelData.appIcon
                                            ? Quickshell.iconPath(card.modelData.appIcon, true)
                                            : ""
                                        visible: source !== ""
                                    }

                                    Text {
                                        anchors.left: appIcon.visible ? appIcon.right : parent.left
                                        anchors.leftMargin: appIcon.visible ? 5 : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: card.modelData.appName
                                        color: Theme.colors.on_surface_variant
                                        font.family: "Maple Mono NF CN"
                                        font.pixelSize: 10
                                        font.styleName: "ExtraBold"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.right: dismissBtn.left
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Notifications.formatTime(card.modelData.time)
                                        color: Theme.colors.on_surface_variant
                                        opacity: 0.6
                                        font.family: "Maple Mono NF CN"
                                        font.pixelSize: 9
                                        font.styleName: "Medium"
                                    }

                                    Item {
                                        id: dismissBtn
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        opacity: cardHover.containsMouse || dismissMa.containsMouse ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: dismissMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "close"
                                            font.family: "Material Symbols Rounded"
                                            font.pixelSize: 13
                                            color: Theme.colors.on_surface_variant
                                        }
                                        MouseArea {
                                            id: dismissMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifications.dismiss(card.modelData.id)
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: card.modelData.summary
                                    color: Theme.colors.on_surface
                                    font.family: "Maple Mono NF CN"
                                    font.pixelSize: 12
                                    font.styleName: "ExtraBold"
                                    elide: Text.ElideRight
                                    visible: text.length > 0
                                }

                                Text {
                                    width: parent.width
                                    text: card.modelData.body
                                    color: Theme.colors.on_surface_variant
                                    font.family: "Maple Mono NF CN"
                                    font.pixelSize: 11
                                    font.styleName: "Medium"
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: card.expanded ? 999 : 2
                                    elide: card.expanded ? Text.ElideNone : Text.ElideRight
                                    textFormat: Text.PlainText
                                    visible: text.length > 0
                                }
                            }
                        }
                    }
                }

                // Todo
                Item {
                    anchors.fill: parent
                    visible: root.activeList === "todo"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // 顶部右上一个日期标签(不是 today 时显示选中日期)
                    Item {
                        id: todoHeader
                        anchors.top: parent.top
                        anchors.right: parent.right
                        height: 22
                        width: dateLabel.implicitWidth + 16
                        visible: !root.sameDay(root.selectedDate, new Date())

                        Rectangle {
                            anchors.fill: parent
                            radius: 11
                            color: Qt.rgba(1, 1, 1, 0.06)
                        }
                        Text {
                            id: dateLabel
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(root.selectedDate, "MMM d")
                            color: Theme.colors.on_surface_variant
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 11
                            font.styleName: "ExtraBold"
                        }
                    }

                    // 空状态
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -16
                        spacing: 6
                        visible: root.todayTasks.length === 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "task_alt"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 40
                            color: Theme.colors.on_surface_variant
                            opacity: 0.45
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nothing to do"
                            color: Theme.colors.on_surface_variant
                            opacity: 0.6
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: "Medium"
                        }
                    }

                    ListView {
                        id: todoList
                        anchors.top: todoHeader.visible ? todoHeader.bottom : parent.top
                        anchors.topMargin: todoHeader.visible ? 6 : 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: addBox.top
                        anchors.bottomMargin: 8
                        clip: true
                        spacing: 4
                        visible: root.todayTasks.length > 0
                        model: root.todayTasks
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: taskCard
                            required property var modelData
                            width: ListView.view.width
                            height: 30
                            radius: 10
                            color: taskMa.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.06)
                                : Qt.rgba(1, 1, 1, 0.03)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            MouseArea {
                                id: taskMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 8

                                Item {
                                    width: 18
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: checkMa.containsMouse
                                            ? Qt.rgba(1, 1, 1, 0.12)
                                            : Qt.rgba(1, 1, 1, 0.05)
                                        border.color: Theme.colors.on_surface_variant
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "check"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 14
                                        color: Theme.colors.primary
                                        opacity: checkMa.containsMouse ? 0.8 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea {
                                        id: checkMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Tasks.markDone(taskCard.modelData.uuid)
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: taskCard.width - 60
                                    text: taskCard.modelData.description
                                    color: Theme.colors.on_surface
                                    font.family: "Maple Mono NF CN"
                                    font.pixelSize: 12
                                    font.styleName: "Medium"
                                    elide: Text.ElideRight
                                }
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 8
                                width: 18
                                height: 18
                                opacity: taskMa.containsMouse || delMa.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: delMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: Theme.colors.on_surface_variant
                                }
                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Tasks.remove(taskCard.modelData.uuid)
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: addBox
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 32
                        radius: 10
                        color: addInput.activeFocus
                            ? Qt.rgba(1, 1, 1, 0.08)
                            : Qt.rgba(1, 1, 1, 0.04)
                        border.color: addInput.activeFocus ? Theme.colors.primary : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "add"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 16
                            color: Theme.colors.on_surface_variant
                        }

                        TextField {
                            id: addInput
                            anchors.fill: parent
                            anchors.leftMargin: 32
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: root.sameDay(root.selectedDate, new Date())
                                ? "Add task… (Enter to save)"
                                : "Add task for " + Qt.formatDateTime(root.selectedDate, "MMM d") + "…"
                            color: Theme.colors.on_surface
                            placeholderTextColor: Theme.colors.on_surface_variant
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 12
                            font.styleName: "Medium"
                            background: null
                            onAccepted: {
                                if (text.trim().length === 0) return
                                Tasks.add(text.trim(), root.isoDate(root.selectedDate))
                                text = ""
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ╔══════════════════ 右半(~55%):Calendar 独占 ══════════════════╗
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 8

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: navPrev.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Theme.colors.on_surface
                    }
                    MouseArea {
                        id: navPrev
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shiftMonth(-1)
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(root.viewDate, "MMMM yyyy")
                        color: Theme.colors.on_surface
                        font.family: "Maple Mono NF CN"
                        font.pixelSize: 18
                        font.styleName: "ExtraBold"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = new Date()
                            root.viewDate = t
                            root.selectedDate = t
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: navNext.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: Theme.colors.on_surface
                    }
                    MouseArea {
                        id: navNext
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shiftMonth(1)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 0
                Repeater {
                    model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                    delegate: Item {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.colors.on_surface_variant
                            opacity: 0.7
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 11
                            font.styleName: "Medium"
                        }
                    }
                }
            }

            Grid {
                id: dayGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rows: 6
                readonly property real cellW: width / 7
                readonly property real cellH: height / 6
                readonly property date start: root.gridStart(root.viewDate)

                Repeater {
                    model: 42
                    delegate: Item {
                        required property int index
                        width: dayGrid.cellW
                        height: dayGrid.cellH

                        readonly property date cellDate: new Date(
                            dayGrid.start.getFullYear(),
                            dayGrid.start.getMonth(),
                            dayGrid.start.getDate() + index)
                        readonly property bool inMonth: cellDate.getMonth() === root.viewDate.getMonth()
                        readonly property bool isToday: root.sameDay(cellDate, new Date())
                        readonly property bool isSelected: root.sameDay(cellDate, root.selectedDate)
                        readonly property int taskCount: Tasks.countOn(cellDate)

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 6
                            height: width
                            radius: width / 2
                            color: parent.isSelected
                                ? Theme.colors.primary
                                : (parent.isToday ? Qt.rgba(1, 1, 1, 0.08) : (cellHoverMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"))
                            border.color: parent.isToday && !parent.isSelected
                                ? Theme.colors.primary
                                : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.cellDate.getDate()
                            color: parent.isSelected
                                ? Theme.colors.on_primary
                                : (parent.inMonth ? Theme.colors.on_surface : Theme.colors.on_surface_variant)
                            opacity: parent.inMonth ? 1.0 : 0.35
                            font.family: "Maple Mono NF CN"
                            font.pixelSize: 14
                            font.styleName: parent.isSelected || parent.isToday ? "ExtraBold" : "Medium"
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 6
                            anchors.bottomMargin: 6
                            width: 5
                            height: 5
                            radius: 2.5
                            visible: parent.taskCount > 0 && !parent.isSelected
                            color: Theme.colors.primary
                        }

                        MouseArea {
                            id: cellHoverMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedDate = parent.cellDate
                                // 点格子顺便切到 Todo 视图,方便看那天有什么 task
                                if (parent.taskCount > 0) root.activeList = "todo"
                            }
                        }
                    }
                }
            }
        }
    }
}
