import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "TaskSwitcherLogic.js" as Logic

Item {
    id: hero
    property real uiScale: 1

    property var entry: null

    readonly property int inset: 5
    readonly property var previewSize: hero.entry
        ? Logic.previewSize(hero.entry, hero.width - hero.inset * 2, hero.height - hero.inset * 2)
        : ({ width: 0, height: 0 })

    readonly property string iconUrl: {
        const appClass = hero.entry && hero.entry.appClass ? hero.entry.appClass : ""
        const first = appClass ? Quickshell.iconPath(appClass, true) : ""
        const second = first === "" && appClass ? Quickshell.iconPath(appClass.toLowerCase(), true) : ""
        first !== "" ? first : second
    }

    readonly property bool hasPreview: capture.hasContent && hero.entry !== null

    // Dark inset well: the capture always separates from the panel, whatever
    // the captured window looks like. Near-opaque, because the card behind it
    // is a solid surface and a see-through well would only add noise.
    BorderSurface {
        anchors.fill: parent
        radius: Math.round(10 * hero.uiScale)
        color: Util.alpha("#000000", 0.55)
        borderSpec: Border.flat(Util.alpha(Color.menu.text, 0.14), 1)
    }

    Rectangle {
        id: frame
        anchors.centerIn: parent
        width: hero.previewSize.width
        height: hero.previewSize.height
        radius: Math.round(6 * hero.uiScale)
        color: "transparent"
        clip: true

        ScreencopyView {
            id: capture
            anchors.fill: parent
            live: false
            paintCursor: false
            captureSource: hero.entry && hero.entry.toplevel ? hero.entry.toplevel.wayland : null
            opacity: hero.hasPreview ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 70
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Util.alpha(Color.menu.text, 0.18)
        }

        // Shown until (or instead of) the capture, so there is never a
        // black rectangle while the compositor grabs the surface.
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: !hero.hasPreview && hero.entry !== null
            opacity: hero.entry !== null ? 1 : 0

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(40 * hero.uiScale)
                height: Math.round(40 * hero.uiScale)
                radius: Math.round(11 * hero.uiScale)
                color: Util.alpha(Color.menu.text, 0.10)

                Image {
                    anchors.centerIn: parent
                    width: Math.round(22 * hero.uiScale)
                    height: Math.round(22 * hero.uiScale)
                    visible: status === Image.Ready
                    source: hero.iconUrl
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: hero.iconUrl === ""
                    text: hero.entry ? Logic.appInitial(hero.entry.appClass) : "?"
                    color: Util.alpha(Color.menu.text, 0.8)
                    font.family: Style.font.family
                    font.pixelSize: Math.round(Style.font.title * hero.uiScale)
                    font.weight: Font.DemiBold
                }
            }

        }
    }

    // App name and title sit under the preview, at a size that stays legible
    // instead of shrinking into a single elided line.
}
