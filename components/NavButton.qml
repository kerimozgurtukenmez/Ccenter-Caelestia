import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

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
    radius: Tokens.rounding.largeIncreased
    color: active ? Colours.primary : (ma.containsMouse ? Colours.surfaceHigh : Colours.surfaceContainer)
    Behavior on color { CAnim {} }

    RowLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 14

        Rectangle {
            implicitWidth: 48; implicitHeight: 48; radius: Tokens.rounding.large
            color: btn.active ? Qt.rgba(0, 0, 0, 0.15) : Colours.surfaceHigh
            StyledText {
                anchors.centerIn: parent
                text: btn.icon
                font { family: Colours.iconFont; pixelSize: 28 }
                color: btn.active ? Colours.fgOnPrimary : Colours.primary
            }
        }
        ColumnLayout {
            spacing: 2
            StyledText { text: btn.label; font { pixelSize: 16; bold: true } color: btn.active ? Colours.fgOnPrimary : Colours.fg }
            StyledText { text: btn.sub; font.pixelSize: 12; color: btn.active ? Colours.fgOnPrimary : Colours.fgDim; opacity: 0.75 }
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
