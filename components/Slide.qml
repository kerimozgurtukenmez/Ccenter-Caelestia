import QtQuick
import qs.services

Item {
    id: s
    property real value: 0.5          // 0..1
    property bool vertical: false
    property color accent: Colours.primary
    readonly property real thick: Math.min(width, height)
    signal moved(real v)              // only while the user drags

    implicitWidth: vertical ? 24 : 200
    implicitHeight: vertical ? 90 : 24

    Rectangle { anchors.fill: parent; radius: s.thick / 2; color: Colours.surfaceHigh }
    Rectangle {
        radius: s.thick / 2
        color: s.accent
        width: s.vertical ? s.width : Math.max(s.thick, s.width * s.value)
        height: s.vertical ? Math.max(s.thick, s.height * s.value) : s.height
        y: s.vertical ? s.height - height : 0
    }
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function upd(m) {
            const v = s.vertical ? 1 - m.y / height : m.x / width
            s.value = Math.max(0, Math.min(1, v))
            s.moved(s.value)
        }
        onPressed: m => upd(m)
        onPositionChanged: m => upd(m)
    }
}
