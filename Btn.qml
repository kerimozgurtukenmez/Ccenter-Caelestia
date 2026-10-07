import QtQuick
import QtQuick.Layouts

Rectangle {
    id: b
    property string text
    property string icon: ""
    property bool filled: false
    readonly property color fgc: filled ? Colours.fgOnPrimary : Colours.fg
    signal clicked()

    implicitHeight: 38
    implicitWidth: row.implicitWidth + 28
    radius: 19
    color: filled ? Colours.primary : Colours.surfaceHigh

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "white"
        opacity: ma.containsMouse ? 0.1 : 0
    }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text { visible: b.icon !== ""; text: b.icon; color: b.fgc; font { family: Colours.iconFont; pixelSize: 18 } }
        Text { text: b.text; color: b.fgc; font { pixelSize: 13; bold: true } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
