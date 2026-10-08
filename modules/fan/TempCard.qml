import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Card {
    title: "Donanım ve sıcaklıklar"

    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Sensors.readings.length)
        columnSpacing: 10
        Repeater {
            model: Sensors.readings.length
            Rectangle {
                readonly property var r: Sensors.readings[index]
                readonly property bool known: r && isFinite(r.value)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                implicitHeight: info.implicitHeight + 24
                radius: 16
                color: Colours.surfaceHigh

                ColumnLayout {
                    id: info
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        StyledText {
                            text: r && r.label === "CPU" ? "memory" : "developer_board"
                            color: Colours.primary
                            font { family: Colours.iconFont; pixelSize: 16 }
                        }
                        StyledText { text: r ? r.label : ""; color: Colours.fgDim; font { pixelSize: 11; bold: true; letterSpacing: 0.8 } }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: known ? Math.round(r.value) + "°C" : (r && r.note !== "" ? r.note : "—")
                        color: known && r.value >= 85 ? Colours.error : (known && r.value >= 70 ? Colours.warning : Colours.fg)
                        font { pixelSize: known ? 24 : 15; bold: true }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: r && r.model !== ""
                        text: r ? r.model : ""
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Colours.fg
                        font.pixelSize: 11
                    }
                    StyledText {
                        visible: r && r.extra !== ""
                        text: r ? r.extra : ""
                        color: Colours.fgDim
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
    StyledText {
        visible: Sensors.readings.length === 0
        text: "Sensör okunamadı"
        color: Colours.fgDim
        font.pixelSize: 12
    }
}
