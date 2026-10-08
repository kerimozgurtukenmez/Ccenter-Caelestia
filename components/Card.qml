import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

Rectangle {
    id: card
    default property alias content: inner.data
    property string title: ""
    property int pad: Tokens.padding.large
    property int gap: Tokens.spacing.medium

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    radius: Tokens.rounding.largeIncreased
    color: Colours.surfaceContainer
    implicitHeight: inner.implicitHeight + pad * 2

    ColumnLayout {
        id: inner
        anchors { fill: parent; margins: card.pad }
        spacing: card.gap

        StyledText {
            visible: card.title !== ""
            text: card.title
            color: Colours.fgDim
            font { pixelSize: 11; bold: true; letterSpacing: 1.2; capitalization: Font.AllUppercase }
        }
    }
}
