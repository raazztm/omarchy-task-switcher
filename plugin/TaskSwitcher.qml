import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "TaskSwitcherLogic.js" as Logic

Item {
    id: root

    property string mode: "global"
    property bool sticky: false
    property bool opened: false
    property var entries: []
    property var groups: []
    property int selectedIndex: 0
    property var pendingEntry: null

    readonly property var screen: {
        const focused = Hyprland.focusedMonitor
        const wanted = focused ? focused.name : ""
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === wanted) return screens[i]
        }
        return screens.length > 0 ? screens[0] : null
    }

    readonly property var commitKeys: [
        Qt.Key_Alt, Qt.Key_Alt_L, Qt.Key_Alt_R,
        Qt.Key_Control, Qt.Key_Control_L, Qt.Key_Control_R,
        Qt.Key_Super, Qt.Key_Super_L, Qt.Key_Super_R,
        Qt.Key_Meta, Qt.Key_Meta_L, Qt.Key_Meta_R
    ]

    function open(payload) {
        let options = ({})
        if (typeof payload === "string" && payload.length > 0) {
            try {
                options = JSON.parse(payload)
            } catch (error) {
                options = ({})
            }
        } else if (payload && typeof payload === "object") {
            options = payload
        }

        if (options.mode) mode = String(options.mode)
        sticky = options.sticky === true
        selectedIndex = 0
        rebuild()

        if (options.direction === -1) selectedIndex = Math.max(0, entries.length - 1)
        if (options.index !== undefined) selectedIndex = clampIndex(parseInt(options.index, 10))

        opened = true
    }

    function close() {
        opened = false
    }

    function begin(nextMode, direction) {
        if (opened && nextMode === mode) {
            move(direction)
            return
        }

        mode = nextMode
        rebuild()

        if (entries.length === 0) {
            selectedIndex = 0
        } else if (direction > 0) {
            selectedIndex = Math.min(1, entries.length - 1)
        } else {
            selectedIndex = entries.length - 1
        }

        opened = true
    }

    function move(delta) {
        if (entries.length === 0) return
        const count = entries.length
        selectedIndex = ((selectedIndex + delta) % count + count) % count
    }

    function select(index) {
        selectedIndex = clampIndex(index)
    }

    function commit() {
        if (!opened) return

        const entry = entries[selectedIndex]
        pendingEntry = entry
        opened = false
        if (!entry) return

        // Hand the focus over only after this overlay has released the
        // keyboard, otherwise the compositor puts focus straight back.
        focusTimer.restart()
    }

    function activateSelected() {
        const entry = pendingEntry
        pendingEntry = null
        if (!entry) return

        // This Hyprland evaluates dispatches as Lua, so the plain
        // "focuswindow address:0x..." form is a syntax error.
        try {
            Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + String(entry.address) + '" })')
        } catch (error) {
            console.warn("task-switcher: focus dispatch failed", error)
        }
    }

    Timer {
        id: focusTimer
        interval: 140
        onTriggered: root.activateSelected()
    }

    function cancel() {
        opened = false
    }

    function clampIndex(index) {
        if (entries.length === 0) return 0
        let value = isNaN(index) ? 0 : index
        if (value < 0) value = 0
        if (value > entries.length - 1) value = entries.length - 1
        return value
    }

    function rebuild() {
        const tops = Hyprland.toplevels.values
        const focused = Hyprland.focusedWorkspace
        entries = Logic.buildEntries(tops, mode, focused ? focused.id : -1)

        if (mode === "grouped") {
            groups = Logic.buildGroups(entries, workspaceOrder())
            entries = Logic.flattenGroups(groups)
        } else {
            groups = []
        }

        selectedIndex = clampIndex(selectedIndex)

    }

    function workspaceOrder() {
        const workspaces = Hyprland.workspaces.values
        const out = []

        for (let i = 0; i < workspaces.length; i++) {
            out.push({ id: workspaces[i].id, name: workspaces[i].name })
        }

        out.sort(function (a, b) {
            const aSpecial = a.id > 0 ? 0 : 1
            const bSpecial = b.id > 0 ? 0 : 1
            if (aSpecial !== bSpecial) return aSpecial - bSpecial
            return a.id - b.id
        })

        return out
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.opened) return
            const name = event && event.name ? String(event.name) : ""
            if (name === "openwindow" || name === "closewindow") root.rebuild()
        }
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "workspace-next"
        description: "Task switcher: next window on this workspace"
        onPressed: root.begin("workspace", 1)
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "workspace-prev"
        description: "Task switcher: previous window on this workspace"
        onPressed: root.begin("workspace", -1)
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "global-next"
        description: "Task switcher: next window on any workspace"
        onPressed: root.begin("global", 1)
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "global-prev"
        description: "Task switcher: previous window on any workspace"
        onPressed: root.begin("global", -1)
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "grouped-next"
        description: "Task switcher: next window grouped by workspace"
        onPressed: root.begin("grouped", 1)
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "grouped-prev"
        description: "Task switcher: previous window grouped by workspace"
        onPressed: root.begin("grouped", -1)
    }

    GlobalShortcut {
        appid: "nayan.task-switcher"
        name: "commit"
        description: "Task switcher: focus the highlighted window"
        onPressed: root.commit()
        onReleased: root.commit()
    }

    PanelWindow {
        id: window
        visible: root.opened
        implicitWidth: root.screen ? root.screen.width : 1920
        implicitHeight: root.screen ? root.screen.height : 1080
        anchors {
            top: true
            left: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "nayan-task-switcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        SwitcherView {
            anchors.fill: parent
            ctl: root
        }
    }
}
