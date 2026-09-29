import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "TaskSwitcherLogic.js" as Logic

Item {
    id: row
    property real uiScale: 1

    property var entry: null
    property var ctl: null
    property int rowIndex: -1
    property bool selected: false
    property bool showWorkspace: false
    property bool showActive: false

    readonly property string iconUrl: {
        const appClass = row.entry && row.entry.appClass ? row.entry.appClass : ""
        const first = appClass ? Quickshell.iconPath(appClass, true) : ""
        const second = first === "" && appClass ? Quickshell.iconPath(appClass.toLowerCase(), true) : ""
        first !== "" ? first : second
    }

    readonly property string liveTitle: {
        let value = row.entry ? row.entry.title : ""
        try {
            if (row.entry && row.entry.toplevel && row.entry.toplevel.title) {
                value = String(row.entry.toplevel.title)
            }
        } catch (error) {
        }
        Logic.cleanTitle(value, row.entry ? row.entry.appName : "")
    }

    property bool hovered: false

    visible: row.entry !== null

    Rectangle {
        anchors.fill: parent
        radius: Math.round(7 * row.uiScale)
        color: row.selected
            ? Util.alpha(Color.menu.selectedText, 0.18)
            : (row.hovered ? Util.alpha(Color.menu.text, 0.09) : "transparent")
        border.width: row.selected ? 1 : 0
        border.color: Util.alpha(Color.menu.selectedText, 0.55)

        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Util.alpha(Color.menu.text, 0.09)
        visible: !row.selected
    }

    Rectangle {
        visible: row.selected
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(2, Math.round(3 * row.uiScale))
        height: parent.height - Math.round(10 * row.uiScale)
        radius: Math.max(1, Math.round(2 * row.uiScale))
        color: Color.menu.selectedText
    }

    Image {
        id: appIcon
        width: Math.round(15 * row.uiScale)
        height: Math.round(15 * row.uiScale)
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 2
        visible: status === Image.Ready
        source: row.iconUrl
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Text {
        id: appName
        anchors.left: appIcon.visible ? appIcon.right : parent.left
        anchors.leftMargin: appIcon.visible ? 6 : 8
        anchors.right: badges.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: 2
        height: Math.round(13 * row.uiScale)
        text: row.entry ? row.entry.appName : ""
        elide: Text.ElideRight
        color: row.selected
            ? Color.menu.selectedText
            : Color.menu.text
        font.family: Style.font.family
        // Floors matter: a small [font] base-size would otherwise render the
        // title line at 8px, which is unreadable regardless of opacity.
        font.pixelSize: Math.max(10, Math.round(Style.font.bodySmall * row.uiScale))
        font.weight: Font.DemiBold
    }

    Text {
        anchors.left: appName.left
        anchors.right: badges.left
        anchors.rightMargin: 8
        anchors.top: appName.bottom
        height: Math.round(11 * row.uiScale)
        text: row.liveTitle
        elide: Text.ElideRight
        color: row.selected
            ? Util.alpha(Color.menu.selectedText, 0.88)
            : Util.alpha(Color.menu.text, 0.80)
        font.family: Style.font.family
        font.pixelSize: Math.max(9, Math.round(Style.font.caption * row.uiScale))
    }

    Row {
        id: badges
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.showWorkspace && row.entry && row.entry.workspaceId > 0
            width: wsLabel.implicitWidth + Math.round(6 * row.uiScale)
            height: Math.round(13 * row.uiScale)
            radius: Math.round(4 * row.uiScale)
            color: row.selected
                ? Util.alpha(Color.menu.selectedText, 0.22)
                : Util.alpha(Color.menu.text, 0.12)

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: row.entry ? "ws " + row.entry.workspaceId : ""
                color: row.selected
                    ? Util.alpha(Color.menu.selectedText, 0.9)
                    : Util.alpha(Color.menu.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Math.round(9 * row.uiScale)
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.rowIndex >= 0 && row.rowIndex < 9
            width: 13
            height: Math.round(13 * row.uiScale)
            radius: 3
            color: row.selected
                ? Color.menu.selectedText
                : Util.alpha(Color.menu.text, 0.14)

            Text {
                anchors.centerIn: parent
                text: row.rowIndex + 1
                color: row.selected
                    ? Color.menu.background
                    : Util.alpha(Color.menu.text, 0.78)
                font.family: Style.font.family
                font.pixelSize: Math.round(9 * row.uiScale)
            }
        }
    }

    Rectangle {
        visible: row.showActive && row.entry ? row.entry.activated : false
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: 5
        height: 5
        radius: 3
        color: Util.alpha(Color.menu.selectedText, 0.85)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            row.hovered = true
            if (row.ctl) row.ctl.select(row.rowIndex)
        }
        onExited: row.hovered = false
        onClicked: {
            if (!row.ctl) return
            row.ctl.select(row.rowIndex)
            row.ctl.commit()
        }
    }
}
