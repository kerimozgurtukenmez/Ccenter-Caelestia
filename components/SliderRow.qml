import QtQuick
import QtQuick.Layouts
import qs.services

ColumnLayout {
    id: row
    property string label
    property string readout
    property alias value: sl.value
    signal moved(real v)

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        Text { text: row.label; color: Colours.fg; font.pixelSize: 13 }
        Item { Layout.fillWidth: true }
        Text { text: row.readout; color: Colours.primary; font { pixelSize: 13; bold: true } }
    }
    Slide { id: sl; Layout.fillWidth: true; onMoved: v => row.moved(v) }
}
