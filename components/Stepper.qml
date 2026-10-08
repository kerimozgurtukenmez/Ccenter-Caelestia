import QtQuick
import QtQuick.Layouts
import qs.services

RowLayout {
    id: s
    property string label
    property int value: 0
    property int from: 0
    property int to: 100
    property string unit: ""
    signal moved(int v)

    spacing: 6
    StyledText { text: s.label; color: Colours.fgDim; font.pixelSize: 12 }
    Item { Layout.fillWidth: true }
    StepBtn { icon: "remove"; onActivated: s.moved(Math.max(s.from, s.value - 1)) }
    StyledText {
        Layout.minimumWidth: 46
        horizontalAlignment: Text.AlignHCenter
        text: s.value + s.unit
        color: Colours.fg
        font { pixelSize: 13; bold: true }
    }
    StepBtn { icon: "add"; onActivated: s.moved(Math.min(s.to, s.value + 1)) }
}
