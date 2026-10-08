import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Flickable {
    id: page
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    // colors = seçilebilecek renk sayısı (0 = renk gerekmez), speed = hız ayarı var mı
    readonly property var modes: [
        { name: "Sabit",       colors: 1, speed: false, hint: "Tek renk, sabit yanar." },
        { name: "Nefes",       colors: 1, speed: true,  hint: "Seçtiğin renk yavaşça artıp söner." },
        { name: "Yanıp sönme", colors: 1, speed: true,  hint: "Seçtiğin renk yanıp söner." },
        { name: "Renk geçişi", colors: 3, speed: true,  hint: "Seçtiğin renkler arasında yumuşak geçiş." },
        { name: "Dalga",       colors: 2, speed: true,  hint: "İki renk arasında dalga gibi akar." },
        { name: "Gökkuşağı",   colors: 0, speed: true,  hint: "Tüm renkler döner, renk seçmeye gerek yok." }
    ]
    property int mode: 0
    readonly property var cur: modes[mode]
    property var slots: [{ h: 0.74, s: 0.31 }, { h: 0.93, s: 0.6 }, { h: 0.55, s: 0.6 }, { h: 0.3, s: 0.6 }]
    property int slot: 0
    property bool sync: false
    onModeChanged: slot = 0

    function slotColor(i) { return Qt.hsva(slots[i].h, slots[i].s, 1, 1) }
    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase()
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Renk çemberi
            Card {
                Layout.fillHeight: true
                title: "Renk"
                enabled: !page.sync && page.cur.colors > 0
                opacity: enabled ? 1 : 0.4

                ColorWheel {
                    Layout.alignment: Qt.AlignHCenter
                    hue: page.slots[page.slot].h
                    sat: page.slots[page.slot].s
                    onPicked: (h, s) => {
                        const a = page.slots.slice()
                        a[page.slot] = { h: h, s: s }
                        page.slots = a
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Repeater {
                        model: page.cur.colors
                        Rectangle {
                            width: 34; height: 34; radius: 17
                            color: page.slotColor(index)
                            border { width: page.slot === index ? 3 : 0; color: Colours.fg }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.slot = index }
                        }
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    color: Colours.fg
                    font { pixelSize: 13; bold: true; family: "monospace" }
                    text: page.sync ? "Caelestia'dan alınıyor"
                        : page.cur.colors === 0 ? "Bu mod renk istemiyor"
                        : page.hex(page.slotColor(page.slot))
                }
            }

            // Işık modları
            Card {
                Layout.fillHeight: true
                title: "Işık modu"
                gap: 6

                Repeater {
                    model: page.modes
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 12
                        color: page.mode === index ? Colours.primary : (ma.containsMouse ? Colours.surfaceHigh : "transparent")
                        StyledText {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                            text: modelData.name
                            color: page.mode === index ? Colours.fgOnPrimary : Colours.fg
                            font.pixelSize: 14
                        }
                        StyledText {
                            anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 12 }
                            text: modelData.colors > 0 ? modelData.colors + " renk" : "otomatik"
                            color: page.mode === index ? Colours.fgOnPrimary : Colours.fgDim
                            opacity: 0.75
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.mode = index
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: page.cur.hint
                    wrapMode: Text.WordWrap
                    color: Colours.fgDim
                    font.pixelSize: 11
                }
            }
        }

        // Diğer ayarlar
        Card {
            title: "Ayarlar"
            gap: 16

            SliderRow { label: "Parlaklık"; value: 0.8; readout: Math.round(value * 100) + "%" }
            SliderRow {
                label: "Efekt hızı"; value: 0.5; readout: Math.round(value * 100) + "%"
                enabled: page.cur.speed
                opacity: enabled ? 1 : 0.35
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                StyledText { text: "sync"; font { family: Colours.iconFont; pixelSize: 24 } color: Colours.primary }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText { text: "Caelestia renk senkronizasyonu"; color: Colours.fg; font.pixelSize: 14 }
                    StyledText { text: "Klavye renkleri Caelestia temasından alınır"; color: Colours.fgDim; font.pixelSize: 11 }
                }
                Toggle { onCheckedChanged: page.sync = checked }
            }
        }
    }
}
