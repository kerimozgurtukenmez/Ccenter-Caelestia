import QtQuick
import qs.services

Rectangle {
    id: t
    property bool checked: false
    property bool controlled: false   // true: tıklayınca kendi kendine değişmez, durumu dışarıdan bağla
    signal toggled(bool v)

    implicitWidth: 48
    implicitHeight: 28
    radius: 14
    color: checked ? Colours.primary : Colours.surfaceHigh
    border { width: checked ? 0 : 2; color: Colours.outline }
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: t.checked ? 20 : 14
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: t.checked ? t.width - width - 4 : 7
        color: t.checked ? Colours.fgOnPrimary : Colours.fgDim
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 150 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const v = !t.checked
            if (!t.controlled) t.checked = v
            t.toggled(v)
        }
    }
}
