import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
    id: seg
    property var model: []
    property int current: 0
    property bool controlled: false   // true: tıklayınca kendi kendine değişmez, current dışarıdan bağlanır
    signal picked(int i)              // sadece kullanıcı tıklayınca

    Layout.fillWidth: true
    implicitHeight: 36
    radius: 18
    color: Colours.surfaceHigh

    RowLayout {
        anchors { fill: parent; margins: 3 }
        spacing: 0
        Repeater {
            model: seg.model
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                radius: 15
                color: seg.current === index ? Colours.primary : "transparent"
                Behavior on color { CAnim {} }
                StyledText {
                    anchors.centerIn: parent
                    text: modelData
                    color: seg.current === index ? Colours.fgOnPrimary : Colours.fgDim
                    font { pixelSize: 12; bold: true }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (!seg.controlled) seg.current = index; seg.picked(index) }
                }
            }
        }
    }
}
