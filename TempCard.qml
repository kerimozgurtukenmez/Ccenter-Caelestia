import QtQuick
import QtQuick.Layouts

Card {
    title: "Sıcaklıklar"

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: Sensors.readings.length
            Rectangle {
                readonly property var r: Sensors.readings[index]
                readonly property bool known: r && isFinite(r.value)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 76
                radius: 16
                color: Colours.surfaceHigh
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Text { Layout.alignment: Qt.AlignHCenter; text: r ? r.label : ""; color: Colours.fgDim; font.pixelSize: 12 }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: known ? Math.round(r.value) + "°C" : (r && r.note !== "" ? r.note : "—")
                        color: known && r.value >= 85 ? "#f2b8b5" : (known && r.value >= 70 ? "#ffcc80" : Colours.fg)
                        font { pixelSize: known ? 22 : 15; bold: true }
                    }
                }
            }
        }
    }
    Text {
        visible: Sensors.readings.length === 0
        text: "Sensör okunamadı"
        color: Colours.fgDim
        font.pixelSize: 12
    }
}
