import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
    id: card
    default property alias content: inner.data
    property string title: ""
    property int pad: 16
    property int gap: 12

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    radius: 20
    color: Colours.surfaceContainer
    implicitHeight: inner.implicitHeight + pad * 2

    ColumnLayout {
        id: inner
        anchors { fill: parent; margins: card.pad }
        spacing: card.gap

        Text {
            visible: card.title !== ""
            text: card.title
            color: Colours.fgDim
            font { pixelSize: 11; bold: true; letterSpacing: 1.2; capitalization: Font.AllUppercase }
        }
    }
}
