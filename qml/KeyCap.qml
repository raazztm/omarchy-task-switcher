import QtQuick
import qs.Commons

Rectangle {
    id: cap
    property real uiScale: 1

    property string label: ""
    property bool accent: false

    implicitWidth: labelText.implicitWidth + Math.round(11 * cap.uiScale)
    implicitHeight: Math.round(17 * cap.uiScale)
    radius: Math.round(4 * cap.uiScale)
    color: accent ? Util.alpha(Color.menu.selectedText, 0.18) : Util.alpha(Color.menu.text, 0.08)
    border.width: 1
    border.color: accent
        ? Util.alpha(Color.menu.selectedText, 0.45)
        : Util.alpha(Color.menu.text, 0.10)

    Text {
        id: labelText
        anchors.centerIn: parent
        text: cap.label
        color: cap.accent ? Color.menu.selectedText : Util.alpha(Color.menu.text, 0.78)
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.caption * cap.uiScale)
        font.weight: Font.DemiBold
    }
}
