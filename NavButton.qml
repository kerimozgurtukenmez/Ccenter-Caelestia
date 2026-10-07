import QtQuick
import QtQuick.Layouts

Rectangle {
    id: btn
    property string icon
    property string label
    property string sub
    property bool active: false
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 84
    radius: 22
    color: active ? Colours.primary : (ma.containsMouse ? Colours.surfaceHigh : Colours.surfaceContainer)
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 14

        Rectangle {
            implicitWidth: 48; implicitHeight: 48; radius: 16
            color: btn.active ? Qt.rgba(0, 0, 0, 0.15) : Colours.surfaceHigh
            Text {
                anchors.centerIn: parent
                text: btn.icon
                font { family: Colours.iconFont; pixelSize: 28 }
                color: btn.active ? Colours.onPrimary : Colours.primary
            }
        }
        ColumnLayout {
            spacing: 2
            Text { text: btn.label; font { pixelSize: 16; bold: true } color: btn.active ? Colours.onPrimary : Colours.onSurface }
            Text { text: btn.sub; font.pixelSize: 12; color: btn.active ? Colours.onPrimary : Colours.onSurfaceVariant; opacity: 0.75 }
        }
        Item { Layout.fillWidth: true }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
