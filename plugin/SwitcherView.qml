import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "TaskSwitcherLogic.js" as Logic

Item {
    id: view

    property var ctl: null
    focus: true

    // Authored against a 1536x864 reference display, then scaled to whatever
    // screen this actually runs on, so the panel keeps its proportions from
    // 1280x720 laptops up to 4K without ever overflowing the display.
    readonly property real screenW: ctl && ctl.screen ? ctl.screen.width : 1536
    readonly property real screenH: ctl && ctl.screen ? ctl.screen.height : 864

    // Test hook: force a scale to check a size the current display cannot show.
    property real uiScaleOverride: 0
    readonly property real uiScale: uiScaleOverride > 0 ? uiScaleOverride
        : Math.max(0.55, Math.min(1.35, Math.min(screenW / 1536, screenH / 864)))

    readonly property int heroW: Math.round(560 * uiScale)
    readonly property int heroH: Math.round(320 * uiScale)
    readonly property int rowW: Math.round(176 * uiScale)
    readonly property int rowH: Math.max(20, Math.round(30 * uiScale))
    readonly property int railGap: Math.max(3, Math.round(6 * uiScale))
    readonly property int railHeaderW: Math.max(12, Math.round(22 * uiScale))
    readonly property int gap: Math.max(6, Math.round(10 * uiScale))
    readonly property int headerHeight: Math.max(14, Math.round(20 * uiScale))
    readonly property int footerHeight: Math.max(10, Math.round(16 * uiScale))
    readonly property int padding: Math.max(8, Math.round(12 * uiScale))
    readonly property int screenMargin: Math.max(10, Math.round(32 * uiScale))

    readonly property int entriesCount: ctl && ctl.entries ? ctl.entries.length : 0
    readonly property var railCells: ctl
        ? Logic.buildRail(ctl.entries || [], ctl.groups || [], ctl.mode)
        : []

    readonly property int railW: {
        if (railCells.length === 0) return heroW
        let width = 0
        for (let i = 0; i < railCells.length; i++) {
            width += railCells[i].kind === "header" ? railHeaderW : rowW
            if (i > 0) width += railGap
        }
        return Math.min(width, Math.max(heroW, maxRailW))
    }

    readonly property int railContentW: {
        let width = 0
        for (let i = 0; i < railCells.length; i++) {
            width += railCells[i].kind === "header" ? railHeaderW : rowW
            if (i > 0) width += railGap
        }
        return width
    }

    readonly property int maxRailW: Math.max(360, screenW - screenMargin * 2 - padding * 2)
    readonly property int contentW: Math.max(heroW, railW)
    readonly property int contentH: entriesCount > 0 ? heroH + gap + rowH : heroH
    readonly property int contentOffsetX: Math.round((contentW - heroW) / 2)

    readonly property int panelW: Math.min(contentW + padding * 2,
        screenW - screenMargin * 2)
    readonly property int panelH: Math.min(contentH + headerHeight + footerHeight + gap + padding * 2 + 12,
        screenH - screenMargin * 2)

    readonly property var selectedEntry: ctl && ctl.entries && ctl.selectedIndex >= 0
        && ctl.selectedIndex < ctl.entries.length
        ? ctl.entries[ctl.selectedIndex]
        : null

    readonly property string modeTitle: {
        if (!ctl) return ""
        if (ctl.mode === "global") return "All windows"
        if (ctl.mode === "grouped") return "By workspace"
        return "This workspace"
    }

    readonly property string modeSummary: {
        if (!ctl) return ""
        const count = Logic.summarize(entriesCount)
        if (ctl.sticky) return count + " · click or Enter to open"
        return count
    }

    readonly property var hints: ctl && ctl.sticky
        ? [
            { key: "Click", text: "open", accent: true },
            { key: "1-9", text: "jump" },
            { key: "Esc", text: "close" }
        ]
        : [
            { key: "Tab", text: "cycle" },
            { key: "1-9", text: "jump" },
            { key: "Release", text: "open", accent: true }
        ]

    function selectNext(delta) {
        if (!ctl || entriesCount === 0) return

        let next = ctl.selectedIndex + delta
        if (ctl.mode === "grouped" && ctl.groups && ctl.groups.length > 0) {
            const group = Logic.groupIndexOfEntry(ctl.groups, ctl.selectedIndex)
            const row = ctl.selectedIndex - Logic.groupStartIndex(ctl.groups, group)
            const target = group + delta
            if (target < 0 || target >= ctl.groups.length) return
            const start = Logic.groupStartIndex(ctl.groups, target)
            ctl.select(start + Math.min(row, ctl.groups[target].entries.length - 1))
            return
        }

        if (next < 0) next = 0
        if (next > entriesCount - 1) next = entriesCount - 1
        ctl.select(next)
    }

    function moveByRow(delta) {
        selectNext(delta)
    }

    function moveByColumn(delta) {
        selectNext(delta)
    }

    function centerSelection() {
        if (!rail.visible || entriesCount === 0) return
        const index = ctl ? ctl.selectedIndex : -1
        if (index < 0) return

        let x = 0
        for (let i = 0; i < railCells.length; i++) {
            const cell = railCells[i]
            if (cell.kind === "row" && cell.index === index) {
                const width = rowW
                const target = x + width / 2 - rail.width / 2
                rail.contentX = Math.max(0, Math.min(rail.contentWidth - rail.width, target))
                return
            }
            x += (cell.kind === "header" ? railHeaderW : rowW) + (i > 0 ? railGap : 0)
        }
    }

    onEntriesCountChanged: Qt.callLater(centerSelection)

    Keys.onPressed: function (event) {
        const key = event.key

        if (key === Qt.Key_Escape) {
            event.accepted = true
            if (view.ctl) view.ctl.cancel()
            return
        }
        if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            event.accepted = true
            if (view.ctl) view.ctl.commit()
            return
        }
        if (key === Qt.Key_Home) {
            event.accepted = true
            if (view.ctl) view.ctl.select(0)
            return
        }
        if (key === Qt.Key_End) {
            event.accepted = true
            if (view.ctl) view.ctl.select(1000000)
            return
        }
        if (key === Qt.Key_Left || key === Qt.Key_Up) {
            event.accepted = true
            view.selectNext(-1)
            return
        }
        if (key === Qt.Key_Right || key === Qt.Key_Down) {
            event.accepted = true
            view.selectNext(1)
            return
        }
        if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            event.accepted = true
            if (!view.ctl) return
            const digit = key - Qt.Key_0
            view.ctl.select(digit === 0 ? 9 : digit - 1)
            view.ctl.commit()
        }
    }

    Keys.onReleased: function (event) {
        const keys = view.ctl ? view.ctl.commitKeys : []
        if (keys.indexOf(event.key) >= 0 && view.ctl) view.ctl.commit()
    }

    Rectangle {
        anchors.fill: parent
        color: Color.menu.scrim
    }

    BorderSurface {
        id: panel
        anchors.centerIn: parent
        width: view.panelW
        height: view.panelH
        radius: Math.round(14 * view.uiScale)
        color: Util.alpha(Color.menu.background, 0.55)
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, 1)

        // Specular edge: the one cue that reads as glass rather than a
        // translucent rectangle.
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.leftMargin: parent.radius
            anchors.right: parent.right
            anchors.rightMargin: parent.radius
            height: 1
            color: Util.alpha(Color.menu.text, 0.13)
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 2.0
            shadowScale: 1.06
            shadowColor: Util.alpha("#000000", 0.55)
        }

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: view.padding
            height: view.headerHeight

            Rectangle {
                id: titleAccent
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2, Math.round(3 * view.uiScale))
                height: Math.round(13 * view.uiScale)
                radius: Math.max(1, Math.round(2 * view.uiScale))
                color: Color.menu.selectedText
            }

            Text {
                anchors.left: titleAccent.right
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                text: view.modeTitle
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.subtitle * view.uiScale)
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: view.modeSummary
                color: Util.alpha(Color.menu.text, 0.50)
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.caption * view.uiScale)
            }
        }

        Item {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: 4
            anchors.bottomMargin: view.padding
            anchors.leftMargin: view.padding
            anchors.rightMargin: view.padding
            height: view.contentH
            visible: view.entriesCount > 0

            HeroPreview {
                uiScale: view.uiScale
                id: heroPreview
                x: view.contentOffsetX
                y: 0
                width: view.heroW
                height: view.heroH
                entry: view.selectedEntry
            }

            Flickable {
                id: rail
                x: 0
                y: view.heroH + view.gap
                width: parent.width
                height: view.rowH
                contentWidth: view.railContentW
                contentHeight: view.rowH
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Behavior on contentX {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutQuint
                    }
                }

                Row {
                    spacing: view.railGap

                    Repeater {
                        model: view.railCells

                        Item {
                            id: cell
                            required property var modelData
                            required property int index

                            readonly property int cellW: modelData.kind === "header"
                                ? view.railHeaderW
                                : view.rowW

                            width: cell.cellW
                            height: view.rowH

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: view.rowH - Math.round(12 * view.uiScale)
                                color: Util.alpha(Color.menu.text, 0.12)
                                visible: cell.modelData.kind === "header"
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cell.modelData.kind === "header"
                                text: cell.modelData.count > 1
                                    ? cell.modelData.id + " · " + cell.modelData.count
                                    : String(cell.modelData.id > 0 ? cell.modelData.id : cell.modelData.count)
                                color: Util.alpha(Color.menu.text, 0.45)
                                font.family: Style.font.family
                                font.pixelSize: Math.round(Style.font.caption * view.uiScale)
                                font.weight: Font.DemiBold
                                wrapMode: Text.NoWrap
                                rotation: 90
                            }

                            WindowRow {
                                uiScale: view.uiScale
                                anchors.fill: parent
                                visible: cell.modelData.kind === "row"
                                entry: cell.modelData.kind === "row" ? cell.modelData.entry : null
                                ctl: view.ctl
                                rowIndex: cell.modelData.kind === "row" ? cell.modelData.index : -1
                                selected: cell.modelData.kind === "row"
                                    && view.ctl
                                    && view.ctl.selectedIndex === cell.modelData.index
                                showWorkspace: view.ctl ? view.ctl.mode === "global" : false
                                showActive: view.ctl ? view.ctl.mode === "grouped" : false
                            }
                        }
                    }
                }

                // Rail scroll indicator, hand-rolled to avoid pulling in
                // QtQuick.Controls just for a three pixel bar.
                Rectangle {
                    id: railThumb
                    visible: rail.contentWidth > rail.width && rail.contentWidth > 0
                    height: 3
                    radius: 2
                    color: Util.alpha(Color.menu.text, 0.22)
                    width: Math.max(28, rail.width * rail.width / rail.contentWidth)
                    x: rail.x + (rail.contentX / Math.max(1, rail.contentWidth - rail.width))
                        * (rail.width - width)
                    y: rail.y + rail.height - height
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: view.entriesCount === 0
            spacing: 5

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No open windows"
                color: Util.alpha(Color.menu.text, 0.70)
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.body * view.uiScale)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Open something and try again"
                color: Util.alpha(Color.menu.text, 0.40)
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.caption * view.uiScale)
            }
        }

        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: view.padding
            height: view.footerHeight

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: 10

                Repeater {
                    model: view.hints

                    Row {
                        required property var modelData

                        spacing: 4

                        KeyCap {
                            uiScale: view.uiScale
                            anchors.verticalCenter: parent.verticalCenter
                            label: modelData.key
                            accent: modelData.accent === true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            color: modelData.accent === true
                                ? Util.alpha(Color.menu.text, 0.75)
                                : Util.alpha(Color.menu.text, 0.45)
                            font.family: Style.font.family
                            font.pixelSize: Math.round(Style.font.caption * view.uiScale)
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: view.ctl
        function onEntriesChanged() {
            view.centerSelection()
        }
        function onGroupsChanged() {
            view.centerSelection()
        }
        function onModeChanged() {
            view.centerSelection()
        }
        function onSelectedIndexChanged() {
            view.centerSelection()
        }
        function onOpenedChanged() {
            if (view.ctl && view.ctl.opened) {
                Qt.callLater(function () {
                    view.forceActiveFocus()
                })
            }
        }
    }
}
