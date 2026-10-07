import QtQuick
import QtQuick.Layouts

Card {
    id: fan
    property string name: "Fan"
    property string subtitle: ""
    property bool isGlobal: false
    property bool active: true               // global açıkken tekil kartlar false olur
    property alias globalOn: tog.checked
    property var info: null                  // Nbfc.fans[i] (global kartta null)
    property bool synced: false
    property var curve: [0.2, 0.4, 0.6, 0.8, 1.0]
    readonly property bool allowed: isGlobal ? tog.checked : active
    // mode: 0 Otomatik, 1 Sabit, 2 Eğri
    readonly property var st: ({ mode: mode.current, fixed: fixedRow.value, curve: fan.curve })
    signal edited()                          // kullanıcı bir şeyi değiştirdi (400 ms bekleyip bir kez)

    function touch() { debounce.restart() }
    Timer { id: debounce; interval: 400; onTriggered: fan.edited() }

    // İlk durum okunduğunda kartı fanın gerçek durumuna eşitle (komut göndermez)
    onInfoChanged: {
        if (!info || synced || isGlobal) return
        synced = true
        mode.current = info.auto ? 0 : 1
        if (!info.auto) fixedRow.value = Math.max(0, Math.min(1, info.target / 100))
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text { text: "mode_fan"; color: Colours.primary; font { family: Colours.iconFont; pixelSize: 24 } }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { text: fan.name; color: Colours.fg; font { pixelSize: 15; bold: true } }
            Text { Layout.fillWidth: true; text: fan.subtitle; elide: Text.ElideRight; color: Colours.fgDim; font.pixelSize: 11 }
        }
        Text {
            visible: !fan.isGlobal
            text: fan.info ? Math.round(fan.info.current) + "%" : "—"
            color: Colours.primary
            font { pixelSize: 13; bold: true }
        }
        Toggle { id: tog; visible: fan.isGlobal }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        enabled: fan.allowed
        opacity: fan.allowed ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Segment { id: mode; model: ["Otomatik", "Sabit", "Eğri"]; onPicked: fan.touch() }

        Text {
            visible: mode.current === 0
            Layout.fillWidth: true
            text: "Config'teki hazır eğri kullanılır."
            color: Colours.fgDim
            font.pixelSize: 11
        }

        SliderRow {
            id: fixedRow
            visible: mode.current === 1
            label: "Sabit hız"
            value: 0.5
            readout: Math.round(value * 100) + "%"
            onMoved: fan.touch()
        }

        ColumnLayout {
            visible: mode.current === 2
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Sıcaklık eğrisi"; color: Colours.fg; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text { text: "°C → hız %"; color: Colours.fgDim; font.pixelSize: 11 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: Nbfc.temps
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        spacing: 6
                        Text { Layout.alignment: Qt.AlignHCenter; text: Math.round(bar.value * 100) + "%"; color: Colours.fgDim; font.pixelSize: 11 }
                        Slide {
                            id: bar
                            vertical: true
                            Layout.alignment: Qt.AlignHCenter
                            value: fan.curve[index]
                            onMoved: v => {
                                const a = fan.curve.slice()
                                a[index] = v
                                fan.curve = a
                                fan.touch()
                            }
                        }
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData + "°"; color: Colours.fg; font { pixelSize: 12; bold: true } }
                    }
                }
            }
        }
    }
}
