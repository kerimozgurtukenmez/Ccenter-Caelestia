import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Klavye ışığı: renk ve parlaklık (tek bölge). Mantık services/Keyboard.qml'de; burası sadece görünüm.
Flickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    readonly property bool canWrite: Keyboard.available && Keyboard.writable
    // Hazır renkler; ilki Caelestia temasının ana rengi
    readonly property var presets: [
        { name: "Caelestia", c: Colours.primary },
        { name: "Beyaz", c: "#ffffff" }, { name: "Kırmızı", c: "#ff0000" }, { name: "Turuncu", c: "#ff6000" },
        { name: "Sarı", c: "#ffd000" }, { name: "Yeşil", c: "#00ff00" }, { name: "Camgöbeği", c: "#00ffff" },
        { name: "Mavi", c: "#0040ff" }, { name: "Mor", c: "#8000ff" }, { name: "Pembe", c: "#ff00a0" }
    ]

    // Pencere açılınca güncel durumu oku (Fn tuşlarıyla değişmiş olabilir)
    Component.onCompleted: Keyboard.refresh()

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        // Durum / uyarılar
        Card {
            title: "Klavye ışığı"
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 44; implicitHeight: 44; radius: 14
                    color: Keyboard.rgb ? Keyboard.color : Colours.surfaceHigh
                    opacity: Keyboard.maxBrightness > 0 ? 0.35 + 0.65 * Keyboard.brightness / Keyboard.maxBrightness : 1
                    border { width: 2; color: Colours.outline }
                    StyledText {
                        anchors.centerIn: parent
                        visible: !Keyboard.rgb
                        text: "keyboard"
                        color: Colours.primary
                        font { family: Colours.iconFont; pixelSize: 24 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        text: !Keyboard.ready ? "Okunuyor…" : Keyboard.available ? Keyboard.name : "Klavye ışığı bulunamadı"
                        color: Colours.fg
                        font { pixelSize: 15; bold: true }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: !Keyboard.available ? "Bu bilgisayarda çekirdeğin tanıdığı bir klavye ışığı yok."
                            : (Keyboard.rgb ? "RGB · tek bölge (tüm klavye tek renk)" : "Tek renk · sadece parlaklık")
                              + (Keyboard.rgb ? " · " + Keyboard.hex(Keyboard.color) : "")
                        color: Colours.fgDim
                        font.pixelSize: 11
                    }
                }
            }
            StyledText {
                visible: Keyboard.available && !Keyboard.writable && Keyboard.ready
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Işığa yazma izni yok. Kurulum, sadece bu ışığın renk ve parlaklık dosyalarına izin veren bir udev kuralı ekler: sudo make install"
                color: Colours.warning
                font.pixelSize: 12
            }
            StyledText {
                visible: Keyboard.error !== ""
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: Keyboard.error
                color: Colours.error
                font.pixelSize: 12
            }
        }

        // Renk
        Card {
            visible: Keyboard.rgb
            title: "Renk"
            enabled: page.canWrite
            opacity: enabled ? 1 : 0.4

            ColorWheel {
                Layout.alignment: Qt.AlignHCenter
                hue: Keyboard.color.hsvHue < 0 ? 0 : Keyboard.color.hsvHue
                sat: Keyboard.color.hsvSaturation
                onPicked: (h, s) => Keyboard.setColor(Qt.hsva(h, s, 1, 1))
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: page.presets
                    Rectangle {
                        required property var modelData
                        width: 34; height: 34; radius: 17
                        color: modelData.c
                        border { width: 2; color: Colours.outline }
                        StyledText {
                            visible: parent.modelData.name === "Caelestia"
                            anchors.centerIn: parent
                            text: "palette"
                            color: Colours.fgOnPrimary
                            font { family: Colours.iconFont; pixelSize: 18 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Keyboard.setColor(parent.modelData.c)
                        }
                    }
                }
            }
        }

        // Parlaklık
        Card {
            visible: Keyboard.available
            title: "Parlaklık"
            enabled: page.canWrite
            opacity: enabled ? 1 : 0.4

            SliderRow {
                id: bright
                label: "Parlaklık"
                value: Keyboard.maxBrightness > 0 ? Keyboard.brightness / Keyboard.maxBrightness : 0
                readout: Math.round(value * 100) + "%"
                onMoved: v => Keyboard.setBrightness(v * Keyboard.maxBrightness)
            }
            // Kaydırıcı sürüklenince bağı kopar; parlaklık başka yerden (butonlar, terminal) değişince eşitle
            Connections {
                target: Keyboard
                function onBrightnessChanged() {
                    if (Keyboard.maxBrightness > 0) bright.value = Keyboard.brightness / Keyboard.maxBrightness
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [{ t: "Kapalı", v: 0 }, { t: "%25", v: 0.25 }, { t: "%50", v: 0.5 }, { t: "%100", v: 1 }]
                    Btn {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.t
                        onClicked: Keyboard.setBrightness(modelData.v * Keyboard.maxBrightness)
                    }
                }
            }
        }
    }
}
